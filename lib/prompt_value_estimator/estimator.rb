# frozen_string_literal: true

require 'digest'

module PromptValueEstimator
  class Estimator < BaseService
    attr_reader :normalizer, :serpstat_client, :cache

    def initialize(configuration = nil, logger = nil)
      super
      @normalizer = Normalizer.new(configuration, logger)
      @serpstat_client = SerpstatClient.new(configuration, logger)
      @cache = Cache.new(
        ttl: configuration&.cache_ttl || 86_400,
        max_size: 1000 # Default max size
      )
    end

    def estimate_volume(prompt, region = nil)
      validate_presence(prompt, 'prompt')
      validate_type(prompt, String, 'prompt')

      # Check cache first
      cache_key = generate_cache_key('estimate_volume', prompt, region)
      cached_result = cache.get(cache_key)
      if cached_result
        log_info('Returning cached result', { prompt: prompt, region: region })
        return cached_result
      end

      log_info('Starting volume estimation', { prompt: prompt, region: region })

      # Step 1: Normalize the prompt into variants
      variants = normalizer.normalize(prompt)
      log_info('Generated variants', { variants_count: variants.values.sum(&:length) })

      # Step 2: Fetch volume data for all variants
      volume_data = fetch_volume_data(variants, region)
      log_info('Fetched volume data', {
                 total_variants: volume_data.length,
                 variants_with_data: volume_data.count { |v| v[:search_volume].positive? }
               })

      # Step 3: Calculate weighted estimates
      estimates = calculate_weighted_estimates(variants, volume_data)
      log_info('Calculated estimates', {
                 head_estimate: estimates[:head],
                 mid_estimate: estimates[:mid],
                 long_estimate: estimates[:long],
                 total_estimate: estimates[:total]
               })

      # Step 4: Calculate confidence score
      confidence = calculate_confidence_score(variants, volume_data, estimates)

      # Step 5: Generate final result
      result = {
        prompt: prompt,
        region: region || configuration.provider_config('serpstat')['default_region'] || 'us',
        estimates: estimates,
        confidence: confidence,
        variants: variants,
        volume_data: volume_data,
        metadata: {
          total_variants: variants.values.sum(&:length),
          variants_with_data: volume_data.count { |v| v[:search_volume].positive? },
          source: 'serpstat',
          timestamp: Time.now.iso8601
        }
      }

      log_info('Volume estimation completed', {
                 total_estimate: estimates[:total],
                 confidence: confidence
               })

      # Cache the result
      cache.set(cache_key, result)

      result
    end

    def estimate_batch(prompts, region = nil)
      validate_presence(prompts, 'prompts')
      validate_type(prompts, Array, 'prompts')

      log_info('Starting batch estimation', {
                 prompt_count: prompts.length,
                 region: region
               })

      results = []
      prompts.each_with_index do |prompt, index|
        result = estimate_volume(prompt, region)
        results << result
        log_info('Processed prompt', {
                   index: index + 1,
                   total: prompts.length,
                   prompt: prompt,
                   estimate: result[:estimates][:total]
                 })
      rescue StandardError => e
        log_error('Failed to estimate prompt', {
                    prompt: prompt,
                    error: e.message,
                    index: index + 1
                  })
        results << {
          prompt: prompt,
          error: e.message,
          estimates: { total: 0, head: 0, mid: 0, long: 0 },
          confidence: 0.0
        }
      end

      log_info('Batch estimation completed', {
                 successful: results.count { |r| r[:error].nil? },
                 failed: results.count { |r| r[:error] }
               })

      results
    end

    def get_related_prompts(prompt, region = nil)
      validate_presence(prompt, 'prompt')
      validate_type(prompt, String, 'prompt')

      # Check cache first
      cache_key = generate_cache_key('get_related_prompts', prompt, region)
      cached_result = cache.get(cache_key)
      if cached_result
        log_info('Returning cached related prompts', { prompt: prompt, region: region })
        return cached_result
      end

      region ||= configuration.provider_config('serpstat')['default_region'] || 'us'
      log_info('Fetching related prompts', { prompt: prompt, region: region })

      begin
        related_keywords = serpstat_client.get_related_keywords(prompt, region)

        # Sort by search volume (descending)
        sorted_keywords = related_keywords.sort_by { |k| -(k[:search_volume] || 0) }

        result = {
          prompt: prompt,
          region: region,
          related_keywords: sorted_keywords,
          source: 'serpstat',
          metadata: {
            total_related: sorted_keywords.length,
            source: 'serpstat',
            timestamp: Time.now.iso8601
          }
        }

        # Cache the result
        cache.set(cache_key, result)

        result
      rescue StandardError => e
        log_error('Failed to fetch related prompts', {
                    prompt: prompt,
                    region: region,
                    error: e.message
                  })

        {
          prompt: prompt,
          region: region,
          related_keywords: [],
          error: e.message,
          source: 'serpstat',
          metadata: {
            total_related: 0,
            source: 'serpstat',
            timestamp: Time.now.iso8601
          }
        }
      end
    end

    def get_keyword_suggestions(prompt, region = nil)
      validate_presence(prompt, 'prompt')
      validate_type(prompt, String, 'prompt')

      # Check cache first
      cache_key = generate_cache_key('get_keyword_suggestions', prompt, region)
      cached_result = cache.get(cache_key)
      if cached_result
        log_info('Returning cached keyword suggestions', { prompt: prompt, region: region })
        return cached_result
      end

      region ||= configuration.provider_config('serpstat')['default_region'] || 'us'
      log_info('Fetching keyword suggestions', { prompt: prompt, region: region })

      begin
        suggestions = serpstat_client.get_keyword_suggestions(prompt, region)

        # Sort by search volume (descending)
        sorted_suggestions = suggestions.sort_by { |s| -(s[:search_volume] || 0) }

        result = {
          prompt: prompt,
          region: region,
          suggestions: sorted_suggestions,
          source: 'serpstat',
          metadata: {
            total_suggestions: sorted_suggestions.length,
            source: 'serpstat',
            timestamp: Time.now.iso8601
          }
        }

        # Cache the result
        cache.set(cache_key, result)

        result
      rescue StandardError => e
        log_error('Failed to fetch keyword suggestions', {
                    prompt: prompt,
                    region: region,
                    error: e.message
                  })

        {
          prompt: prompt,
          region: region,
          suggestions: [],
          error: e.message,
          source: 'serpstat',
          metadata: {
            total_suggestions: 0,
            source: 'serpstat',
            timestamp: Time.now.iso8601
          }
        }
      end
    end

    private

    def generate_cache_key(method, prompt, region)
      "estimator:#{method}:#{Digest::MD5.hexdigest(prompt.downcase.strip)}:#{region || 'us'}"
    end

    def fetch_volume_data(variants, region)
      volume_data = []

      variants.each do |type, type_variants|
        type_variants.each do |variant|
          data = serpstat_client.get_keyword_volume(variant, region)
          volume_data << data.merge(variant_type: type, original_variant: variant)
        rescue StandardError => e
          log_warn('Failed to fetch volume data', {
                     variant: variant,
                     type: type,
                     error: e.message
                   })
          volume_data << {
            keyword: variant,
            search_volume: 0,
            cpc: 0.0,
            competition: 0.0,
            results_count: 0,
            trend: [],
            source: 'serpstat',
            variant_type: type,
            original_variant: variant,
            error: e.message
          }
        end
      end

      volume_data
    end

    def calculate_weighted_estimates(_variants, volume_data)
      weights = configuration.estimate['weights']
      locale_bias = configuration.estimate['locale_bias'][region] || 1.0

      # Group volume data by type
      head_data = volume_data.select { |v| v[:variant_type] == :head }
      mid_data = volume_data.select { |v| v[:variant_type] == :mid }
      long_data = volume_data.select { |v| v[:variant_type] == :long }

      # Calculate weighted averages for each type
      head_estimate = calculate_type_estimate(head_data, weights['head'], locale_bias)
      mid_estimate = calculate_type_estimate(mid_data, weights['mid'], locale_bias)
      long_estimate = calculate_type_estimate(long_data, weights['long'], locale_bias)

      # Calculate total weighted estimate
      total_estimate = head_estimate + mid_estimate + long_estimate

      {
        head: head_estimate.round(2),
        mid: mid_estimate.round(2),
        long: long_estimate.round(2),
        total: total_estimate.round(2)
      }
    end

    def calculate_type_estimate(type_data, weight, locale_bias)
      return 0.0 if type_data.empty?

      # Filter out variants with errors or zero volume
      valid_data = type_data.reject { |v| v[:error] || v[:search_volume].nil? }
      return 0.0 if valid_data.empty?

      # Calculate weighted average
      total_volume = valid_data.sum { |v| v[:search_volume] || 0 }
      average_volume = total_volume.to_f / valid_data.length

      # Apply weight and locale bias
      (average_volume * weight * locale_bias).round(2)
    end

    def calculate_confidence_score(variants, volume_data, _estimates)
      confidence_config = configuration.estimate['confidence']
      base_score = confidence_config['base_score']

      # Source bonus: more data sources = higher confidence
      source_bonus = calculate_source_bonus(volume_data)

      # Variant bonus: more variants = higher confidence
      variant_bonus = calculate_variant_bonus(variants)

      # Data quality bonus: higher volume data quality = higher confidence
      data_quality_bonus = calculate_data_quality_bonus(volume_data)

      # Competition bonus: lower competition = higher confidence
      competition_bonus = calculate_competition_bonus(volume_data)

      total_confidence = base_score + source_bonus + variant_bonus + data_quality_bonus + competition_bonus

      # Cap confidence at 1.0
      [total_confidence, 1.0].min.round(3)
    end

    def calculate_source_bonus(volume_data)
      confidence_config = configuration.estimate['confidence']
      source_bonus = confidence_config['source_bonus']

      # Count unique sources
      sources = volume_data.filter_map { |v| v[:source] }.uniq
      sources.length * source_bonus
    end

    def calculate_variant_bonus(variants)
      confidence_config = configuration.estimate['confidence']
      variant_bonus = confidence_config['variant_bonus']

      total_variants = variants.values.sum(&:length)

      # Bonus for having more variants (up to a reasonable limit)
      variant_count = [total_variants, 20].min
      (variant_count / 20.0) * variant_bonus
    end

    def calculate_data_quality_bonus(volume_data)
      # Bonus for having high-quality volume data
      valid_data = volume_data.reject { |v| v[:error] || v[:search_volume].nil? }
      return 0.0 if valid_data.empty?

      # Calculate percentage of variants with actual volume data
      total_variants = volume_data.length
      variants_with_data = valid_data.count { |v| v[:search_volume].positive? }

      data_coverage = variants_with_data.to_f / total_variants
      data_coverage * 0.1 # Max 0.1 bonus for data quality
    end

    def calculate_competition_bonus(volume_data)
      # Bonus for lower competition (easier to rank)
      valid_data = volume_data.reject { |v| v[:error] || v[:competition].nil? }
      return 0.0 if valid_data.empty?

      # Lower competition = higher bonus
      average_competition = valid_data.sum { |v| v[:competition] || 0 } / valid_data.length
      competition_bonus = (1.0 - average_competition) * 0.05 # Max 0.05 bonus

      [competition_bonus, 0.0].max
    end

    def region
      @region ||= configuration.provider_config('serpstat')['default_region'] || 'us'
    end
  end
end
