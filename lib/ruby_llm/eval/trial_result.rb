# frozen_string_literal: true

module RubyLLM
  module Eval
    class TrialResult
      attr_reader :trial_number, :status, :grader_results, :transcript,
                  :duration_ms, :error_message

      def initialize(trial_number:, status:, grader_results: [], transcript: nil,
                     duration_ms: 0, error_message: nil)
        @trial_number = trial_number
        @status = status.to_sym
        @grader_results = grader_results
        @transcript = transcript
        @duration_ms = duration_ms
        @error_message = error_message
        freeze
      end

      def passed?
        @status == :pass
      end

      def failed?
        @status == :fail
      end

      def error?
        @status == :error
      end

      def to_h
        h = {
          trial_number: @trial_number,
          status: @status,
          duration_ms: @duration_ms,
          grader_results: @grader_results.map(&:to_h)
        }
        h[:error_message] = @error_message if @error_message
        h[:tokens] = @transcript.total_tokens if @transcript
        h
      end
    end
  end
end
