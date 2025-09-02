# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::Estimator do
  let(:output) { StringIO.new }
  let(:logger) { PromptValueEstimator::Logger.new(output, Logger::DEBUG) }
  let(:configuration) { PromptValueEstimator::Configuration.new }
  let(:estimator) { described_class.new(configuration, logger) }

  describe '#initialize' do
    it 'creates estimator with configuration and logger' do
      expect(estimator.normalizer).to be_a(PromptValueEstimator::Normalizer)
      expect(estimator.serpstat_client).to be_a(PromptValueEstimator::SerpstatClient)
    end

    it 'creates estimator with defaults' do
      default_estimator = described_class.new
      expect(default_estimator.normalizer).to be_a(PromptValueEstimator::Normalizer)
      expect(default_estimator.serpstat_client).to be_a(PromptValueEstimator::SerpstatClient)
    end
  end

  describe '#estimate_volume' do
    it 'validates prompt presence' do
      expect { estimator.estimate_volume(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompt cannot be blank')
      expect { estimator.estimate_volume('') }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompt cannot be blank')
    end

    it 'validates prompt type' do
      expect { estimator.estimate_volume(123) }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompt must be a String')
    end

    it 'returns complete estimation result structure' do
      # Mock the dependencies
      allow(estimator.normalizer).to receive(:normalize).and_return({
                                                                      head: %w[test keyword],
                                                                      mid: ['test keyword'],
                                                                      long: ['how to test keyword',
                                                                             'test keyword?']
                                                                    })

      allow(estimator.serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                                    keyword: 'test',
                                                                                    search_volume: 1000,
                                                                                    cpc: 1.50,
                                                                                    competition: 0.60,
                                                                                    results_count: 500_000,
                                                                                    trend: [100,
                                                                                            120],
                                                                                    source: 'serpstat'
                                                                                  })

      result = estimator.estimate_volume('test keyword')

      expect(result).to have_key(:prompt)
      expect(result).to have_key(:region)
      expect(result).to have_key(:estimates)
      expect(result).to have_key(:confidence)
      expect(result).to have_key(:variants)
      expect(result).to have_key(:volume_data)
      expect(result).to have_key(:metadata)

      expect(result[:estimates]).to have_key(:head)
      expect(result[:estimates]).to have_key(:mid)
      expect(result[:estimates]).to have_key(:long)
      expect(result[:estimates]).to have_key(:total)
    end

    it 'uses default region when none specified' do
      allow(estimator.normalizer).to receive(:normalize).and_return({
                                                                      head: ['test'],
                                                                      mid: [],
                                                                      long: []
                                                                    })

      allow(estimator.serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                                    keyword: 'test',
                                                                                    search_volume: 1000,
                                                                                    cpc: 1.50,
                                                                                    competition: 0.60,
                                                                                    results_count: 500_000,
                                                                                    trend: [],
                                                                                    source: 'serpstat'
                                                                                  })

      result = estimator.estimate_volume('test')
      expect(result[:region]).to eq('us')
    end

    it 'uses specified region' do
      allow(estimator.normalizer).to receive(:normalize).and_return({
                                                                      head: ['test'],
                                                                      mid: [],
                                                                      long: []
                                                                    })

      allow(estimator.serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                                    keyword: 'test',
                                                                                    search_volume: 1000,
                                                                                    cpc: 1.50,
                                                                                    competition: 0.60,
                                                                                    results_count: 500_000,
                                                                                    trend: [],
                                                                                    source: 'serpstat'
                                                                                  })

      result = estimator.estimate_volume('test', 'tr')
      expect(result[:region]).to eq('tr')
    end
  end

  describe '#estimate_batch' do
    it 'validates prompts presence' do
      expect { estimator.estimate_batch(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompts cannot be blank')
      expect { estimator.estimate_batch([]) }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompts cannot be blank')
    end

    it 'validates prompts type' do
      expect { estimator.estimate_batch('not an array') }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompts must be a Array')
    end

    it 'processes multiple prompts successfully' do
      allow(estimator.normalizer).to receive(:normalize).and_return({
                                                                      head: ['test'],
                                                                      mid: [],
                                                                      long: []
                                                                    })

      allow(estimator.serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                                    keyword: 'test',
                                                                                    search_volume: 1000,
                                                                                    cpc: 1.50,
                                                                                    competition: 0.60,
                                                                                    results_count: 500_000,
                                                                                    trend: [],
                                                                                    source: 'serpstat'
                                                                                  })

      prompts = ['test keyword', 'another test']
      results = estimator.estimate_batch(prompts)

      expect(results.length).to eq(2)
      expect(results.first[:prompt]).to eq('test keyword')
      expect(results.last[:prompt]).to eq('another test')
    end

    it 'handles errors gracefully in batch processing' do
      allow(estimator.normalizer).to receive(:normalize).and_return({
                                                                      head: ['test'],
                                                                      mid: [],
                                                                      long: []
                                                                    })

      # First call succeeds, second call fails
      call_count = 0
      allow(estimator.serpstat_client).to receive(:get_keyword_volume) do
        call_count += 1
        raise StandardError, 'API error' unless call_count == 1

        {
          keyword: 'test',
          search_volume: 1000,
          cpc: 1.50,
          competition: 0.60,
          results_count: 500_000,
          trend: [],
          source: 'serpstat'
        }
      end

      prompts = ['test keyword', 'another test']
      results = estimator.estimate_batch(prompts)

      expect(results.length).to eq(2)
      expect(results.first[:error]).to be_nil
      # The second prompt should have an error in the volume data, not in the result
      expect(results.last[:volume_data].first[:error]).to eq('API error')
      expect(results.last[:estimates][:total]).to eq(0)
    end
  end

  describe 'volume data fetching' do
    it 'fetches volume data for all variants' do
      variants = {
        head: %w[test keyword],
        mid: ['test keyword'],
        long: ['how to test keyword']
      }

      allow(estimator.serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                                    keyword: 'test',
                                                                                    search_volume: 1000,
                                                                                    cpc: 1.50,
                                                                                    competition: 0.60,
                                                                                    results_count: 500_000,
                                                                                    trend: [],
                                                                                    source: 'serpstat'
                                                                                  })

      volume_data = estimator.send(:fetch_volume_data, variants, 'us')

      expect(volume_data.length).to eq(4)
      expect(volume_data.first[:variant_type]).to eq(:head)
      expect(volume_data.first[:original_variant]).to eq('test')
    end

    it 'handles API errors gracefully' do
      variants = {
        head: ['test'],
        mid: [],
        long: []
      }

      allow(estimator.serpstat_client).to receive(:get_keyword_volume)
        .and_raise(StandardError.new('API error'))

      volume_data = estimator.send(:fetch_volume_data, variants, 'us')

      expect(volume_data.length).to eq(1)
      expect(volume_data.first[:error]).to eq('API error')
      expect(volume_data.first[:search_volume]).to eq(0)
    end
  end

  describe 'weighted estimates calculation' do
    it 'calculates weighted estimates correctly' do
      variants = {
        head: %w[test keyword],
        mid: ['test keyword'],
        long: ['how to test keyword']
      }

      volume_data = [
        { variant_type: :head, search_volume: 1000, error: nil },
        { variant_type: :head, search_volume: 800, error: nil },
        { variant_type: :mid, search_volume: 600, error: nil },
        { variant_type: :long, search_volume: 400, error: nil }
      ]

      estimates = estimator.send(:calculate_weighted_estimates, variants, volume_data)

      expect(estimates[:head]).to be > 0
      expect(estimates[:mid]).to be > 0
      expect(estimates[:long]).to be > 0
      expect(estimates[:total]).to be > 0
    end

    it 'handles empty variant types' do
      variants = {
        head: [],
        mid: [],
        long: ['test keyword']
      }

      volume_data = [
        { variant_type: :long, search_volume: 400, error: nil }
      ]

      estimates = estimator.send(:calculate_weighted_estimates, variants, volume_data)

      expect(estimates[:head]).to eq(0)
      expect(estimates[:mid]).to eq(0)
      expect(estimates[:long]).to be > 0
    end

    it 'applies locale bias correctly' do
      variants = {
        head: ['test'],
        mid: [],
        long: []
      }

      volume_data = [
        { variant_type: :head, search_volume: 1000, error: nil }
      ]

      # Mock configuration to return different locale biases
      allow(configuration).to receive(:estimate).and_return({
                                                              'weights' => { 'head' => 0.5,
                                                                             'mid' => 0.35, 'long' => 0.15 },
                                                              'locale_bias' => { 'us' => 0.9,
                                                                                 'tr' => 0.8, 'de' => 0.85 }
                                                            })

      estimates = estimator.send(:calculate_weighted_estimates, variants, volume_data)

      # Should apply 0.9 locale bias for 'us' region
      expect(estimates[:head]).to be < 500 # 1000 * 0.5 * 0.9 = 450
    end
  end

  describe 'confidence scoring' do
    it 'calculates base confidence score' do
      variants = { head: ['test'], mid: [], long: [] }
      volume_data = [{ variant_type: :head, search_volume: 1000, error: nil }]
      estimates = { head: 500, mid: 0, long: 0, total: 500 }

      confidence = estimator.send(:calculate_confidence_score, variants, volume_data, estimates)

      expect(confidence).to be >= 0.5 # Base score
      expect(confidence).to be <= 1.0
    end

    it 'applies source bonus correctly' do
      variants = { head: ['test'], mid: [], long: [] }
      volume_data = [
        { variant_type: :head, search_volume: 1000, source: 'serpstat', error: nil },
        { variant_type: :head, search_volume: 800, source: 'another_source', error: nil }
      ]
      estimates = { head: 500, mid: 0, long: 0, total: 500 }

      confidence = estimator.send(:calculate_confidence_score, variants, volume_data, estimates)

      # Should have higher confidence due to multiple sources
      expect(confidence).to be > 0.5
    end

    it 'applies variant bonus correctly' do
      variants = {
        head: %w[test keyword example],
        mid: ['test keyword'],
        long: ['how to test keyword']
      }
      volume_data = [{ variant_type: :head, search_volume: 1000, error: nil }]
      estimates = { head: 500, mid: 0, long: 0, total: 500 }

      confidence = estimator.send(:calculate_confidence_score, variants, volume_data, estimates)

      # Should have higher confidence due to more variants
      expect(confidence).to be > 0.5
    end

    it 'applies data quality bonus correctly' do
      variants = { head: ['test'], mid: [], long: [] }
      volume_data = [
        { variant_type: :head, search_volume: 1000, error: nil },
        { variant_type: :head, search_volume: 800, error: nil }
      ]
      estimates = { head: 500, mid: 0, long: 0, total: 500 }

      confidence = estimator.send(:calculate_confidence_score, variants, volume_data, estimates)

      # Should have higher confidence due to good data quality
      expect(confidence).to be > 0.5
    end

    it 'applies competition bonus correctly' do
      variants = { head: ['test'], mid: [], long: [] }
      volume_data = [
        { variant_type: :head, search_volume: 1000, competition: 0.3, error: nil }
      ]
      estimates = { head: 500, mid: 0, long: 0, total: 500 }

      confidence = estimator.send(:calculate_confidence_score, variants, volume_data, estimates)

      # Should have higher confidence due to low competition
      expect(confidence).to be > 0.5
    end

    it 'caps confidence at 1.0' do
      variants = { head: ['test'], mid: [], long: [] }
      volume_data = [
        { variant_type: :head, search_volume: 1000, source: 'serpstat', competition: 0.1,
          error: nil }
      ]
      estimates = { head: 500, mid: 0, long: 0, total: 500 }

      confidence = estimator.send(:calculate_confidence_score, variants, volume_data, estimates)

      expect(confidence).to be <= 1.0
    end
  end

  describe 'type estimate calculation' do
    it 'calculates type estimate correctly' do
      type_data = [
        { search_volume: 1000, error: nil },
        { search_volume: 800, error: nil },
        { search_volume: 1200, error: nil }
      ]

      weight = 0.5
      locale_bias = 1.0

      estimate = estimator.send(:calculate_type_estimate, type_data, weight, locale_bias)

      # Average: (1000 + 800 + 1200) / 3 = 1000
      # Applied weight: 1000 * 0.5 = 500
      # Applied locale bias: 500 * 1.0 = 500
      expect(estimate).to eq(500.0)
    end

    it 'returns 0 for empty type data' do
      estimate = estimator.send(:calculate_type_estimate, [], 0.5, 1.0)
      expect(estimate).to eq(0.0)
    end

    it 'filters out variants with errors' do
      type_data = [
        { search_volume: 1000, error: nil },
        { search_volume: 800, error: 'API error' },
        { search_volume: 1200, error: nil }
      ]

      weight = 0.5
      locale_bias = 1.0

      estimate = estimator.send(:calculate_type_estimate, type_data, weight, locale_bias)

      # Only 2 valid variants: (1000 + 1200) / 2 = 1100
      # Applied weight: 1100 * 0.5 = 550
      expect(estimate).to eq(550.0)
    end
  end

  describe 'logging' do
    it 'logs estimation process' do
      allow(estimator.normalizer).to receive(:normalize).and_return({
                                                                      head: ['test'],
                                                                      mid: [],
                                                                      long: []
                                                                    })

      allow(estimator.serpstat_client).to receive(:get_keyword_volume).and_return({
                                                                                    keyword: 'test',
                                                                                    search_volume: 1000,
                                                                                    cpc: 1.50,
                                                                                    competition: 0.60,
                                                                                    results_count: 500_000,
                                                                                    trend: [],
                                                                                    source: 'serpstat'
                                                                                  })

      estimator.estimate_volume('test keyword')

      log_output = output.string
      expect(log_output).to include('Starting volume estimation')
      expect(log_output).to include('Generated variants')
      expect(log_output).to include('Fetched volume data')
      expect(log_output).to include('Calculated estimates')
      expect(log_output).to include('Volume estimation completed')
    end
  end
end
