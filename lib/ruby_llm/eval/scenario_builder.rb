# frozen_string_literal: true

module RubyLLM
  module Eval
    class ScenarioBuilder
      def initialize(name)
        @name = name
        @category = :capability
        @description = nil
        @input = nil
        @graders = []
        @trial_count = 1
        @tags = []
        @setup_block = nil
      end

      def category(cat)
        @category = cat
      end

      def description(desc)
        @description = desc
      end

      def input(text)
        @input = text
      end

      def grader(type, **params)
        @graders << { type: type.to_sym, **params }
      end

      def trials(count)
        @trial_count = count
      end

      def tags(*tag_list)
        @tags.concat(tag_list.flatten)
      end

      def setup(&block)
        @setup_block = block
      end

      def expected_tool_call(tool_name, **args)
        grader(:tool_called, tool: tool_name)
        grader(:tool_args, tool: tool_name, args: args) unless args.empty?
      end

      def build
        raise Error, "Scenario '#{@name}' must have an input" unless @input
        raise Error, "Scenario '#{@name}' must have at least one grader" if @graders.empty?

        Scenario.new(
          name: @name,
          category: @category,
          description: @description,
          input: @input,
          graders: @graders,
          trial_count: @trial_count,
          tags: @tags,
          setup_block: @setup_block
        )
      end
    end
  end
end
