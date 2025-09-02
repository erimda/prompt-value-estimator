# frozen_string_literal: true

require 'logger'
require 'json'

module PromptValueEstimator
  class Logger
    attr_reader :logger, :level

    def initialize(output = $stdout, level = ::Logger::INFO)
      @logger = ::Logger.new(output)
      @logger.level = level
      @logger.formatter = create_formatter
      @level = level
    end

    def info(message, context = {})
      log(:info, message, context)
    end

    def warn(message, context = {})
      log(:warn, message, context)
    end

    def error(message, context = {})
      log(:error, message, context)
    end

    def debug(message, context = {})
      log(:debug, message, context)
    end

    def log(level, message, context = {})
      formatted_message = format_message(level, message, context)
      @logger.send(level, formatted_message)
    end

    private

    def create_formatter
      proc do |severity, datetime, progname, msg|
        if msg.is_a?(String) && msg.start_with?('{')
          # JSON message, format it nicely
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{progname}: #{msg}\n"
        else
          # Regular message
          timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
          "#{timestamp} [#{severity}] #{progname}: #{msg}\n"
        end
      end
    end

    def format_message(level, message, context)
      log_data = {
        level: level.to_s.upcase,
        message: message,
        timestamp: Time.now.iso8601,
        context: context
      }

      if context[:error].is_a?(Exception)
        log_data[:error] = {
          class: context[:error].class.name,
          message: context[:error].message,
          backtrace: context[:error].backtrace&.first(5)
        }
      end

      log_data.to_json
    end
  end
end
