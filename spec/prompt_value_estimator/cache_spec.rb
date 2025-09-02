# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::Cache do
  let(:cache) { described_class.new }
  let(:cache_with_custom_ttl) { described_class.new(ttl: 1800, max_size: 100) }

  describe '#initialize' do
    it 'creates cache with default configuration' do
      expect(cache.instance_variable_get(:@ttl)).to eq(3600)
      expect(cache.instance_variable_get(:@max_size)).to eq(1000)
    end

    it 'creates cache with custom configuration' do
      expect(cache_with_custom_ttl.instance_variable_get(:@ttl)).to eq(1800)
      expect(cache_with_custom_ttl.instance_variable_get(:@max_size)).to eq(100)
    end
  end

  describe '#set and #get' do
    it 'stores and retrieves values' do
      cache.set('key1', 'value1')
      expect(cache.get('key1')).to eq('value1')
    end

    it 'overwrites existing keys' do
      cache.set('key1', 'value1')
      cache.set('key1', 'value2')
      expect(cache.get('key1')).to eq('value2')
    end

    it 'returns nil for non-existent keys' do
      expect(cache.get('nonexistent')).to be_nil
    end
  end

  describe '#set with custom TTL' do
    it 'uses custom TTL when provided' do
      cache.set('key1', 'value1', 1) # 1 second TTL
      expect(cache.get('key1')).to eq('value1')

      sleep(1.1)
      expect(cache.get('key1')).to be_nil
    end

    it 'uses default TTL when not provided' do
      cache.set('key1', 'value1')
      expect(cache.get('key1')).to eq('value1')
    end
  end

  describe '#delete' do
    it 'removes existing keys' do
      cache.set('key1', 'value1')
      cache.delete('key1')
      expect(cache.get('key1')).to be_nil
    end

    it 'handles deleting non-existent keys gracefully' do
      expect { cache.delete('nonexistent') }.not_to raise_error
    end
  end

  describe '#clear' do
    it 'removes all entries' do
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')
      expect(cache.size).to eq(2)

      cache.clear
      expect(cache.size).to eq(0)
      expect(cache.get('key1')).to be_nil
      expect(cache.get('key2')).to be_nil
    end
  end

  describe '#size' do
    it 'returns correct cache size' do
      expect(cache.size).to eq(0)

      cache.set('key1', 'value1')
      expect(cache.size).to eq(1)

      cache.set('key2', 'value2')
      expect(cache.size).to eq(2)
    end
  end

  describe '#keys' do
    it 'returns all cache keys' do
      cache.set('key1', 'value1')
      cache.set('key2', 'value2')

      keys = cache.keys
      expect(keys).to include('key1', 'key2')
      expect(keys.length).to eq(2)
    end

    it 'returns empty array for empty cache' do
      expect(cache.keys).to eq([])
    end
  end

  describe '#exists?' do
    it 'returns true for existing keys' do
      cache.set('key1', 'value1')
      expect(cache.exists?('key1')).to be true
    end

    it 'returns false for non-existent keys' do
      expect(cache.exists?('nonexistent')).to be false
    end

    it 'returns false for expired keys' do
      cache.set('key1', 'value1', 0.1) # Very short TTL
      expect(cache.exists?('key1')).to be true

      sleep(0.2)
      expect(cache.exists?('key1')).to be false
    end
  end

  describe 'TTL expiration' do
    it 'expires entries after TTL' do
      cache.set('key1', 'value1', 0.1) # 0.1 second TTL
      expect(cache.get('key1')).to eq('value1')

      sleep(0.2)
      expect(cache.get('key1')).to be_nil
    end

    it 'automatically removes expired entries on access' do
      cache.set('key1', 'value1', 0.1)
      cache.set('key2', 'value2', 0.1)

      sleep(0.2)

      # Accessing expired entries should remove them
      cache.get('key1')
      cache.exists?('key2')

      expect(cache.size).to eq(0)
    end
  end

  describe 'max size enforcement' do
    let(:small_cache) { described_class.new(max_size: 3) }

    it 'enforces maximum cache size' do
      small_cache.set('key1', 'value1')
      small_cache.set('key2', 'value2')
      small_cache.set('key3', 'value3')
      small_cache.set('key4', 'value4')

      expect(small_cache.size).to be <= 3
    end

    it 'removes oldest entries when max size exceeded' do
      small_cache.set('key1', 'value1', 10)
      small_cache.set('key2', 'value2', 20)
      small_cache.set('key3', 'value3', 30)

      # Add one more to trigger cleanup
      small_cache.set('key4', 'value4', 40)

      # key1 should be removed as it has the earliest expiration
      expect(small_cache.exists?('key1')).to be false
      expect(small_cache.exists?('key2')).to be true
      expect(small_cache.exists?('key3')).to be true
      expect(small_cache.exists?('key4')).to be true
    end

    it 'removes expired entries before enforcing size limit' do
      small_cache.set('key1', 'value1', 0.1) # Will expire soon
      small_cache.set('key2', 'value2', 10)
      small_cache.set('key3', 'value3', 20)

      sleep(0.2) # Let key1 expire

      # Add one more - the cache will automatically clean up expired entries
      # during set operation, so key1 will be removed
      small_cache.set('key4', 'value4', 30)

      # The cache should have 3 entries after cleanup (key1 was expired and removed)
      expect(small_cache.size).to eq(3)

      # All remaining keys should exist
      expect(small_cache.exists?('key2')).to be true
      expect(small_cache.exists?('key3')).to be true
      expect(small_cache.exists?('key4')).to be true
    end
  end

  describe 'edge cases' do
    it 'handles nil values' do
      cache.set('key1', nil)
      expect(cache.get('key1')).to be_nil
      expect(cache.exists?('key1')).to be true
    end

    it 'handles empty string values' do
      cache.set('key1', '')
      expect(cache.get('key1')).to eq('')
    end

    it 'handles complex object values' do
      complex_value = { nested: { array: [1, 2, 3], string: 'test' } }
      cache.set('key1', complex_value)
      expect(cache.get('key1')).to eq(complex_value)
    end
  end
end
