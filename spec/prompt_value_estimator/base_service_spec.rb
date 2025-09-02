# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe PromptValueEstimator::BaseService do
  let(:output) { StringIO.new }
  let(:logger) { PromptValueEstimator::Logger.new(output, Logger::DEBUG) }
  let(:configuration) { PromptValueEstimator::Configuration.new }
  let(:service) { described_class.new(configuration, logger) }

  describe '#initialize' do
    it 'creates service with default configuration and logger' do
      default_service = described_class.new
      expect(default_service.configuration).to be_a(PromptValueEstimator::Configuration)
      expect(default_service.logger).to be_a(PromptValueEstimator::Logger)
    end

    it 'creates service with custom configuration and logger' do
      expect(service.configuration).to eq(configuration)
      expect(service.logger).to eq(logger)
    end
  end

  describe 'logging methods' do
    it 'logs info messages with service context' do
      service.send(:log_info, 'Test info message')
      log_output = output.string
      expect(log_output).to include('Test info message')
      expect(log_output).to include('BaseService')
    end

    it 'logs warning messages with service context' do
      service.send(:log_warn, 'Test warning message')
      log_output = output.string
      expect(log_output).to include('Test warning message')
      expect(log_output).to include('BaseService')
    end

    it 'logs error messages with service context' do
      service.send(:log_error, 'Test error message')
      log_output = output.string
      expect(log_output).to include('Test error message')
      expect(log_output).to include('BaseService')
    end

    it 'logs debug messages with service context' do
      service.send(:log_debug, 'Test debug message')
      log_output = output.string
      expect(log_output).to include('Test debug message')
      expect(log_output).to include('BaseService')
    end
  end

  describe '#handle_error' do
    it 'logs error and re-raises it' do
      error = StandardError.new('Test error')

      expect { service.send(:handle_error, error) }.to raise_error(StandardError)

      log_output = output.string
      expect(log_output).to include('Service error occurred')
      expect(log_output).to include('Test error')
    end

    it 'includes additional context in error log' do
      error = StandardError.new('Test error')

      expect { service.send(:handle_error, error, { user_id: 123 }) }.to raise_error(StandardError)

      log_output = output.string
      expect(log_output).to include('user_id')
      expect(log_output).to include('123')
    end
  end

  describe '#validate_presence' do
    it 'raises ValidationError for nil value' do
      expect { service.send(:validate_presence, nil, 'field_name') }
        .to raise_error(PromptValueEstimator::ValidationError, 'field_name cannot be blank')
    end

    it 'raises ValidationError for empty string' do
      expect { service.send(:validate_presence, '', 'field_name') }
        .to raise_error(PromptValueEstimator::ValidationError, 'field_name cannot be blank')
    end

    it 'raises ValidationError for empty array' do
      expect { service.send(:validate_presence, [], 'field_name') }
        .to raise_error(PromptValueEstimator::ValidationError, 'field_name cannot be blank')
    end

    it 'does not raise error for valid value' do
      expect { service.send(:validate_presence, 'valid', 'field_name') }.not_to raise_error
    end
  end

  describe '#validate_type' do
    it 'raises ValidationError for wrong type' do
      expect { service.send(:validate_type, 'string', Integer, 'field_name') }
        .to raise_error(PromptValueEstimator::ValidationError, 'field_name must be a Integer')
    end

    it 'does not raise error for correct type' do
      expect { service.send(:validate_type, 123, Integer, 'field_name') }.not_to raise_error
    end
  end

  describe '#retry_with_backoff' do
    it 'succeeds on first attempt' do
      result = service.send(:retry_with_backoff) { 'success' }
      expect(result).to eq('success')
    end

    it 'retries and succeeds on second attempt' do
      attempts = 0
      result = service.send(:retry_with_backoff) do
        attempts += 1
        raise StandardError, 'Temporary error' if attempts == 1

        'success'
      end

      expect(result).to eq('success')
      expect(attempts).to eq(2)
    end

    it 'fails after max attempts' do
      expect do
        service.send(:retry_with_backoff, max_attempts: 2) do
          raise StandardError, 'Persistent error'
        end
      end.to raise_error(StandardError, 'Persistent error')
    end

    it 'logs retry attempts' do
      attempts = 0
      begin
        service.send(:retry_with_backoff, max_attempts: 2) do
          attempts += 1
          raise StandardError, 'Temporary error'
        end
      rescue StandardError
        # Expected to fail
      end

      log_output = output.string
      expect(log_output).to include('Retry attempt 1')
    end

    it 'logs max retry attempts reached' do
      attempts = 0
      begin
        service.send(:retry_with_backoff, max_attempts: 2) do
          attempts += 1
          raise StandardError, 'Temporary error'
        end
      rescue StandardError
        # Expected to fail
      end

      log_output = output.string
      expect(log_output).to include('Max retry attempts reached')
    end
  end
end
