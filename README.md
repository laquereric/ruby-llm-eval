# ruby-llm-eval

Behavioral evaluation framework for [RubyLLM](https://github.com/crmne/ruby_llm) agents.

Test whether your LLM agents complete tasks correctly, use tools appropriately, and maintain quality across model changes — with multi-trial execution, deterministic and model-based graders, and CI-friendly reporting.

## Installation

```ruby
# Gemfile (test group)
group :test do
  gem "ruby-llm-eval"
end
```

## Quick Start

```ruby
require "ruby_llm/eval"

# Define an eval suite
RubyLLM::Eval.define "weather-agent" do
  scenario "returns temperature for valid city" do
    input "What's the weather in San Francisco?"

    grader :tool_called, tool: "get_weather"
    grader :tool_args, tool: "get_weather", args: { city: "San Francisco" }
    grader :response_includes, pattern: /temperature|degrees|°/

    trials 5
  end

  scenario "handles unknown city gracefully" do
    input "What's the weather in Atlantis?"

    grader :tool_not_called, tool: "get_weather"
    grader :response_includes, pattern: /not found|don't have|unavailable/i
  end
end

# Run against a RubyLLM agent
agent = RubyLLM.agent(model: "claude-sonnet-4-5", tools: [WeatherTool])
results = RubyLLM::Eval.run("weather-agent", agent: agent)

puts results.summary
# => 2 scenarios, 7 trials, pass@1: 80%, pass@5: 100%

# Or with a custom callable
results = RubyLLM::Eval.run("weather-agent") do |input|
  my_custom_agent.call(input)
end
```

## Grader Types

### Code-Based (Deterministic)

| Grader | Description |
|--------|-------------|
| `:response_includes` | Response matches pattern (string or regex) |
| `:response_excludes` | Response does NOT match pattern |
| `:tool_called` | Named tool was invoked |
| `:tool_not_called` | Named tool was NOT invoked |
| `:tool_args` | Tool called with expected arguments |
| `:tool_count` | Number of tool calls matches expected |
| `:turn_count` | Conversation turns within min/max bounds |
| `:custom` | Custom lambda grader |

### Model-Based (LLM-as-Judge)

| Grader | Description |
|--------|-------------|
| `:llm_judge` | LLM evaluates response against a rubric |

## Multi-Trial Metrics

```ruby
scenario "reliable tool usage" do
  input "Calculate 2 + 2"
  grader :tool_called, tool: "calculator"
  trials 10
end

results.pass_at(1)   # => 0.9   (probability of success in 1 attempt)
results.pass_at(5)   # => 1.0   (probability of success in 5 attempts)
results.pass_pow(5)  # => 0.59  (probability ALL 5 attempts succeed)
```

## Baseline Regression Detection

```ruby
# Save a baseline
RubyLLM::Eval::Baseline.save("weather-agent", results)

# Compare against baseline
regressions = RubyLLM::Eval::Baseline.compare("weather-agent", new_results)
regressions.each do |r|
  puts "#{r[:scenario]} regressed: #{r[:previous_status]} -> #{r[:current_status]}"
end
```

## Reports

```ruby
report = RubyLLM::Eval::Report.new(results)
report.to_json       # => Hash
report.to_markdown   # => String
report.to_junit_xml  # => String (for CI integration)
```

## License

MIT
