# frozen_string_literal: true

# Integration tests for the llama-1b-container
# Container: https://github.com/laquereric/llama-1b-container
#
# Start the container before running these tests:
#   podman run --rm -it \
#     --device /dev/dri \
#     -v ~/models:/models \
#     -p 8080:8080 \
#     llama-cpp-vulkan \
#     -m /models/Llama-3.2-1B-Instruct-Q4_K_M.gguf \
#     --host 0.0.0.0 --port 8080 --n-gpu-layers 99
#
# Override host with LLAMA_HOST env var (default: http://localhost:8080)
#
# Run: ruby test/integration/llama_container_test.rb

require_relative "../test_helper"

class LlamaContainerConnectivityTest < Minitest::Test
  include LlamaContainerHelper

  def setup
    skip "llama-1b-container not running at #{LLAMA_HOST}" unless container_available?
    RubyLLM::Eval.reset!
  end

  def test_models_endpoint_lists_available_models
    uri = URI("#{LLAMA_HOST}/v1/models")
    body = JSON.parse(Net::HTTP.get(uri))
    assert body.key?("data"), "Expected 'data' key in /v1/models response"
    assert_kind_of Array, body["data"]
  end

  def test_raw_completion_returns_non_empty_response
    reply = call_llama("Say the word: hello")
    refute_empty reply
  end
end

class LlamaContainerBasicCapabilityTest < Minitest::Test
  include LlamaContainerHelper

  def setup
    skip "llama-1b-container not running at #{LLAMA_HOST}" unless container_available?
    RubyLLM::Eval.reset!
  end

  def test_greeting_scenario_passes
    suite = RubyLLM::Eval::Suite.define("llama-greeting") do
      scenario "responds to hello" do
        input "Say hello back to me in one short sentence."
        grader :response_includes, pattern: /hello/i
      end
    end

    result = llama_runner.run(suite)
    assert result.passed?, failed_message(result, "responds to hello")
  end

  def test_instruction_following_yes_no_answer
    suite = RubyLLM::Eval::Suite.define("llama-instructions") do
      scenario "yes or no answer" do
        input "Answer with only the word YES or NO. Is the sky blue during a clear day?"
        grader :response_includes, pattern: /\byes\b/i
      end
    end

    result = llama_runner.run(suite)
    assert result.passed?, failed_message(result, "yes or no answer")
  end

  def test_basic_arithmetic
    suite = RubyLLM::Eval::Suite.define("llama-arithmetic") do
      scenario "simple addition" do
        input "What is 2 + 2? Reply with only the number."
        grader :response_includes, pattern: "4"
      end
    end

    result = llama_runner.run(suite)
    assert result.passed?, failed_message(result, "simple addition")
  end

  def test_response_excludes_opposite_answer
    suite = RubyLLM::Eval::Suite.define("llama-excludes") do
      scenario "does not say goodbye when greeted" do
        input "Say hello back to me."
        grader :response_excludes, pattern: /\bgoodbye\b/i
      end
    end

    result = llama_runner.run(suite)
    assert result.passed?, failed_message(result, "does not say goodbye when greeted")
  end

  def test_turn_count_is_one
    suite = RubyLLM::Eval::Suite.define("llama-turns") do
      scenario "single turn response" do
        input "What color is grass?"
        grader :turn_count, expected: 1
      end
    end

    result = llama_runner.run(suite)
    assert result.passed?, failed_message(result, "single turn response")
  end

  private

  def failed_message(result, scenario_name)
    eval_result = result[scenario_name]
    return "Scenario '#{scenario_name}' not found" unless eval_result

    trial = eval_result.trial_results.first
    grader_msgs = trial.grader_results.map { |gr| "  #{gr.name}: #{gr.message}" }.join("\n")
    "Scenario '#{scenario_name}' failed:\n#{grader_msgs}"
  end
end

class LlamaContainerMultiTrialTest < Minitest::Test
  include LlamaContainerHelper

  def setup
    skip "llama-1b-container not running at #{LLAMA_HOST}" unless container_available?
    RubyLLM::Eval.reset!
  end

  # Runs 3 trials to check consistency. With temperature: 0, a 1B model
  # should answer a simple factual question correctly every time.
  def test_consistent_factual_answer_across_trials
    suite = RubyLLM::Eval::Suite.define("llama-consistency") do
      scenario "capital of France" do
        input "What is the capital of France? Reply with just the city name."
        grader :response_includes, pattern: /paris/i
        trials 3
      end
    end

    result = llama_runner.run(suite)
    eval_result = result["capital of France"]

    assert_equal 3, eval_result.trial_count
    assert eval_result.pass_count >= 2,
      "Expected at least 2/3 trials to pass, got #{eval_result.pass_count}/3"
  end
end

class LlamaContainerReportTest < Minitest::Test
  include LlamaContainerHelper

  def setup
    skip "llama-1b-container not running at #{LLAMA_HOST}" unless container_available?
    RubyLLM::Eval.reset!
  end

  def test_run_result_produces_valid_json_report
    suite = RubyLLM::Eval::Suite.define("llama-report") do
      scenario "json check" do
        input "Say ok."
        grader :response_includes, pattern: /ok/i
      end
    end

    result = llama_runner.run(suite)
    report = RubyLLM::Eval::Report.new(result)
    data = report.to_json

    assert_kind_of Hash, data
    assert data.key?(:suite_name)
    assert data.key?(:results)
    assert_kind_of Array, data[:results]
    assert_equal 1, data[:results].size
  end

  def test_run_result_produces_markdown_report
    suite = RubyLLM::Eval::Suite.define("llama-markdown") do
      scenario "markdown check" do
        input "Say ok."
        grader :response_includes, pattern: /ok/i
      end
    end

    result = llama_runner.run(suite)
    report = RubyLLM::Eval::Report.new(result)
    markdown = report.to_markdown

    assert_includes markdown, "markdown check"
    assert_includes markdown, "llama-markdown"
  end
end
