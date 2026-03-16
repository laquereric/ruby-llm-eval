# frozen_string_literal: true

module RubyLLM
  module Eval
    class EvalResult
      attr_reader :scenario_name, :suite_name, :trial_results

      def initialize(scenario_name:, suite_name:, trial_results:)
        @scenario_name = scenario_name
        @suite_name = suite_name
        @trial_results = trial_results
        freeze
      end

      def status
        return :error if @trial_results.any?(&:error?)
        return :pass if @trial_results.all?(&:passed?)

        :fail
      end

      def passed?
        status == :pass
      end

      def failed?
        !passed?
      end

      def pass_count
        @trial_results.count(&:passed?)
      end

      def fail_count
        @trial_results.count(&:failed?)
      end

      def error_count
        @trial_results.count(&:error?)
      end

      def trial_count
        @trial_results.size
      end

      def pass_rate
        return 0.0 if trial_count.zero?

        pass_count.to_f / trial_count
      end

      def pass_at(k)
        Metrics.pass_at_k(pass_count, fail_count + error_count, k)
      end

      def pass_pow(k)
        Metrics.pass_pow_k(pass_rate, k)
      end

      def avg_duration_ms
        return 0 if trial_count.zero?

        @trial_results.sum(&:duration_ms).to_f / trial_count
      end

      def to_h
        {
          scenario_name: @scenario_name,
          suite_name: @suite_name,
          status: status,
          trial_count: trial_count,
          pass_count: pass_count,
          fail_count: fail_count,
          error_count: error_count,
          pass_rate: pass_rate.round(4),
          avg_duration_ms: avg_duration_ms.round(1),
          trials: @trial_results.map(&:to_h)
        }
      end
    end
  end
end
