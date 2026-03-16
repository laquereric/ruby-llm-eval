# frozen_string_literal: true

require "json"

module RubyLLM
  module Eval
    class Report
      def initialize(run_result, regressions: [])
        @run_result = run_result
        @regressions = regressions
      end

      def to_json
        {
          generated_at: Time.now.iso8601,
          suite_name: @run_result.suite_name,
          summary: summary,
          results: @run_result.eval_results.map(&:to_h),
          regressions: @regressions
        }
      end

      def to_markdown
        lines = []
        lines << "# Eval Report: #{@run_result.suite_name}"
        lines << ""
        lines << "Generated: #{Time.now.iso8601}"
        lines << ""
        lines << "## Summary"
        lines << ""
        lines << "| Metric | Value |"
        lines << "|--------|-------|"
        s = summary
        lines << "| Scenarios | #{s[:total]} |"
        lines << "| Passed | #{s[:pass]} |"
        lines << "| Failed | #{s[:fail]} |"
        lines << "| Errors | #{s[:error]} |"
        lines << "| Pass Rate | #{(s[:pass_rate] * 100).round(1)}% |"
        lines << "| Total Trials | #{s[:total_trials]} |"
        lines << ""

        failures = @run_result.eval_results.select(&:failed?)
        if failures.any?
          lines << "## Failures"
          lines << ""
          failures.each do |result|
            lines << "### #{result.scenario_name}"
            lines << ""
            result.trial_results.select(&:failed?).each do |trial|
              lines << "**Trial #{trial.trial_number}:**"
              trial.grader_results.select(&:failed?).each do |gr|
                lines << "- #{gr.name}: expected #{gr.expected}, got #{gr.actual}"
              end
              lines << ""
            end
          end
        end

        if @regressions.any?
          lines << "## Regressions"
          lines << ""
          lines << "| Scenario | Previous | Current |"
          lines << "|----------|----------|---------|"
          @regressions.each do |r|
            lines << "| #{r[:scenario_name]} | #{r[:previous_status]} | #{r[:current_status]} |"
          end
          lines << ""
        end

        lines.join("\n")
      end

      def to_junit_xml
        lines = []
        lines << '<?xml version="1.0" encoding="UTF-8"?>'
        total = @run_result.scenario_count
        failures = @run_result.eval_results.count(&:failed?)
        errors = @run_result.eval_results.count { |r| r.trial_results.any?(&:error?) }
        lines << %(<testsuite name="#{xml_escape(@run_result.suite_name)}" tests="#{total}" failures="#{failures}" errors="#{errors}">)

        @run_result.eval_results.each do |result|
          avg_time = result.avg_duration_ms / 1000.0
          lines << %(  <testcase name="#{xml_escape(result.scenario_name)}" classname="#{xml_escape(@run_result.suite_name)}" time="#{avg_time.round(3)}">)

          if result.failed?
            failing = result.trial_results.select(&:failed?).flat_map(&:grader_results).select(&:failed?)
            msg = failing.map { |gr| "#{gr.name}: expected #{gr.expected}, got #{gr.actual}" }.join("; ")
            lines << %(    <failure message="#{xml_escape(msg)}"/>)
          end

          result.trial_results.select(&:error?).each do |trial|
            lines << %(    <error message="#{xml_escape(trial.error_message || "unknown error")}"/>)
          end

          lines << "  </testcase>"
        end

        lines << "</testsuite>"
        lines.join("\n")
      end

      private

      def summary
        results = @run_result.eval_results
        pass = results.count(&:passed?)
        fail_count = results.count { |r| r.status == :fail }
        error = results.count { |r| r.status == :error }
        total = results.size
        {
          total: total,
          pass: pass,
          fail: fail_count,
          error: error,
          pass_rate: total.zero? ? 0.0 : pass.to_f / total,
          total_trials: @run_result.trial_count
        }
      end

      def xml_escape(str)
        str.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&apos;")
      end
    end
  end
end
