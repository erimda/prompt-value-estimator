# frozen_string_literal: true

require 'yaml'
require 'erb'

module PromptValueEstimator
  class Configuration
    attr_reader :providers, :normalize, :estimate, :cache, :output

    def initialize(config_path = nil)
      @config_path = config_path || default_config_path
      load_config
    end

    def provider_enabled?(name)
      @providers[name.to_s]&.dig('enabled') == true
    end

    def provider_config(name)
      @providers[name.to_s] || {}
    end

    def weight_for_type(type)
      @estimate['weights'][type.to_s] || 0.0
    end

    def locale_bias(locale)
      @estimate['locale_bias'][locale.to_s] || 1.0
    end

    def max_variants
      @normalize['max_variants'] || 15
    end

    def stopwords
      @normalize['stopwords'] || []
    end

    def cache_enabled?
      @cache['enabled'] == true
    end

    def cache_ttl
      @cache['ttl_seconds'] || 86_400
    end

    def top_n
      @output['topN'] || 10
    end

    private

    def default_config_path
      File.join(File.dirname(__FILE__), '..', '..', 'config', 'config.yml')
    end

    def load_config
      config_content = File.read(@config_path)
      processed_content = ERB.new(config_content).result
      config = YAML.safe_load(processed_content)

      @providers = config['providers'] || {}
      @normalize = config['normalize'] || {}
      @estimate = config['estimate'] || {}
      @cache = config['cache'] || {}
      @output = config['output'] || {}
    rescue Errno::ENOENT
      raise ConfigurationError, "Configuration file not found: #{@config_path}"
    rescue YAML::SyntaxError => e
      raise ConfigurationError, "Invalid YAML in configuration file: #{e.message}"
    end
  end

  class ConfigurationError < StandardError; end
end
