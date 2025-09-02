# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Error Handling' do
  describe 'ConfigurationError' do
    it 'provides helpful error messages for missing config files' do
      expect { PromptValueEstimator::Configuration.new('/nonexistent/path.yml') }
        .to raise_error(PromptValueEstimator::ConfigurationError, /Configuration file not found/)
    end

    it 'provides helpful error messages for invalid YAML' do
      temp_config = Tempfile.new(['config', '.yml'])
      temp_config.write("invalid: yaml: content: [")
      temp_config.close

      expect { PromptValueEstimator::Configuration.new(temp_config.path) }
        .to raise_error(PromptValueEstimator::ConfigurationError, /Invalid YAML in configuration file/)

      temp_config.unlink
    end
  end

  describe 'ValidationError' do
    it 'provides clear validation error messages' do
      estimator = PromptValueEstimator::Estimator.new

      expect { estimator.estimate_volume(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, /prompt cannot be blank/)

      expect { estimator.estimate_volume(123) }
        .to raise_error(PromptValueEstimator::ValidationError, /prompt must be a String/)
    end
  end

  describe 'ProviderError' do
    it 'provides clear provider error messages' do
      # Test that provider errors are properly categorized
      expect(PromptValueEstimator::ProviderError.new('Test error')).to be_a(StandardError)
    end
  end

  describe 'ProviderRateLimitError' do
    it 'provides clear rate limit error messages' do
      error = PromptValueEstimator::ProviderRateLimitError.new('API rate limit exceeded')
      expect(error.message).to eq('API rate limit exceeded')
      expect(error).to be_a(PromptValueEstimator::ProviderError)
    end
  end

  describe 'ProviderAuthenticationError' do
    it 'provides clear authentication error messages' do
      error = PromptValueEstimator::ProviderAuthenticationError.new('Invalid API key')
      expect(error.message).to eq('Invalid API key')
      expect(error).to be_a(PromptValueEstimator::ProviderError)
    end
  end

  describe 'ProviderConnectionError' do
    it 'provides clear connection error messages' do
      error = PromptValueEstimator::ProviderConnectionError.new('Connection timeout')
      expect(error.message).to eq('Connection timeout')
      expect(error).to be_a(PromptValueEstimator::ProviderError)
    end
  end

  describe 'CLI error handling' do
    it 'provides user-friendly error messages' do
      # Test CLI error handling
      cli = PromptValueEstimator::CLI.new

      # Test with invalid command
      expect { cli.send(:execute_command) }
        .to raise_error(SystemExit)

      # Test with missing prompt
      expect { cli.send(:estimate_volume) }
        .to raise_error(ArgumentError, 'Prompt is required')
    end
  end

  describe 'Cache error handling' do
    it 'handles cache errors gracefully' do
      cache = PromptValueEstimator::Cache.new

      # Test that cache operations don't raise unexpected errors
      expect { cache.get('nonexistent') }.not_to raise_error
      expect { cache.delete('nonexistent') }.not_to raise_error
      expect { cache.exists?('nonexistent') }.not_to raise_error
    end
  end

  describe 'Normalizer error handling' do
    it 'handles normalization errors gracefully' do
      normalizer = PromptValueEstimator::Normalizer.new

      # Test with nil input
      expect { normalizer.normalize(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, /prompt cannot be blank/)

      # Test with non-string input
      expect { normalizer.normalize(123) }
        .to raise_error(PromptValueEstimator::ValidationError, /prompt must be a String/)
    end
  end

  describe 'SerpstatClient error handling' do
    it 'provides clear API error messages' do
      client = PromptValueEstimator::SerpstatClient.new

      # Test validation errors
      expect { client.get_keyword_volume(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, /keyword cannot be blank/)

      expect { client.get_keyword_volume(123) }
        .to raise_error(PromptValueEstimator::ValidationError, /keyword must be a String/)
    end
  end

  describe 'Error inheritance hierarchy' do
    it 'maintains proper error inheritance' do
      # All provider errors should inherit from ProviderError
      expect(PromptValueEstimator::ProviderRateLimitError).to be < PromptValueEstimator::ProviderError
      expect(PromptValueEstimator::ProviderAuthenticationError).to be < PromptValueEstimator::ProviderError
      expect(PromptValueEstimator::ProviderConnectionError).to be < PromptValueEstimator::ProviderError

      # ProviderError should inherit from StandardError
      expect(PromptValueEstimator::ProviderError).to be < StandardError

      # ValidationError should inherit from StandardError
      expect(PromptValueEstimator::ValidationError).to be < StandardError

      # ConfigurationError should inherit from StandardError
      expect(PromptValueEstimator::ConfigurationError).to be < StandardError
    end
  end

  describe 'User-friendly error messages' do
    it 'provides actionable error messages' do
      # Test that error messages are helpful and actionable
      expect { PromptValueEstimator::Configuration.new('/nonexistent/path.yml') }
        .to raise_error(PromptValueEstimator::ConfigurationError, /Configuration file not found/)

      # Test validation error messages
      estimator = PromptValueEstimator::Estimator.new
      expect { estimator.estimate_volume(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, /prompt cannot be blank/)
    end
  end
end
