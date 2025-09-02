# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::Configuration do
  let(:config_path) { File.join(File.dirname(__FILE__), '..', '..', 'config', 'config.yml') }
  let(:configuration) { described_class.new(config_path) }

  describe '#initialize' do
    it 'loads configuration from file' do
      expect(configuration.providers).to be_a(Hash)
      expect(configuration.normalize).to be_a(Hash)
      expect(configuration.estimate).to be_a(Hash)
      expect(configuration.cache).to be_a(Hash)
      expect(configuration.output).to be_a(Hash)
    end

    it 'uses default config path when none provided' do
      config = described_class.new
      expect(config.providers).to be_a(Hash)
    end

    it 'raises error for non-existent config file' do
      expect { described_class.new('/nonexistent/path.yml') }
        .to raise_error(PromptValueEstimator::ConfigurationError, /Configuration file not found/)
    end
  end

  describe 'environment variable interpolation' do
    before do
      @original_serpstat_key = ENV['SERPSTAT_API_KEY']
      @original_dataforseo_login = ENV['DATAFORSEO_LOGIN']
      @original_dataforseo_password = ENV['DATAFORSEO_PASSWORD']
    end

    after do
      ENV['SERPSTAT_API_KEY'] = @original_serpstat_key
      ENV['DATAFORSEO_LOGIN'] = @original_dataforseo_login
      ENV['DATAFORSEO_PASSWORD'] = @original_dataforseo_password
    end

    it 'interpolates SERPSTAT_API_KEY environment variable' do
      ENV['SERPSTAT_API_KEY'] = 'test_api_key_123'
      config = described_class.new(config_path)
      
      expect(config.providers['serpstat']['api_key']).to eq('test_api_key_123')
    end

    it 'interpolates DATAFORSEO_LOGIN environment variable' do
      ENV['DATAFORSEO_LOGIN'] = 'test_login'
      config = described_class.new(config_path)
      
      expect(config.providers['dataforseo']['login']).to eq('test_login')
    end

    it 'interpolates DATAFORSEO_PASSWORD environment variable' do
      ENV['DATAFORSEO_PASSWORD'] = 'test_password'
      config = described_class.new(config_path)
      
      expect(config.providers['dataforseo']['password']).to eq('test_password')
    end

    it 'handles missing environment variables gracefully' do
      ENV.delete('SERPSTAT_API_KEY')
      ENV.delete('DATAFORSEO_LOGIN')
      ENV.delete('DATAFORSEO_PASSWORD')
      
      config = described_class.new(config_path)
      
      expect(config.providers['serpstat']['api_key']).to eq('${SERPSTAT_API_KEY}')
      expect(config.providers['dataforseo']['login']).to eq('${DATAFORSEO_LOGIN}')
      expect(config.providers['dataforseo']['password']).to eq('${DATAFORSEO_PASSWORD}')
    end
  end

  describe '#provider_enabled?' do
    it 'returns true for enabled providers' do
      expect(configuration.provider_enabled?('serpstat')).to be true
    end

    it 'returns false for disabled providers' do
      expect(configuration.provider_enabled?('dataforseo')).to be false
    end

    it 'returns false for non-existent providers' do
      expect(configuration.provider_enabled?('nonexistent')).to be false
    end

    it 'handles string and symbol inputs' do
      expect(configuration.provider_enabled?('serpstat')).to be true
      expect(configuration.provider_enabled?(:serpstat)).to be true
    end
  end

  describe '#provider_config' do
    it 'returns provider configuration hash' do
      serpstat_config = configuration.provider_config('serpstat')
      expect(serpstat_config).to include('api_key', 'default_region', 'enabled')
    end

    it 'returns empty hash for non-existent providers' do
      expect(configuration.provider_config('nonexistent')).to eq({})
    end

    it 'handles string and symbol inputs' do
      expect(configuration.provider_config('serpstat')).to eq(configuration.provider_config(:serpstat))
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

    it 'returns 0.0 for unknown types' do
      expect(configuration.weight_for_type('unknown')).to eq(0.0)
    end

    it 'handles string and symbol inputs' do
      expect(configuration.weight_for_type('head')).to eq(configuration.weight_for_type(:head))
    end
  end

  describe '#locale_bias' do
    it 'returns correct bias for US locale' do
      expect(configuration.locale_bias('us')).to eq(1.0)
    end

    it 'returns correct bias for TR locale' do
      expect(configuration.locale_bias('tr')).to eq(0.9)
    end

    it 'returns correct bias for DE locale' do
      expect(configuration.locale_bias('de')).to eq(0.95)
    end

    it 'returns 1.0 for unknown locales' do
      expect(configuration.locale_bias('unknown')).to eq(1.0)
    end

    it 'handles string and symbol inputs' do
      expect(configuration.locale_bias('us')).to eq(configuration.locale_bias(:us))
    end
  end

  describe '#max_variants' do
    it 'returns configured max variants' do
      expect(configuration.max_variants).to eq(15)
    end

    it 'returns default when not configured' do
      # Create a config without max_variants
      allow(configuration).to receive(:normalize).and_return({})
      expect(configuration.max_variants).to eq(15)
    end
  end

  describe '#stopwords' do
    it 'returns configured stopwords array' do
      stopwords = configuration.stopwords
      expect(stopwords).to be_an(Array)
      expect(stopwords).to include('the', 'a', 'an', 'and', 'or', 'but')
    end

    it 'returns empty array when not configured' do
      # Create a minimal config file without stopwords
      temp_config = Tempfile.new(['config', '.yml'])
      temp_config.write(<<~YAML)
        providers:
          serpstat:
            api_key: test_key
            default_region: us
            enabled: true
        normalize: {}
        estimate: {}
        cache: {}
        output: {}
      YAML
      temp_config.close

      config = described_class.new(temp_config.path)
      expect(config.stopwords).to eq([])

      temp_config.unlink
    end
  end

  describe '#cache_enabled?' do
    it 'returns true when cache is enabled' do
      expect(configuration.cache_enabled?).to be true
    end

    it 'returns false when cache is disabled' do
      # Create a config file with cache disabled
      temp_config = Tempfile.new(['config', '.yml'])
      temp_config.write(<<~YAML)
        providers:
          serpstat:
            api_key: test_key
            default_region: us
            enabled: true
        normalize: {}
        estimate: {}
        cache:
          enabled: false
          ttl_seconds: 3600
        output: {}
      YAML
      temp_config.close

      config = described_class.new(temp_config.path)
      expect(config.cache_enabled?).to be false

      temp_config.unlink
    end

    it 'returns false when cache config is missing' do
      # Create a config file without cache section
      temp_config = Tempfile.new(['config', '.yml'])
      temp_config.write(<<~YAML)
        providers:
          serpstat:
            api_key: test_key
            default_region: us
            enabled: true
        normalize: {}
        estimate: {}
        output: {}
      YAML
      temp_config.close

      config = described_class.new(temp_config.path)
      expect(config.cache_enabled?).to be false

      temp_config.unlink
    end
  end

  describe '#cache_ttl' do
    it 'returns configured TTL in seconds' do
      expect(configuration.cache_ttl).to eq(86_400)
    end

    it 'returns default TTL when not configured' do
      allow(configuration).to receive(:cache).and_return({})
      expect(configuration.cache_ttl).to eq(86_400)
    end
  end

  describe '#top_n' do
    it 'returns configured top N value' do
      expect(configuration.top_n).to eq(10)
    end

    it 'returns default when not configured' do
      allow(configuration).to receive(:output).and_return({})
      expect(configuration.top_n).to eq(10)
    end
  end

  describe 'configuration structure validation' do
    it 'has required provider configurations' do
      expect(configuration.providers['serpstat']).to include('api_key', 'default_region', 'enabled')
      expect(configuration.providers['dataforseo']).to include('enabled', 'login', 'password')
    end

    it 'has required normalization settings' do
      expect(configuration.normalize).to include('max_variants', 'include_question_forms', 'stopwords')
    end

    it 'has required estimation settings' do
      expect(configuration.estimate).to include('weights', 'locale_bias', 'confidence')
    end

    it 'has required cache settings' do
      expect(configuration.cache).to include('ttl_seconds', 'enabled')
    end

    it 'has required output settings' do
      expect(configuration.output).to include('topN', 'include_breakdown', 'include_assumptions')
    end
  end

  describe 'error handling' do
    it 'raises ConfigurationError for invalid YAML' do
      # Create a temporary invalid YAML file
      temp_config = Tempfile.new(['config', '.yml'])
      temp_config.write("invalid: yaml: content: [")
      temp_config.close

      expect { described_class.new(temp_config.path) }
        .to raise_error(PromptValueEstimator::ConfigurationError, /Invalid YAML in configuration file/)

      temp_config.unlink
    end
  end
end
