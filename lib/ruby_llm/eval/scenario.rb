# frozen_string_literal: true

require "securerandom"

module RubyLLM
  module Eval
    class Scenario
      CATEGORIES = %i[capability regression].freeze

      attr_reader :id, :name, :category, :description, :input,
                  :graders, :trial_count, :tags, :setup_block

      def initialize(name:, input:, graders:, category: :capability,
                     description: nil, trial_count: 1, tags: [], setup_block: nil)
        @id = SecureRandom.uuid
        @name = name
        @category = validate_category(category)
        @description = description
        @input = input
        @graders = graders.freeze
        @trial_count = [trial_count, 1].max
        @tags = tags.map(&:to_sym).freeze
        @setup_block = setup_block
        freeze
      end

      def to_h
        {
          id: @id,
          name: @name,
          category: @category,
          description: @description,
          input: @input,
          graders: @graders,
          trial_count: @trial_count,
          tags: @tags
        }
      end

      private

      def validate_category(cat)
        cat = cat.to_sym
        return cat if CATEGORIES.include?(cat)

        raise ArgumentError, "Invalid category: #{cat}. Must be one of: #{CATEGORIES.join(", ")}"
      end
    end
  end
end
