# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe PromptValueEstimator::Logger do
  let(:output) { StringIO.new }
  let(:logger) { described_class.new(output, Logger::DEBUG) }

  describe '#initialize' do
    it 'creates a logger with default output' do
      expect { described_class.new }.not_to raise_error
    end

    it 'creates a logger with custom output' do
      expect { described_class.new(output) }.not_to raise_error
    end

    it 'creates a logger with custom level' do
      custom_logger = described_class.new(output, Logger::DEBUG)
      expect(custom_logger.level).to eq(Logger::DEBUG)
    end
  end

  describe '#info' do
    it 'logs info message' do
      logger.info('Test info message')
      expect(output.string).to include('Test info message')
      expect(output.string).to include('[INFO]')
    end

    it 'includes context in log' do
      logger.info('Test message', { user_id: 123, action: 'test' })
      log_output = output.string
      expect(log_output).to include('Test message')
      expect(log_output).to include('user_id')
      expect(log_output).to include('123')
    end
  end

  describe '#warn' do
    it 'logs warning message' do
      logger.warn('Test warning message')
      expect(output.string).to include('Test warning message')
      expect(output.string).to include('[WARN]')
    end
  end

  describe '#error' do
    it 'logs error message' do
      logger.error('Test error message')
      expect(output.string).to include('Test error message')
      expect(output.string).to include('[ERROR]')
    end

    it 'includes error details when error object provided' do
      error = StandardError.new('Test error')
      error.set_backtrace(%w[line1 line2])

      logger.error('Error occurred', { error: error })
      log_output = output.string
      expect(log_output).to include('Error occurred')
      expect(log_output).to include('StandardError')
      expect(log_output).to include('Test error')
    end
  end

  describe '#debug' do
    it 'logs debug message' do
      logger.debug('Test debug message')
      expect(output.string).to include('Test debug message')
      expect(output.string).to include('[DEBUG]')
    end
  end

  describe 'log formatting' do
    it 'includes timestamp in logs' do
      logger.info('Test message')
      expect(output.string).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
    end

    it 'formats JSON output correctly' do
      logger.info('Test message', { key: 'value' })
      log_output = output.string
      # Find the JSON line (the last line that starts with a timestamp)
      json_line = log_output.lines.reverse.find { |line| line.match(/^\d{4}-\d{2}-\d{2}/) }
      expect { JSON.parse(json_line.split(': ', 2).last) }.not_to raise_error
    end
  end
end
