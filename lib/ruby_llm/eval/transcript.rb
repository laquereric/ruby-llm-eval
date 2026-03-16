# frozen_string_literal: true

module RubyLLM
  module Eval
    class Transcript
      Entry = Struct.new(:role, :content, :tool_calls, :tokens, keyword_init: true) do
        def tool_call?
          tool_calls && !tool_calls.empty?
        end
      end

      attr_reader :entries

      def initialize
        @entries = []
      end

      def add(role:, content: nil, tool_calls: nil, tokens: nil)
        @entries << Entry.new(role: role.to_sym, content: content, tool_calls: tool_calls, tokens: tokens)
        self
      end

      def messages
        @entries.select { |e| %i[user assistant].include?(e.role) }
      end

      def tool_calls
        @entries.flat_map { |e| e.tool_calls || [] }
      end

      def tool_names
        tool_calls.map { |tc| tc[:name] || tc["name"] }.compact.uniq
      end

      def total_tokens
        input = @entries.sum { |e| e.tokens&.dig(:input) || e.tokens&.dig("input") || 0 }
        output = @entries.sum { |e| e.tokens&.dig(:output) || e.tokens&.dig("output") || 0 }
        { input: input, output: output, total: input + output }
      end

      def turn_count
        messages.count { |e| e.role == :assistant }
      end

      def response_text
        messages
          .select { |e| e.role == :assistant }
          .map(&:content)
          .compact
          .join("\n")
      end

      def to_a
        @entries.map do |e|
          h = { role: e.role }
          h[:content] = e.content if e.content
          h[:tool_calls] = e.tool_calls if e.tool_calls
          h[:tokens] = e.tokens if e.tokens
          h
        end
      end

      def size
        @entries.size
      end
    end
  end
end
