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

## Configuration

### Environment Variables

The gem uses environment variables for sensitive configuration:

```bash
# Required: Serpstat API key
export SERPSTAT_API_KEY="your_api_key_here"

# Optional: DataForSEO credentials (if enabled)
export DATAFORSEO_LOGIN="your_login"
export DATAFORSEO_PASSWORD="your_password"
```

### Configuration File

The `config/config.yml` file contains all non-sensitive settings:

```yaml
providers:
  serpstat:
    api_key: ${SERPSTAT_API_KEY}  # Environment variable
    default_region: us
    enabled: true
  dataforseo:
    enabled: false
    login: ${DATAFORSEO_LOGIN}
    password: ${DATAFORSEO_PASSWORD}

normalize:
  max_variants: 15
  include_question_forms: true
  stopwords:
    - the
    - a
    - an
    - and
    - or
    - but

estimate:
  weights:
    head: 0.5      # Short, high-volume keywords
    mid: 0.35      # Medium-length keywords
    long: 0.15     # Long-tail keywords
  locale_bias:
    us: 1.0        # US market (baseline)
    tr: 0.9        # Turkish market
    de: 0.95       # German market

cache:
  ttl_seconds: 86400  # 24 hours
  enabled: true

output:
  topN: 10
  include_breakdown: true
  include_assumptions: true
```

### Custom Configuration

You can use a custom configuration file:

```ruby
config = PromptValueEstimator::Configuration.new('/path/to/custom/config.yml')
estimator = PromptValueEstimator::Estimator.new(config)
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

### Basic Usage

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

### Advanced Usage

```ruby
# Initialize with custom configuration
config = PromptValueEstimator::Configuration.new('/path/to/custom/config.yml')
estimator = PromptValueEstimator::Estimator.new(config)

# Batch estimation
prompts = ["how to make pasta", "best pasta recipes", "pasta cooking tips"]
results = estimator.estimate_batch(prompts, "us")

# Access detailed results
results.each do |result|
  puts "Prompt: #{result[:prompt]}"
  puts "Total Volume: #{result[:estimates][:total]}"
  puts "Confidence: #{result[:confidence]}"
  puts "Variants: #{result[:variants].values.sum(&:length)}"
  puts "---"
end
```

### Cache Management

```ruby
# The estimator automatically caches results
# First call hits the API
result1 = estimator.estimate_volume("test prompt")

# Subsequent calls use cache
result2 = estimator.estimate_volume("test prompt") # Uses cache

# Access cache directly
cache = estimator.cache
puts "Cache size: #{cache.size}"
puts "Cache keys: #{cache.keys.first(5)}"

# Clear cache if needed
cache.clear
```

### Error Handling

```ruby
begin
  result = estimator.estimate_volume("test prompt")
rescue PromptValueEstimator::ValidationError => e
  puts "Validation error: #{e.message}"
rescue PromptValueEstimator::ProviderError => e
  puts "Provider error: #{e.message}"
rescue PromptValueEstimator::ConfigurationError => e
  puts "Configuration error: #{e.message}"
end
```

### Configuration

```ruby
# Access configuration settings
config = estimator.configuration

# Check provider status
if config.provider_enabled?('serpstat')
  puts "Serpstat is enabled"
end

# Get weights for different variant types
head_weight = config.weight_for_type('head')      # 0.5
mid_weight = config.weight_for_type('mid')       # 0.35
long_weight = config.weight_for_type('long')     # 0.15

# Get locale bias
us_bias = config.locale_bias('us')               # 1.0
tr_bias = config.locale_bias('tr')               # 0.9
de_bias = config.locale_bias('de')               # 0.95
```

## Troubleshooting

### Common Issues

**Configuration file not found**
```bash
Error: Configuration file not found: /path/to/config.yml
```
**Solution**: Ensure the configuration file exists and the path is correct.

**Invalid API key**
```bash
Error: Invalid Serpstat API key
```
**Solution**: Check that `SERPSTAT_API_KEY` environment variable is set correctly.

**Rate limit exceeded**
```bash
Error: Serpstat API rate limit exceeded
```
**Solution**: Wait before making more requests or upgrade your Serpstat plan.

**Cache issues**
```bash
# If you need to clear the cache
estimator.cache.clear
```

### Debug Mode

Enable debug logging by setting the log level:

```ruby
require 'logger'
logger = Logger.new(STDOUT)
logger.level = Logger::DEBUG

estimator = PromptValueEstimator::Estimator.new(nil, logger)
```

### Performance Tips

1. **Use caching**: Results are automatically cached for 24 hours by default
2. **Batch processing**: Use `estimate_batch` for multiple prompts
3. **Region selection**: Choose appropriate regions for your target market
4. **Variant limits**: Adjust `max_variants` in config for faster processing

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
