# frozen_string_literal: true

module PromptValueEstimator
  # Base error class for all application errors
  class Error < StandardError; end

  # Provider/API related errors
  class ProviderError < Error; end
  class ProviderRateLimitError < ProviderError; end
  class ProviderAuthenticationError < ProviderError; end
  class ProviderConnectionError < ProviderError; end

  # Normalization related errors
  class NormalizationError < Error; end

  # Estimation related errors
  class EstimationError < Error; end

  # Cache related errors
  class CacheError < Error; end

  # Input validation errors
  class ValidationError < Error; end
end
