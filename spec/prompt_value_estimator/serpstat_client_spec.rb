# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::SerpstatClient do
  let(:output) { StringIO.new }
  let(:logger) { PromptValueEstimator::Logger.new(output, Logger::DEBUG) }
  let(:configuration) { PromptValueEstimator::Configuration.new }
  let(:client) { described_class.new(configuration, logger) }

  describe '#initialize' do
    it 'creates client with configuration and logger' do
      expect(client.api_key).to eq(configuration.provider_config('serpstat')['api_key'])
      expect(client.base_url).to eq('https://api.serpstat.com/v4')
      expect(client.rate_limit_delay).to eq(1.0)
    end

    it 'creates client with defaults' do
      default_client = described_class.new
      expect(default_client.api_key).to be_nil
      expect(default_client.base_url).to eq('https://api.serpstat.com/v4')
      expect(default_client.rate_limit_delay).to eq(1.0)
    end
  end

  describe '#get_keyword_volume' do
    it 'validates keyword presence' do
      expect { client.get_keyword_volume(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, 'keyword cannot be blank')
      expect { client.get_keyword_volume('') }
        .to raise_error(PromptValueEstimator::ValidationError, 'keyword cannot be blank')
    end

    it 'validates keyword type' do
      expect { client.get_keyword_volume(123) }
        .to raise_error(PromptValueEstimator::ValidationError, 'keyword must be a String')
    end

    it 'uses default region when none specified' do
      expect(client).to receive(:make_request).with('keyword_info', hash_including(loc: 'us'))
      client.get_keyword_volume('test keyword')
    end

    it 'uses specified region' do
      expect(client).to receive(:make_request).with('keyword_info', hash_including(loc: 'tr'))
      client.get_keyword_volume('test keyword', 'tr')
    end
  end

  describe '#get_related_keywords' do
    it 'validates keyword presence' do
      expect { client.get_related_keywords(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, 'keyword cannot be blank')
      expect { client.get_related_keywords('') }
        .to raise_error(PromptValueEstimator::ValidationError, 'keyword cannot be blank')
    end

    it 'validates keyword type' do
      expect { client.get_related_keywords(123) }
        .to raise_error(PromptValueEstimator::ValidationError, 'keyword must be a String')
    end

    it 'calls related endpoint' do
      expect(client).to receive(:make_request).with('related', hash_including(q: 'test keyword'))
      client.get_related_keywords('test keyword')
    end
  end

  describe '#get_keyword_suggestions' do
    it 'validates seed keyword presence' do
      expect { client.get_keyword_suggestions(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, 'seed_keyword cannot be blank')
      expect { client.get_keyword_suggestions('') }
        .to raise_error(PromptValueEstimator::ValidationError, 'seed_keyword cannot be blank')
    end

    it 'validates seed keyword type' do
      expect { client.get_keyword_suggestions(123) }
        .to raise_error(PromptValueEstimator::ValidationError, 'seed_keyword must be a String')
    end

    it 'calls suggest endpoint' do
      expect(client).to receive(:make_request).with('suggest', hash_including(q: 'test keyword'))
      client.get_keyword_suggestions('test keyword')
    end
  end

  describe 'rate limiting' do
    it 'enforces rate limit between requests' do
      start_time = Time.now.to_f

      # First request should not delay
      allow(client).to receive(:make_request).and_return({})
      client.get_keyword_volume('test1')

      # Second request should delay
      client.get_keyword_volume('test2')

      elapsed_time = Time.now.to_f - start_time
      expect(elapsed_time).to be >= 1.0
    end

    it 'logs rate limiting information' do
      allow(client).to receive(:make_request).and_return({})

      client.get_keyword_volume('test1')
      client.get_keyword_volume('test2')

      log_output = output.string
      expect(log_output).to include('Rate limiting')
    end
  end

  describe 'HTTP response handling' do
    it 'handles successful responses' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_response).to receive(:body).and_return('{"result": {"test": {"sv": 1000}}}')

      result = client.send(:handle_http_response, mock_response)
      expect(result).to eq({ 'result' => { 'test' => { 'sv' => 1000 } } })
    end

    it 'handles rate limit errors' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(true)
      allow(mock_response).to receive_messages(code: '429', body: 'Rate limited')

      expect { client.send(:handle_http_response, mock_response) }
        .to raise_error(PromptValueEstimator::ProviderRateLimitError,
                        'Serpstat API rate limit exceeded')
    end

    it 'handles authentication errors' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(true)
      allow(mock_response).to receive_messages(code: '401', body: 'Unauthorized')

      expect { client.send(:handle_http_response, mock_response) }
        .to raise_error(PromptValueEstimator::ProviderAuthenticationError,
                        'Invalid Serpstat API key')
    end

    it 'handles bad request errors' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPBadRequest).and_return(true)
      allow(mock_response).to receive(:body).and_return('Invalid parameters')

      expect { client.send(:handle_http_response, mock_response) }
        .to raise_error(PromptValueEstimator::ProviderError, 'Bad request: Invalid parameters')
    end

    it 'handles server errors' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPBadRequest).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPServerError).and_return(true)
      allow(mock_response).to receive(:code).and_return('500')

      expect { client.send(:handle_http_response, mock_response) }
        .to raise_error(PromptValueEstimator::ProviderConnectionError, 'Serpstat server error: 500')
    end

    it 'handles unexpected responses' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPTooManyRequests).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPUnauthorized).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPBadRequest).and_return(false)
      allow(mock_response).to receive(:is_a?).with(Net::HTTPServerError).and_return(false)
      allow(mock_response).to receive_messages(code: '418', body: 'I\'m a teapot')

      expect { client.send(:handle_http_response, mock_response) }
        .to raise_error(PromptValueEstimator::ProviderError,
                        'Unexpected response: 418 - I\'m a teapot')
    end

    it 'handles invalid JSON responses' do
      mock_response = double('response')
      allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_response).to receive(:body).and_return('invalid json')

      expect { client.send(:handle_http_response, mock_response) }
        .to raise_error(PromptValueEstimator::ProviderError, /Invalid JSON response/)
    end
  end

  describe 'response parsing' do
    describe '#parse_keyword_response' do
      it 'parses valid keyword response' do
        response = {
          'result' => {
            'test keyword' => {
              'sv' => 1500,
              'cpc' => 2.50,
              'comp' => 0.75,
              'results' => 1_000_000,
              'trend' => [100, 120, 150]
            }
          }
        }

        result = client.send(:parse_keyword_response, response, 'test keyword')

        expect(result).to eq({
                               keyword: 'test keyword',
                               search_volume: 1500,
                               cpc: 2.50,
                               competition: 0.75,
                               results_count: 1_000_000,
                               trend: [100, 120, 150],
                               source: 'serpstat'
                             })
      end

      it 'handles missing keyword data' do
        response = { 'result' => {} }
        result = client.send(:parse_keyword_response, response, 'missing keyword')

        expect(result).to eq({
                               keyword: 'missing keyword',
                               search_volume: 0,
                               cpc: 0.0,
                               competition: 0.0,
                               results_count: 0,
                               trend: [],
                               source: 'serpstat'
                             })
      end

      it 'handles invalid response format' do
        result = client.send(:parse_keyword_response, 'invalid', 'test')
        expect(result).to eq({})
      end
    end

    describe '#parse_related_response' do
      it 'parses valid related response' do
        response = {
          'result' => {
            'related' => [
              { 'keyword' => 'related1', 'sv' => 500, 'cpc' => 1.50, 'comp' => 0.60 },
              { 'keyword' => 'related2', 'sv' => 300, 'cpc' => 0.80, 'comp' => 0.40 }
            ]
          }
        }

        result = client.send(:parse_related_response, response, 'test keyword')

        expect(result).to eq([
                               { keyword: 'related1', search_volume: 500, cpc: 1.50, competition: 0.60,
                                 source: 'serpstat' },
                               { keyword: 'related2', search_volume: 300, cpc: 0.80, competition: 0.40,
                                 source: 'serpstat' }
                             ])
      end

      it 'handles empty related results' do
        response = { 'result' => { 'related' => [] } }
        result = client.send(:parse_related_response, response, 'test keyword')
        expect(result).to eq([])
      end
    end

    describe '#parse_suggestions_response' do
      it 'parses valid suggestions response' do
        response = {
          'result' => {
            'suggestions' => [
              { 'keyword' => 'suggestion1', 'sv' => 800, 'cpc' => 2.00, 'comp' => 0.70 },
              { 'keyword' => 'suggestion2', 'sv' => 600, 'cpc' => 1.20, 'comp' => 0.50 }
            ]
          }
        }

        result = client.send(:parse_suggestions_response, response, 'test keyword')

        expect(result).to eq([
                               { keyword: 'suggestion1', search_volume: 800, cpc: 2.00, competition: 0.70,
                                 source: 'serpstat' },
                               { keyword: 'suggestion2', search_volume: 600, cpc: 1.20, competition: 0.50,
                                 source: 'serpstat' }
                             ])
      end

      it 'handles empty suggestions results' do
        response = { 'result' => { 'suggestions' => [] } }
        result = client.send(:parse_suggestions_response, response, 'test keyword')
        expect(result).to eq([])
      end
    end
  end

  describe 'URI building' do
    it 'builds correct URI with parameters' do
      uri = client.send(:build_uri, 'keyword_info', { q: 'test', loc: 'us' })

      expect(uri.host).to eq('api.serpstat.com')
      expect(uri.path).to eq('/v4/keyword_info')
      expect(uri.query).to include('q=test')
      expect(uri.query).to include('loc=us')
      expect(uri.query).to include('token=')
    end
  end

  describe 'error handling' do
    it 'logs errors with context' do
      allow(client).to receive(:make_request).and_raise(StandardError.new('Test error'))

      expect { client.get_keyword_volume('test') }.to raise_error(StandardError)

      log_output = output.string
      expect(log_output).to include('Service error occurred')
      expect(log_output).to include('test')
    end
  end
end
