# frozen_string_literal: true

module RubyLLM
  module Eval
    module Grader
      class Base
        def evaluate(grader_config, transcript)
          raise NotImplementedError, "#{self.class}#evaluate must be implemented"
        end
      end
    end
  end
end
