# frozen_string_literal: true

require_relative "lib/prompt_value_estimator/version"

Gem::Specification.new do |spec|
  spec.name = "prompt_value_estimator"
  spec.version = PromptValueEstimator::VERSION
  spec.authors = ["erimda"]
  spec.email = ["erenimdat@gmail.com"]

  spec.summary = "A Ruby gem for estimating prompt values"
  spec.description = "This gem provides functionality to estimate the value of prompts"
  spec.homepage = "https://github.com/erimda/prompt-value-estimator"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage

  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md LICENSE.txt]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "pry-byebug", "~> 3.10"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
