# frozen_string_literal: true

require 'optparse'
require 'json'

module PromptValueEstimator
  class CLI
    def initialize
      @estimator = nil
      @options = {}
    end

    def run(args = ARGV)
      parse_options(args)
      execute_command
    rescue StandardError => e
      handle_error(e)
      exit(1)
    end

    private

    def parse_options(args)
      OptionParser.new do |opts|
        opts.banner = 'Usage: prompt-value-estimator [options] <command> [arguments]'

        opts.on('-p', '--prompt PROMPT', 'Prompt to estimate') do |prompt|
          @options[:prompt] = prompt
        end

        opts.on('-r', '--region REGION', 'Region for estimation (default: us)') do |region|
          @options[:region] = region
        end

        opts.on('-o', '--output FORMAT', 'Output format (json, text)') do |format|
          @options[:output_format] = format
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end

        opts.on('-v', '--version', 'Show version') do
          puts "Prompt Value Estimator #{PromptValueEstimator::VERSION}"
          exit
        end
      end.parse!(args)
    end

    def execute_command
      command = ARGV.first
      case command
      when 'estimate'
        estimate_volume
      when 'related'
        get_related_prompts
      when 'suggestions'
        get_suggestions
      else
        puts "Unknown command: #{command}"
        puts 'Available commands: estimate, related, suggestions'
        exit(1)
      end
    end

    def estimate_volume
      prompt = @options[:prompt] || ARGV[1]
      raise ArgumentError, 'Prompt is required' unless prompt

      result = estimator.estimate_volume(prompt, @options[:region])
      output_result(result)
    end

    def get_related_prompts
      prompt = @options[:prompt] || ARGV[1]
      raise ArgumentError, 'Prompt is required' unless prompt

      result = estimator.get_related_prompts(prompt, @options[:region])
      output_result(result)
    end

    def get_suggestions
      prompt = @options[:prompt] || ARGV[1]
      raise ArgumentError, 'Prompt is required' unless prompt

      result = estimator.get_keyword_suggestions(prompt, @options[:region])
      output_result(result)
    end

    def output_result(result)
      case @options[:output_format]
      when 'json'
        puts JSON.pretty_generate(result)
      else
        output_text(result)
      end
    end

    def output_text(result)
      # Basic text output implementation
      puts "Result: #{result.inspect}"
    end

    def estimator
      @estimator ||= Estimator.new
    end

    def handle_error(error)
      error_message = {
        error: error.class.name,
        message: error.message,
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%SZ')
      }

      case @options[:output_format]
      when 'json'
        puts JSON.pretty_generate(error_message)
      else
        puts "Error: #{error.message}"
      end
    end
  end
end
