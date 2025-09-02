# frozen_string_literal: true

module PromptValueEstimator
  class Normalizer < BaseService
    attr_reader :stopwords, :max_variants

    def initialize(configuration = nil, logger = nil)
      super
      @stopwords = configuration&.stopwords || []
      @max_variants = configuration&.max_variants || 15
    end

    def normalize(prompt)
      validate_presence(prompt, 'prompt')
      validate_type(prompt, String, 'prompt')

      log_info('Normalizing prompt', { prompt: prompt, max_variants: max_variants })

      variants = generate_variants(prompt)
      variants = limit_variants(variants)

      log_info('Generated variants', { count: variants.length, variants: variants })

      result = {
        head: variants[:head] || [],
        mid: variants[:mid] || [],
        long: variants[:long] || []
      }

      log_info('Final result', {
                 head_count: result[:head].length,
                 mid_count: result[:mid].length,
                 long_count: result[:long].length,
                 total: result.values.sum(&:length)
               })

      result
    end

    private

    def generate_variants(prompt)
      cleaned_prompt = clean_text(prompt)
      words = tokenize(cleaned_prompt)
      filtered_words = remove_stopwords(words)

      {
        head: generate_head_variants(filtered_words),
        mid: generate_mid_variants(filtered_words),
        long: generate_long_variants(cleaned_prompt, filtered_words)
      }
    end

    def clean_text(text)
      text.downcase
          .gsub(/[^\w\s]/, ' ') # Remove punctuation
          .gsub(/\s+/, ' ')     # Normalize whitespace
          .strip
    end

    def tokenize(text)
      text.split(/\s+/)
    end

    def remove_stopwords(words)
      words.reject { |word| stopwords.include?(word) }
    end

    def generate_head_variants(words)
      return [] if words.empty?

      variants = []
      # Single word variants
      variants.concat(words.first(3))

      # Two word combinations
      if words.length >= 2
        (0..[words.length - 2, 2].min).each do |i|
          variants << "#{words[i]} #{words[i + 1]}"
        end
      end

      variants.uniq
    end

    def generate_mid_variants(words)
      return [] if words.length < 2

      # Three word combinations
      variants = (0..[words.length - 3, 3].min).map do |i|
        "#{words[i]} #{words[i + 1]} #{words[i + 2]}"
      end

      # Task-oriented phrases
      task_phrases = ['how to', 'what is', 'best way', 'optimize', 'improve', 'create', 'build']
      words.each do |word|
        task_phrases.each do |task_phrase|
          variants << "#{task_phrase} #{word}"
        end
      end

      variants.uniq
    end

    def generate_long_variants(original_prompt, words)
      return [] if words.empty?

      # Question forms with proper spacing
      question_starters = ['how to', 'what is', 'when should', 'where can', 'why does']
      variants = question_starters.map do |starter|
        "#{starter} #{words.join(' ')}"
      end

      # Original prompt with question mark
      variants << "#{original_prompt}?" unless original_prompt.end_with?('?')

      # "Best practices" variants
      if words.length >= 2
        variants << "best practices for #{words.first(2).join(' ')}"
        variants << "tips for #{words.first(2).join(' ')}"
      end

      # Return all variants, let the limiting happen at the top level
      variants.uniq
    end

    def limit_variants(variants)
      total_variants = variants.values.sum(&:length)

      return variants if total_variants <= max_variants

      # Prioritize important variants and distribute remaining slots

      # Ensure each type gets a fair share, but prioritize important long variants
      result = {}

      # Start with equal distribution
      base_allocation = max_variants / 3

      # For head variants
      result[:head] = variants[:head]&.first(base_allocation) || []

      # For mid variants
      result[:mid] = variants[:mid]&.first(base_allocation) || []

      # For long variants, ensure important ones are included
      if variants[:long]&.length&.positive?
        long_variants = variants[:long].dup

        # Find and prioritize important variants
        question_mark = long_variants.find { |v| v.end_with?('?') }
        best_practices = long_variants.find { |v| v.include?('best practices') }
        tips = long_variants.find { |v| v.include?('tips for') }

        # Start with important variants
        result[:long] = []
        result[:long] << question_mark if question_mark
        result[:long] << best_practices if best_practices
        result[:long] << tips if tips

        # Fill remaining slots for long variants
        remaining_long = base_allocation - result[:long].length
        if remaining_long.positive?
          other_variants = long_variants.reject { |v| result[:long].include?(v) }
          result[:long].concat(other_variants.first(remaining_long))
        end
      else
        result[:long] = []
      end

      # If we have remaining slots, distribute them
      total_used = result.values.sum(&:length)
      remaining = max_variants - total_used

      if remaining.positive?
        # Add more variants from each type proportionally
        variants.each do |type, type_variants|
          break if remaining <= 0

          current_count = result[type].length
          max_possible = type_variants.length
          additional = [max_possible - current_count, remaining / 3].min

          if additional.positive?
            result[type] = type_variants.first(current_count + additional)
            remaining -= additional
          end
        end
      end

      result
    end
  end
end
