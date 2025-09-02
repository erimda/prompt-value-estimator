# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::Configuration do
  let(:config_path) { File.join(__dir__, '..', '..', 'config', 'config.yml') }
  let(:configuration) { described_class.new(config_path) }

  describe '#initialize' do
    it 'loads configuration from the specified path' do
      expect(configuration.providers).to be_a(Hash)
      expect(configuration.normalize).to be_a(Hash)
    end

    it 'loads all configuration sections' do
      expect(configuration.estimate).to be_a(Hash)
      expect(configuration.cache).to be_a(Hash)
      expect(configuration.output).to be_a(Hash)
    end

    it 'uses default config path when none specified' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe '#provider_enabled?' do
    it 'returns true for enabled providers' do
      expect(configuration.provider_enabled?('serpstat')).to be true
    end

    it 'returns false for disabled providers' do
      expect(configuration.provider_enabled?('dataforseo')).to be false
    end

    it 'returns false for unknown providers' do
      expect(configuration.provider_enabled?('unknown')).to be false
    end
  end

  describe '#provider_config' do
    it 'returns provider configuration hash' do
      config = configuration.provider_config('serpstat')
      expect(config).to include('enabled', 'default_region')
    end

    it 'returns empty hash for unknown providers' do
      config = configuration.provider_config('unknown')
      expect(config).to eq({})
    end
  end

  describe '#weight_for_type' do
    it 'returns correct weight for head type' do
      expect(configuration.weight_for_type('head')).to eq(0.5)
    end

    it 'returns correct weight for mid type' do
      expect(configuration.weight_for_type('mid')).to eq(0.35)
    end

    it 'returns correct weight for long type' do
      expect(configuration.weight_for_type('long')).to eq(0.15)
    end

    it 'returns 0.0 for unknown type' do
      expect(configuration.weight_for_type('unknown')).to eq(0.0)
    end
  end

  describe '#locale_bias' do
    it 'returns correct bias for US locale' do
      expect(configuration.locale_bias('us')).to eq(1.0)
    end

    it 'returns correct bias for TR locale' do
      expect(configuration.locale_bias('tr')).to eq(0.9)
    end

    it 'returns 1.0 for unknown locale' do
      expect(configuration.locale_bias('unknown')).to eq(1.0)
    end
  end

  describe '#max_variants' do
    it 'returns configured max variants' do
      expect(configuration.max_variants).to eq(15)
    end
  end

  describe '#stopwords' do
    it 'returns array of stopwords' do
      expect(configuration.stopwords).to be_an(Array)
      expect(configuration.stopwords).to include('the', 'a', 'an')
    end
  end

  describe '#cache_enabled?' do
    it 'returns true when cache is enabled' do
      expect(configuration.cache_enabled?).to be true
    end
  end

  describe '#cache_ttl' do
    it 'returns configured TTL in seconds' do
      expect(configuration.cache_ttl).to eq(86_400)
    end
  end

  describe '#top_n' do
    it 'returns configured top N value' do
      expect(configuration.top_n).to eq(10)
    end
  end

  context 'with invalid configuration file' do
    it 'raises ConfigurationError for missing file' do
      expect { described_class.new('/nonexistent/path.yml') }
        .to raise_error(PromptValueEstimator::ConfigurationError)
    end
  end
end
