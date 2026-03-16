# frozen_string_literal: true

require_relative "eval/version"
require_relative "eval/grader_result"
require_relative "eval/grader/registry"
require_relative "eval/grader/base"
require_relative "eval/grader/code_based"
require_relative "eval/grader/model_based"
require_relative "eval/transcript"
require_relative "eval/trial_result"
require_relative "eval/eval_result"
require_relative "eval/scenario"
require_relative "eval/scenario_builder"
require_relative "eval/suite"
require_relative "eval/runner"
require_relative "eval/metrics"
require_relative "eval/baseline"
require_relative "eval/report"

module RubyLLM
  module Eval
    class Error < StandardError; end

    class << self
      def define(name, &block)
        Suite.define(name, &block)
      end

      def run(suite_name, agent: nil, &block)
        suite = Suite.fetch(suite_name)
        runner = Runner.new(agent: agent, &block)
        runner.run(suite)
      end

      def reset!
        Suite.reset!
        Grader::Registry.reset!
      end
    end
  end
end
