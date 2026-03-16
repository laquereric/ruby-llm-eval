# frozen_string_literal: true

module RubyLLM
  module Eval
    class GraderResult
      attr_reader :name, :passed, :expected, :actual, :message

      def initialize(name:, passed:, expected: nil, actual: nil, message: nil)
        @name = name.to_sym
        @passed = !!passed
        @expected = expected
        @actual = actual
        @message = message
        freeze
      end

      def passed?
        @passed
      end

      def failed?
        !@passed
      end

      def to_h
        {
          name: @name,
          passed: @passed,
          expected: @expected,
          actual: @actual,
          message: @message
        }.compact
      end
    end
  end
end
