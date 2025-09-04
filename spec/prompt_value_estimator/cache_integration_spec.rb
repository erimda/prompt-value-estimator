# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Cache Integration' do
  let(:estimator) { PromptValueEstimator::Estimator.new }
  let(:mock_serpstat_client) { instance_double(PromptValueEstimator::SerpstatClient) }
  let(:mock_normalizer) { instance_double(PromptValueEstimator::Normalizer) }

  before do
    allow(PromptValueEstimator::SerpstatClient).to receive(:new).and_return(mock_serpstat_client)
    allow(PromptValueEstimator::Normalizer).to receive(:new).and_return(mock_normalizer)

    # Mock the normalizer to return simple variants
    allow(mock_normalizer).to receive(:normalize).and_return({
                                                               'head' => ['test prompt'],
                                                               'mid' => ['test prompt variant'],
                                                               'long' => ['long test prompt variant']
                                                             })

    # Mock the serpstat client to return volume data
    allow(mock_serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                             keyword: 'test prompt',
                                                                             search_volume: 1000,
                                                                             cpc: 1.50,
                                                                             competition: 0.60,
                                                                             results_count: 500_000,
                                                                             source: 'serpstat'
                                                                           })
  end

  describe 'caching in estimate_volume' do
    it 'caches results and returns cached data on subsequent calls' do
      # First call should hit the API
      expect(mock_serpstat_client).to receive(:get_keyword_volume).exactly(3).times

      result1 = estimator.estimate_volume('test prompt')
      expect(result1[:estimates][:total]).to be >= 0

      # Second call should use cache
      result2 = estimator.estimate_volume('test prompt')
      expect(result2[:estimates][:total]).to eq(result1[:estimates][:total])

      # Third call should also use cache
      result3 = estimator.estimate_volume('test prompt')
      expect(result3[:estimates][:total]).to eq(result1[:estimates][:total])
    end

    it 'uses different cache keys for different prompts' do
      # First prompt
      result1 = estimator.estimate_volume('prompt one')
      expect(result1[:estimates][:total]).to be >= 0

      # Second prompt (different cache key)
      result2 = estimator.estimate_volume('prompt two')
      expect(result2[:estimates][:total]).to be >= 0

      # Both should be cached separately
      expect(estimator.cache.size).to eq(2)
    end

    it 'uses different cache keys for different regions' do
      # Same prompt, different regions
      result1 = estimator.estimate_volume('test prompt', 'us')
      result2 = estimator.estimate_volume('test prompt', 'tr')

      expect(result1[:estimates][:total]).to be >= 0
      expect(result2[:estimates][:total]).to be >= 0

      # Should have separate cache entries
      expect(estimator.cache.size).to eq(2)
    end
  end

  describe 'caching in get_related_prompts' do
    before do
      allow(mock_serpstat_client).to receive(:get_related_keywords).and_return([
                                                                                 { keyword: 'related1', search_volume: 500, cpc: 1.50, competition: 0.60,
                                                                                   source: 'serpstat' },
                                                                                 { keyword: 'related2', search_volume: 300, cpc: 0.80, competition: 0.40,
                                                                                   source: 'serpstat' }
                                                                               ])
    end

    it 'caches related prompts results' do
      # First call should hit the API
      expect(mock_serpstat_client).to receive(:get_related_keywords).once

      result1 = estimator.get_related_prompts('test prompt')
      expect(result1[:related_keywords].length).to eq(2)

      # Second call should use cache
      result2 = estimator.get_related_prompts('test prompt')
      expect(result2[:related_keywords].length).to eq(2)
      expect(result2[:related_keywords]).to eq(result1[:related_keywords])
    end
  end

  describe 'caching in get_keyword_suggestions' do
    before do
      allow(mock_serpstat_client).to receive(:get_keyword_suggestions).and_return([
                                                                                    { keyword: 'suggestion1', search_volume: 800, cpc: 2.00, competition: 0.70,
                                                                                      source: 'serpstat' },
                                                                                    { keyword: 'suggestion2', search_volume: 600, cpc: 1.20, competition: 0.50,
                                                                                      source: 'serpstat' }
                                                                                  ])
    end

    it 'caches keyword suggestions results' do
      # First call should hit the API
      expect(mock_serpstat_client).to receive(:get_keyword_suggestions).once

      result1 = estimator.get_keyword_suggestions('test prompt')
      expect(result1[:suggestions].length).to eq(2)

      # Second call should use cache
      result2 = estimator.get_keyword_suggestions('test prompt')
      expect(result2[:suggestions].length).to eq(2)
      expect(result2[:suggestions]).to eq(result1[:suggestions])
    end
  end

  describe 'cache configuration' do
    it 'uses configuration TTL values' do
      # The cache should be initialized with the configuration TTL
      expect(estimator.cache.instance_variable_get(:@ttl)).to eq(86_400) # 24 hours from config
    end

    it 'has reasonable default max size' do
      expect(estimator.cache.instance_variable_get(:@max_size)).to eq(1000)
    end
  end
end
