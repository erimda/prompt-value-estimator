# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module PromptValueEstimator
  class SerpstatClient < BaseService
    attr_reader :api_key, :base_url, :rate_limit_delay

    def initialize(configuration = nil, logger = nil)
      super
      config = configuration&.provider_config('serpstat') || {}
      @api_key = config['api_key']
      @base_url = 'https://api.serpstat.com/v4'
      @rate_limit_delay = 1.0 # 1 second between requests
      @last_request_time = 0
    end

    def get_keyword_volume(keyword, region = nil)
      validate_presence(keyword, 'keyword')
      validate_type(keyword, String, 'keyword')

      region ||= configuration.provider_config('serpstat')['default_region'] || 'us'
      log_info('Fetching keyword volume', { keyword: keyword, region: region })

      ensure_rate_limit

      response = make_jsonrpc_request('SerpstatKeywordProcedure.getKeywordsInfo', {
                                        keywords: [keyword],
                                        se: 'g_us' # Search engine: Google US
                                      })

      parse_keyword_response(response, keyword)
    rescue StandardError => e
      handle_error(e, { keyword: keyword, region: region })
    end

    def get_related_keywords(keyword, region = nil)
      validate_presence(keyword, 'keyword')
      validate_type(keyword, String, 'keyword')

      region ||= configuration.provider_config('serpstat')['default_region'] || 'us'
      log_info('Fetching related keywords', { keyword: keyword, region: region })

      ensure_rate_limit

      response = make_request('related', {
                                q: keyword,
                                se: 'g_us',
                                loc: region
                              })

      parse_related_response(response, keyword)
    rescue StandardError => e
      handle_error(e, { keyword: keyword, region: region })
    end

    def get_keyword_suggestions(seed_keyword, region = nil)
      validate_presence(seed_keyword, 'seed_keyword')
      validate_type(seed_keyword, String, 'seed_keyword')

      region ||= configuration.provider_config('serpstat')['default_region'] || 'us'
      log_info('Fetching keyword suggestions', { seed_keyword: seed_keyword, region: region })

      ensure_rate_limit

      response = make_request('suggest', {
                                q: seed_keyword,
                                se: 'g_us',
                                loc: region
                              })

      parse_suggestions_response(response, seed_keyword)
    rescue StandardError => e
      handle_error(e, { seed_keyword: seed_keyword, region: region })
    end

    private

    def ensure_rate_limit
      time_since_last = Time.now.to_f - @last_request_time
      if time_since_last < @rate_limit_delay
        sleep_time = @rate_limit_delay - time_since_last
        log_debug('Rate limiting', { sleep_time: sleep_time })
        sleep(sleep_time)
      end
      @last_request_time = Time.now.to_f
    end

    def make_jsonrpc_request(method, params)
      request_data = build_jsonrpc_request(method, params)
      log_debug('Making JSON-RPC request', { method: method, params: params })

      response = retry_with_backoff do
        # Add token as query parameter
        uri = URI("#{@base_url}?token=#{@api_key}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request['User-Agent'] = 'PromptValueEstimator/1.0'
        request.body = request_data.to_json

        http.request(request)
      end

      handle_http_response(response)
    end

    def make_request(endpoint, params)
      uri = build_uri(endpoint, params)
      log_debug('Making request', { endpoint: endpoint, params: params, uri: uri.to_s })

      response = retry_with_backoff do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 10

        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'PromptValueEstimator/1.0'

        http.request(request)
      end

      handle_http_response(response)
    end

    def build_jsonrpc_request(method, params)
      {
        jsonrpc: '2.0',
        method: method,
        params: params,
        id: 1
      }
    end

    def build_uri(endpoint, params)
      uri = URI("#{@base_url}/#{endpoint}")
      uri.query = URI.encode_www_form(params.merge(token: @api_key))
      uri
    end

    # rubocop:disable Style/CaseLikeIf
    def handle_http_response(response)
      # Check response type using is_a? for better testability
      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      elsif response.is_a?(Net::HTTPTooManyRequests)
        raise ProviderRateLimitError, 'Serpstat API rate limit exceeded'
      elsif response.is_a?(Net::HTTPUnauthorized)
        raise ProviderAuthenticationError, 'Invalid Serpstat API key'
      elsif response.is_a?(Net::HTTPBadRequest)
        raise ProviderError, "Bad request: #{response.body}"
      elsif response.is_a?(Net::HTTPServerError)
        raise ProviderConnectionError, "Serpstat server error: #{response.code}"
      else
        raise ProviderError, "Unexpected response: #{response.code} - #{response.body}"
      end
    rescue JSON::ParserError => e
      raise ProviderError, "Invalid JSON response: #{e.message}"
    end
    # rubocop:enable Style/CaseLikeIf

    def parse_keyword_response(response, keyword)
      return {} unless response.is_a?(Hash)

      # Handle JSON-RPC response format
      if response['result'] && response['result']['data']
        data = response['result']['data']
        keyword_data = data.find { |item| item['keyword'] == keyword } || {}

        {
          keyword: keyword,
          search_volume: keyword_data['region_queries_count'] || 0,
          cpc: keyword_data['cost'] || 0.0,
          competition: keyword_data['concurrency'] || 0.0,
          results_count: keyword_data['found_results'] || 0,
          trend: keyword_data['trend'] || [],
          source: 'serpstat'
        }
      elsif response['result']
        result = response['result']

        # Check if result is an array (JSON-RPC format)
        if result.is_a?(Array)
          keyword_data = result.find { |item| item['keyword'] == keyword } || {}

          {
            keyword: keyword,
            search_volume: keyword_data['region_queries_count'] || 0,
            cpc: keyword_data['cpc'] || 0.0,
            competition: keyword_data['competitive_difficulty'] || 0.0,
            results_count: keyword_data['results_count'] || 0,
            trend: keyword_data['trend'] || [],
            source: 'serpstat'
          }
        else
          # Handle old format where result is a hash with keyword as key
          keyword_data = result[keyword] || {}

          {
            keyword: keyword,
            search_volume: keyword_data['sv'] || 0,
            cpc: keyword_data['cpc'] || 0.0,
            competition: keyword_data['comp'] || 0.0,
            results_count: keyword_data['results'] || 0,
            trend: keyword_data['trend'] || [],
            source: 'serpstat'
          }
        end
      else
        # Fallback for non-JSON-RPC format
        result = response['result'] || {}
        keyword_data = result[keyword] || {}

        {
          keyword: keyword,
          search_volume: keyword_data['sv'] || 0,
          cpc: keyword_data['cpc'] || 0.0,
          competition: keyword_data['comp'] || 0.0,
          results_count: keyword_data['results'] || 0,
          trend: keyword_data['trend'] || [],
          source: 'serpstat'
        }
      end
    end

    def parse_related_response(response, _keyword)
      return [] unless response.is_a?(Hash)

      result = response['result'] || {}
      related = result['related'] || []

      related.map do |item|
        {
          keyword: item['keyword'] || '',
          search_volume: item['sv'] || 0,
          cpc: item['cpc'] || 0.0,
          competition: item['comp'] || 0.0,
          source: 'serpstat'
        }
      end
    end

    def parse_suggestions_response(response, _seed_keyword)
      return [] unless response.is_a?(Hash)

      result = response['result'] || {}
      suggestions = result['suggestions'] || []

      suggestions.map do |item|
        {
          keyword: item['keyword'] || '',
          search_volume: item['sv'] || 0,
          cpc: item['cpc'] || 0.0,
          competition: item['comp'] || 0.0,
          source: 'serpstat'
        }
      end
    end
  end
end
