# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PromptValueEstimator::Estimator do
  let(:estimator) { described_class.new }

  describe '#initialize' do
    it 'creates a new estimator instance' do
      expect(estimator).to be_a(described_class)
    end
  end

  describe '#estimate' do
    it 'raises NotImplementedError for now' do
      expect { estimator.estimate('test prompt') }.to raise_error(NotImplementedError)
    end
  end
end
