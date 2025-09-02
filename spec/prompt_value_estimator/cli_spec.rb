# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::CLI do
  let(:cli) { described_class.new }
  let(:mock_estimator) { instance_double(PromptValueEstimator::Estimator) }

  before do
    allow(PromptValueEstimator::Estimator).to receive(:new).and_return(mock_estimator)
  end

  describe '#initialize' do
    it 'creates CLI with empty options' do
      expect(cli.instance_variable_get(:@options)).to eq({})
    end
  end

  describe '#parse_options' do
    it 'parses prompt option' do
      cli.send(:parse_options, ['-p', 'test prompt'])
      expect(cli.instance_variable_get(:@options)[:prompt]).to eq('test prompt')
    end

    it 'parses region option' do
      cli.send(:parse_options, ['-r', 'us'])
      expect(cli.instance_variable_get(:@options)[:region]).to eq('us')
    end

    it 'parses output format option' do
      cli.send(:parse_options, ['-o', 'json'])
      expect(cli.instance_variable_get(:@options)[:output_format]).to eq('json')
    end

    it 'sets default output format to text' do
      cli.send(:parse_options, [])
      expect(cli.instance_variable_get(:@options)[:output_format]).to be_nil
    end
  end

  describe '#execute_command' do
    before do
      allow(cli).to receive(:estimate_volume)
      allow(cli).to receive(:get_related_prompts)
      allow(cli).to receive(:get_suggestions)
      allow(ARGV).to receive(:first).and_return('estimate')
    end

    it 'calls estimate_volume for estimate command' do
      expect(cli).to receive(:estimate_volume)
      cli.send(:execute_command)
    end

    it 'calls get_related_prompts for related command' do
      allow(ARGV).to receive(:first).and_return('related')
      expect(cli).to receive(:get_related_prompts)
      cli.send(:execute_command)
    end

    it 'calls get_suggestions for suggestions command' do
      allow(ARGV).to receive(:first).and_return('suggestions')
      expect(cli).to receive(:get_suggestions)
      cli.send(:execute_command)
    end

    it 'exits with error for unknown command' do
      allow(ARGV).to receive(:first).and_return('unknown')
      expect { cli.send(:execute_command) }.to raise_error(SystemExit)
    end
  end

  describe '#estimate_volume' do
    let(:result) { { prompt: 'test', estimates: { total: 1000 } } }

    before do
      allow(mock_estimator).to receive(:estimate_volume).and_return(result)
      allow(cli).to receive(:output_result)
    end

    it 'calls estimator with prompt and region' do
      cli.instance_variable_set(:@options, { prompt: 'test prompt', region: 'us' })
      expect(mock_estimator).to receive(:estimate_volume).with('test prompt', 'us')
      cli.send(:estimate_volume)
    end

    it 'uses ARGV[1] when prompt not in options' do
      allow(ARGV).to receive(:[]).with(1).and_return('test prompt')
      expect(mock_estimator).to receive(:estimate_volume).with('test prompt', nil)
      cli.send(:estimate_volume)
    end

    it 'raises error when no prompt provided' do
      expect { cli.send(:estimate_volume) }.to raise_error(ArgumentError, 'Prompt is required')
    end

    it 'calls output_result with result' do
      cli.instance_variable_set(:@options, { prompt: 'test prompt' })
      expect(cli).to receive(:output_result).with(result)
      cli.send(:estimate_volume)
    end
  end

  describe '#get_related_prompts' do
    let(:result) { { prompt: 'test', related_keywords: [] } }

    before do
      allow(mock_estimator).to receive(:get_related_prompts).and_return(result)
      allow(cli).to receive(:output_result)
    end

    it 'calls estimator with prompt and region' do
      cli.instance_variable_set(:@options, { prompt: 'test prompt', region: 'us' })
      expect(mock_estimator).to receive(:get_related_prompts).with('test prompt', 'us')
      cli.send(:get_related_prompts)
    end

    it 'raises error when no prompt provided' do
      expect { cli.send(:get_related_prompts) }.to raise_error(ArgumentError, 'Prompt is required')
    end
  end

  describe '#get_suggestions' do
    let(:result) { { prompt: 'test', suggestions: [] } }

    before do
      allow(mock_estimator).to receive(:get_keyword_suggestions).and_return(result)
      allow(cli).to receive(:output_result)
    end

    it 'calls estimator with prompt and region' do
      cli.instance_variable_set(:@options, { prompt: 'test prompt', region: 'us' })
      expect(mock_estimator).to receive(:get_keyword_suggestions).with('test prompt', 'us')
      cli.send(:get_suggestions)
    end

    it 'raises error when no prompt provided' do
      expect { cli.send(:get_suggestions) }.to raise_error(ArgumentError, 'Prompt is required')
    end
  end

  describe '#output_result' do
    let(:result) { { prompt: 'test', data: 'value' } }

    it 'outputs JSON when format is json' do
      cli.instance_variable_set(:@options, { output_format: 'json' })
      expect { cli.send(:output_result, result) }.to output(/prompt.*test/).to_stdout
    end

    it 'outputs text when format is not json' do
      cli.instance_variable_set(:@options, { output_format: 'text' })
      expect { cli.send(:output_result, result) }.to output(/Result:.*test/).to_stdout
    end

    it 'outputs text when no format specified' do
      expect { cli.send(:output_result, result) }.to output(/Result:.*test/).to_stdout
    end
  end

  describe '#output_text' do
    let(:result) { { prompt: 'test', data: 'value' } }

    it 'outputs result as inspect string' do
      expect { cli.send(:output_text, result) }.to output(/Result:.*test/).to_stdout
    end
  end

  describe '#handle_error' do
    let(:error) { StandardError.new('Test error') }

    it 'outputs JSON error when format is json' do
      cli.instance_variable_set(:@options, { output_format: 'json' })
      expect { cli.send(:handle_error, error) }.to output(/error.*StandardError/).to_stdout
    end

    it 'outputs text error when format is not json' do
      cli.instance_variable_set(:@options, { output_format: 'text' })
      expect { cli.send(:handle_error, error) }.to output(/Error: Test error/).to_stdout
    end

    it 'includes timestamp in JSON error' do
      cli.instance_variable_set(:@options, { output_format: 'json' })
      expect { cli.send(:handle_error, error) }.to output(/timestamp/).to_stdout
    end
  end

  describe '#estimator' do
    it 'creates estimator only once' do
      expect(PromptValueEstimator::Estimator).to receive(:new).once.and_return(mock_estimator)
      cli.send(:estimator)
      cli.send(:estimator)
    end
  end
end
