# frozen_string_literal: true

module RubyLLM
  module Eval
    class Suite
      attr_reader :name, :scenarios

      def initialize(name)
        @name = name
        @scenarios = []
      end

      def scenario(name, &block)
        builder = ScenarioBuilder.new(name)
        builder.instance_eval(&block)
        @scenarios << builder.build
      end

      def size
        @scenarios.size
      end

      class << self
        def define(name, &block)
          suite = new(name)
          suite.instance_eval(&block)
          registry[name] = suite
          suite
        end

        def fetch(name)
          registry.fetch(name) do
            raise Error, "Suite '#{name}' not found. Available: #{registry.keys.join(", ")}"
          end
        end

        def all
          registry.values
        end

        def reset!
          @registry = {}
        end

        private

        def registry
          @registry ||= {}
        end
      end
    end
  end
end
