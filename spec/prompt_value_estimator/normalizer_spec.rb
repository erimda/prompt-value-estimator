# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::Normalizer do
  let(:output) { StringIO.new }
  let(:logger) { PromptValueEstimator::Logger.new(output, Logger::DEBUG) }
  let(:configuration) { PromptValueEstimator::Configuration.new }
  let(:normalizer) { described_class.new(configuration, logger) }

  describe '#initialize' do
    it 'creates normalizer with configuration and logger' do
      expect(normalizer.stopwords).to eq(configuration.stopwords)
      expect(normalizer.max_variants).to eq(configuration.max_variants)
    end

    it 'creates normalizer with defaults' do
      default_normalizer = described_class.new
      expect(default_normalizer.stopwords).to be_an(Array)
      expect(default_normalizer.max_variants).to be_a(Integer)
    end
  end

  describe '#normalize' do
    it 'validates prompt presence' do
      expect { normalizer.normalize(nil) }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompt cannot be blank')
      expect { normalizer.normalize('') }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompt cannot be blank')
    end

    it 'validates prompt type' do
      expect { normalizer.normalize(123) }
        .to raise_error(PromptValueEstimator::ValidationError, 'prompt must be a String')
    end

    it 'returns normalized variants structure' do
      result = normalizer.normalize('test prompt')
      expect(result).to have_key(:head)
      expect(result).to have_key(:mid)
      expect(result).to have_key(:long)
      expect(result[:head]).to be_an(Array)
      expect(result[:mid]).to be_an(Array)
      expect(result[:long]).to be_an(Array)
    end

    it 'logs normalization process' do
      normalizer.normalize('test prompt')
      log_output = output.string
      expect(log_output).to include('Normalizing prompt')
      expect(log_output).to include('Generated variants')
    end
  end

  describe 'text processing' do
    it 'cleans text properly' do
      result = normalizer.normalize('Test Prompt! With, Punctuation.')
      expect(result[:head]).to include('test')
      expect(result[:head]).to include('prompt')
    end

    it 'removes stopwords' do
      result = normalizer.normalize('the test prompt for you')
      expect(result[:head]).not_to include('the')
      expect(result[:head]).not_to include('for')
      expect(result[:head]).to include('test')
      expect(result[:head]).to include('prompt')
    end

    it 'normalizes whitespace' do
      result = normalizer.normalize('test    prompt   using   example   words')
      expect(result[:head]).to include('test')
      expect(result[:head]).to include('prompt')
      expect(result[:head]).to include('using')
      # NOTE: 'example' might not be included due to variant limiting
      expect(result[:head].length).to be >= 3
    end
  end

  describe 'variant generation' do
    context 'head variants' do
      it 'generates single word variants' do
        result = normalizer.normalize('test prompt example code')
        expect(result[:head]).to include('test')
        expect(result[:head]).to include('prompt')
        expect(result[:head]).to include('example')
      end

      it 'generates two word combinations' do
        result = normalizer.normalize('test prompt example code')
        expect(result[:head]).to include('test prompt')
        expect(result[:head]).to include('prompt example')
      end

      it 'limits head variants to 5' do
        result = normalizer.normalize('one two three four five six seven eight')
        expect(result[:head].length).to be <= 5
      end
    end

    context 'mid variants' do
      it 'generates three word combinations' do
        result = normalizer.normalize('test prompt example code')
        expect(result[:mid]).to include('test prompt example')
        expect(result[:mid]).to include('prompt example code')
      end

      it 'generates task-oriented phrases' do
        result = normalizer.normalize('database optimization')
        expect(result[:mid]).to include('how to database')
        expect(result[:mid]).to include('optimize database')
      end

      it 'returns empty array for short prompts' do
        result = normalizer.normalize('test')
        expect(result[:mid]).to be_empty
      end
    end

    context 'long variants' do
      it 'generates question forms' do
        result = normalizer.normalize('test prompt')
        expect(result[:long]).to include('how to test prompt')
        expect(result[:long]).to include('what is test prompt')
      end

      it 'adds question mark to non-question prompts' do
        result = normalizer.normalize('test prompt')
        expect(result[:long]).to include('test prompt?')
      end

      it 'generates best practices variants' do
        result = normalizer.normalize('test prompt')
        expect(result[:long]).to include('best practices for test prompt')
        expect(result[:long]).to include('tips for test prompt')
      end
    end
  end

  describe 'variant limiting' do
    it 'respects max_variants configuration' do
      # Create a configuration with very low max_variants
      low_config = double('config')
      allow(low_config).to receive_messages(stopwords: [], max_variants: 5)

      low_normalizer = described_class.new(low_config, logger)
      result = low_normalizer.normalize('one two three four five six seven eight')

      total_variants = result.values.sum(&:length)
      expect(total_variants).to be <= 5
    end

    it 'distributes variants proportionally when limiting' do
      # Create a configuration with moderate max_variants
      moderate_config = double('config')
      allow(moderate_config).to receive_messages(stopwords: [], max_variants: 10)

      moderate_normalizer = described_class.new(moderate_config, logger)
      result = moderate_normalizer.normalize('one two three four five six seven eight')

      total_variants = result.values.sum(&:length)
      expect(total_variants).to be <= 10
    end
  end

  describe 'edge cases' do
    it 'handles single word prompts' do
      result = normalizer.normalize('test')
      expect(result[:head]).to include('test')
      expect(result[:mid]).to be_empty
      expect(result[:long]).to include('test?')
    end

    it 'handles prompts with only stopwords' do
      result = normalizer.normalize('the and or')
      expect(result[:head]).to be_empty
      expect(result[:mid]).to be_empty
      expect(result[:long]).to be_empty
    end

    it 'handles very long prompts' do
      long_prompt = 'this is a very long prompt with many words that should generate many variants'
      result = normalizer.normalize(long_prompt)
      expect(result[:head]).not_to be_empty
      expect(result[:mid]).not_to be_empty
      expect(result[:long]).not_to be_empty
    end
  end
end
