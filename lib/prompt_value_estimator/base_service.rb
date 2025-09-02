# frozen_string_literal: true

module PromptValueEstimator
  class BaseService
    attr_reader :logger, :configuration

    def initialize(configuration = nil, logger = nil)
      @configuration = configuration || PromptValueEstimator::Configuration.new
      @logger = logger || PromptValueEstimator::Logger.new
    end

    protected

    def log_info(message, context = {})
      logger.info(message, context.merge(service: self.class.name))
    end

    def log_warn(message, context = {})
      logger.warn(message, context.merge(service: self.class.name))
    end

    def log_error(message, context = {})
      logger.error(message, context.merge(service: self.class.name))
    end

    def log_debug(message, context = {})
      logger.debug(message, context.merge(service: self.class.name))
    end

    def handle_error(error, context = {})
      log_error('Service error occurred', context.merge(error: error))
      raise error
    end

    def validate_presence(value, field_name)
      return unless value.nil? || (value.respond_to?(:empty?) && value.empty?)

      raise ValidationError, "#{field_name} cannot be blank"
    end

    def validate_type(value, expected_type, field_name)
      return if value.is_a?(expected_type)

      raise ValidationError, "#{field_name} must be a #{expected_type}"
    end

    def retry_with_backoff(max_attempts: 3, base_delay: 1.0)
      attempt = 0
      begin
        attempt += 1
        yield
      rescue StandardError => e
        if attempt < max_attempts
          delay = base_delay * (2**(attempt - 1))
          log_warn("Retry attempt #{attempt} after #{delay}s", error: e)
          sleep(delay)
          retry
        else
          log_error('Max retry attempts reached', error: e)
          raise e
        end
      end
    end
  end
end
