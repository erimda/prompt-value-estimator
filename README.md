# Prompt Value Estimator

A Ruby project for estimating prompt values.

## Requirements

- Ruby 3.3.6+
- Serpstat API key

## Installation

1. Clone the repository:
```bash
git clone https://github.com/erimda/prompt-value-estimator.git
cd prompt-value-estimator
```

2. Install dependencies:
```bash
bundle install
```

3. Configure your API key:
```bash
export SERPSTAT_API_KEY="your_api_key_here"
```

## CLI Usage

The gem provides a command-line interface for easy usage:

```bash
# Basic volume estimation
ruby bin/prompt-value-estimator estimate "how to make pasta"

# With region specification
ruby bin/prompt-value-estimator estimate "how to make pasta" -r us

# JSON output format
ruby bin/prompt-value-estimator estimate "how to make pasta" -o json

# Get related keywords
ruby bin/prompt-value-estimator related "how to make pasta"

# Get keyword suggestions
ruby bin/prompt-value-estimator suggestions "how to make pasta"

# Show help
ruby bin/prompt-value-estimator --help

# Show version
ruby bin/prompt-value-estimator --version
```

### Available Commands

- `estimate` - Estimate search volume for a prompt
- `related` - Get related keywords for a prompt
- `suggestions` - Get keyword suggestions for a prompt

### Options

- `-p, --prompt PROMPT` - Specify the prompt to analyze
- `-r, --region REGION` - Specify the region (default: us)
- `-o, --output FORMAT` - Output format: json or text (default: text)
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Ruby API Usage

```ruby
require 'prompt_value_estimator'

# Initialize with configuration
estimator = PromptValueEstimator::Estimator.new

# Estimate volume for a prompt
result = estimator.estimate_volume("how to make pasta", "us")
puts "Total estimate: #{result[:estimates][:total]}"
puts "Confidence: #{result[:confidence]}"

# Get related prompts
related = estimator.get_related_prompts("how to make pasta", "us")
puts "Related keywords: #{related[:related_keywords].length}"

# Get suggestions
suggestions = estimator.get_keyword_suggestions("how to make pasta", "us")
puts "Suggestions: #{suggestions[:suggestions].length}"
```

## Development

Run tests:
```bash
bundle exec rspec
```

Run with Rake:
```bash
bundle exec rake
```

## License

[License information to be added]
