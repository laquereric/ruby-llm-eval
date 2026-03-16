# frozen_string_literal: true

module RubyLLM
  module Eval
    class Runner
      def initialize(agent: nil, &block)
        @agent = agent
        @block = block
        @code_based = Grader::CodeBased.new
        @model_based = Grader::ModelBased.new
      end

      def run(suite)
        results = suite.scenarios.map { |scenario| run_scenario(scenario, suite.name) }
        RunResult.new(suite_name: suite.name, eval_results: results)
      end

      private

      def run_scenario(scenario, suite_name)
        scenario.setup_block&.call

        trial_results = (1..scenario.trial_count).map do |trial_num|
          run_trial(scenario, trial_num)
        end

        EvalResult.new(
          scenario_name: scenario.name,
          suite_name: suite_name,
          trial_results: trial_results
        )
      end

      def run_trial(scenario, trial_num)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)
        transcript = execute_agent(scenario.input)
        grader_results = evaluate_graders(scenario.graders, transcript)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_time

        status = grader_results.all?(&:passed?) ? :pass : :fail

        TrialResult.new(
          trial_number: trial_num,
          status: status,
          grader_results: grader_results,
          transcript: transcript,
          duration_ms: duration
        )
      rescue => e
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_time
        TrialResult.new(
          trial_number: trial_num,
          status: :error,
          grader_results: [],
          duration_ms: duration,
          error_message: "#{e.class}: #{e.message}"
        )
      end

      def execute_agent(input)
        transcript = Transcript.new
        transcript.add(role: :user, content: input)

        if @agent
          response = execute_ruby_llm_agent(input, transcript)
          transcript.add(
            role: :assistant,
            content: response_content(response),
            tool_calls: extract_tool_calls(response),
            tokens: extract_tokens(response)
          )
        elsif @block
          result = @block.call(input)
          apply_block_result(transcript, result)
        else
          raise Error, "No agent or block provided to runner"
        end

        transcript
      end

      def execute_ruby_llm_agent(input, transcript)
        if @agent.respond_to?(:ask)
          @agent.ask(input)
        elsif @agent.respond_to?(:call)
          @agent.call(input)
        else
          raise Error, "Agent must respond to #ask or #call"
        end
      end

      def apply_block_result(transcript, result)
        case result
        when Hash
          transcript.add(
            role: :assistant,
            content: result[:content] || result["content"],
            tool_calls: result[:tool_calls] || result["tool_calls"],
            tokens: result[:tokens] || result["tokens"]
          )
        when String
          transcript.add(role: :assistant, content: result)
        else
          transcript.add(role: :assistant, content: result.to_s)
        end
      end

      def evaluate_graders(grader_configs, transcript)
        grader_configs.map do |config|
          grader = grader_for(config[:type])
          grader.evaluate(config, transcript)
        end
      end

      def grader_for(type)
        case type
        when :llm_judge then @model_based
        else @code_based
        end
      end

      def response_content(response)
        if response.respond_to?(:content)
          response.content
        elsif response.respond_to?(:to_s)
          response.to_s
        end
      end

      def extract_tool_calls(response)
        if response.respond_to?(:tool_calls)
          response.tool_calls&.map do |tc|
            { name: tc.name, arguments: tc.arguments }
          end
        end
      rescue
        nil
      end

      def extract_tokens(response)
        if response.respond_to?(:input_tokens) && response.respond_to?(:output_tokens)
          { input: response.input_tokens, output: response.output_tokens }
        end
      rescue
        nil
      end
    end

    class RunResult
      attr_reader :suite_name, :eval_results

      def initialize(suite_name:, eval_results:)
        @suite_name = suite_name
        @eval_results = eval_results
        freeze
      end

      def passed?
        @eval_results.all?(&:passed?)
      end

      def scenario_count
        @eval_results.size
      end

      def trial_count
        @eval_results.sum(&:trial_count)
      end

      def pass_rate
        return 0.0 if scenario_count.zero?

        @eval_results.count(&:passed?).to_f / scenario_count
      end

      def summary
        passed = @eval_results.count(&:passed?)
        total_trials = trial_count
        "#{scenario_count} scenarios, #{total_trials} trials, " \
          "#{passed}/#{scenario_count} passed (#{(pass_rate * 100).round(1)}%)"
      end

      def [](scenario_name)
        @eval_results.find { |r| r.scenario_name == scenario_name }
      end

      def to_h
        {
          suite_name: @suite_name,
          scenario_count: scenario_count,
          trial_count: trial_count,
          pass_rate: pass_rate.round(4),
          results: @eval_results.map(&:to_h)
        }
      end
    end
  end
end
