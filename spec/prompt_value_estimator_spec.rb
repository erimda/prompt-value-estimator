# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator do
  describe 'Error classes' do
    describe PromptValueEstimator::Error do
      it 'inherits from StandardError' do
        expect(described_class).to be < StandardError
      end
    end

    describe PromptValueEstimator::ProviderError do
      it 'inherits from Error' do
        expect(described_class).to be < PromptValueEstimator::Error
      end
    end

    describe PromptValueEstimator::ProviderRateLimitError do
      it 'inherits from ProviderError' do
        expect(described_class).to be < PromptValueEstimator::ProviderError
      end
    end

    describe PromptValueEstimator::ProviderAuthenticationError do
      it 'inherits from ProviderError' do
        expect(described_class).to be < PromptValueEstimator::ProviderError
      end
    end

    describe PromptValueEstimator::ProviderConnectionError do
      it 'inherits from ProviderError' do
        expect(described_class).to be < PromptValueEstimator::ProviderError
      end
    end

    describe PromptValueEstimator::NormalizationError do
      it 'inherits from Error' do
        expect(described_class).to be < PromptValueEstimator::Error
      end
    end

    describe PromptValueEstimator::EstimationError do
      it 'inherits from Error' do
        expect(described_class).to be < PromptValueEstimator::Error
      end
    end

    describe PromptValueEstimator::CacheError do
      it 'inherits from Error' do
        expect(described_class).to be < PromptValueEstimator::Error
      end
    end

    describe PromptValueEstimator::ValidationError do
      it 'inherits from Error' do
        expect(described_class).to be < PromptValueEstimator::Error
      end
    end
  end
end
