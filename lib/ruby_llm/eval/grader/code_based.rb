# frozen_string_literal: true

module RubyLLM
  module Eval
    module Grader
      class CodeBased < Base
        EVALUATORS = {
          response_includes: ->(config, transcript) {
            pattern = config[:pattern]
            text = transcript.response_text
            matched = pattern.is_a?(Regexp) ? text.match?(pattern) : text.include?(pattern.to_s)
            GraderResult.new(
              name: :response_includes,
              passed: matched,
              expected: pattern.inspect,
              actual: matched ? "(matched)" : text[0..200]
            )
          },

          response_excludes: ->(config, transcript) {
            pattern = config[:pattern]
            text = transcript.response_text
            matched = pattern.is_a?(Regexp) ? text.match?(pattern) : text.include?(pattern.to_s)
            GraderResult.new(
              name: :response_excludes,
              passed: !matched,
              expected: "not #{pattern.inspect}",
              actual: matched ? text[0..200] : "(not matched)"
            )
          },

          tool_called: ->(config, transcript) {
            tool = config[:tool].to_s
            called = transcript.tool_names.include?(tool)
            GraderResult.new(
              name: :tool_called,
              passed: called,
              expected: tool,
              actual: transcript.tool_names.join(", ")
            )
          },

          tool_not_called: ->(config, transcript) {
            tool = config[:tool].to_s
            called = transcript.tool_names.include?(tool)
            GraderResult.new(
              name: :tool_not_called,
              passed: !called,
              expected: "not #{tool}",
              actual: transcript.tool_names.join(", ")
            )
          },

          tool_args: ->(config, transcript) {
            tool = config[:tool].to_s
            expected_args = config[:args] || {}
            calls = transcript.tool_calls.select { |tc| (tc[:name] || tc["name"]).to_s == tool }
            matched = calls.any? do |tc|
              actual_args = tc[:arguments] || tc["arguments"] || tc[:args] || tc["args"] || {}
              expected_args.all? { |k, v| actual_args[k.to_s] == v || actual_args[k.to_sym] == v }
            end
            GraderResult.new(
              name: :tool_args,
              passed: matched,
              expected: "#{tool}(#{expected_args})",
              actual: calls.map { |tc| tc[:arguments] || tc["arguments"] || tc[:args] || tc["args"] }.inspect
            )
          },

          tool_count: ->(config, transcript) {
            expected = config[:expected]
            actual = transcript.tool_calls.size
            GraderResult.new(
              name: :tool_count,
              passed: actual == expected,
              expected: expected,
              actual: actual
            )
          },

          turn_count: ->(config, transcript) {
            actual = transcript.turn_count
            min = config[:min] || 0
            max = config[:max] || Float::INFINITY
            in_range = actual >= min && actual <= max
            GraderResult.new(
              name: :turn_count,
              passed: in_range,
              expected: "#{min}..#{max == Float::INFINITY ? "∞" : max}",
              actual: actual
            )
          },

          custom: ->(config, transcript) {
            check = config[:check]
            raise Error, "Custom grader requires :check lambda" unless check.respond_to?(:call)

            result = check.call(transcript)
            if result.is_a?(GraderResult)
              result
            else
              GraderResult.new(name: :custom, passed: !!result)
            end
          }
        }.freeze

        def evaluate(grader_config, transcript)
          type = grader_config[:type]
          evaluator = EVALUATORS[type]
          raise Error, "Unknown code-based grader: #{type}" unless evaluator

          evaluator.call(grader_config, transcript)
        end
      end
    end
  end
end
