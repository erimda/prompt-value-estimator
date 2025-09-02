# frozen_string_literal: true

require 'time'

module PromptValueEstimator
  class Cache
    def initialize(config = {})
      @store = {}
      @ttl = config[:ttl] || 3600 # Default 1 hour
      @max_size = config[:max_size] || 1000
    end

    def get(key)
      entry = @store[key]
      return nil unless entry

      if expired?(entry)
        delete(key)
        return nil
      end

      entry[:value]
    end

    def set(key, value, ttl = nil)
      ttl ||= @ttl
      @store[key] = {
        value: value,
        expires_at: Time.now + ttl
      }

      cleanup_if_needed
      value
    end

    def delete(key)
      @store.delete(key)
    end

    def clear
      @store.clear
    end

    def size
      @store.size
    end

    def keys
      @store.keys
    end

    def exists?(key)
      entry = @store[key]
      return false unless entry

      if expired?(entry)
        delete(key)
        return false
      end

      true
    end

    private

    def expired?(entry)
      Time.now > entry[:expires_at]
    end

    def cleanup_if_needed
      return if @store.size <= @max_size

      # Remove expired entries first
      expired_keys = @store.select { |_key, entry| expired?(entry) }.keys
      expired_keys.each { |key| delete(key) }

      # If still over limit, remove oldest entries
      return if @store.size <= @max_size

      sorted_entries = @store.sort_by { |_key, entry| entry[:expires_at] }
      entries_to_remove = @store.size - @max_size
      entries_to_remove.times do |i|
        delete(sorted_entries[i][0])
      end
    end
  end
end
