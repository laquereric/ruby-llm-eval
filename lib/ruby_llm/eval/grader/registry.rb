# frozen_string_literal: true

module RubyLLM
  module Eval
    module Grader
      class Registry
        class << self
          def register(type, grader_class)
            registry[type.to_sym] = grader_class
          end

          def fetch(type)
            registry.fetch(type.to_sym) do
              raise Error, "Unknown grader type: #{type}. Available: #{registry.keys.join(", ")}"
            end
          end

          def types
            registry.keys
          end

          def reset!
            @registry = {}
            register_defaults
          end

          private

          def register_defaults
            @registry[:response_includes] = CodeBased
            @registry[:response_excludes] = CodeBased
            @registry[:tool_called] = CodeBased
            @registry[:tool_not_called] = CodeBased
            @registry[:tool_args] = CodeBased
            @registry[:tool_count] = CodeBased
            @registry[:turn_count] = CodeBased
            @registry[:custom] = CodeBased
            @registry[:llm_judge] = ModelBased
          end

          def registry
            if @registry.nil?
              @registry = {}
              register_defaults
            end
            @registry
          end
        end
      end
    end
  end
end
