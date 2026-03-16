# frozen_string_literal: true

module RubyLLM
  module Eval
    module Grader
      class ModelBased < Base
        DEFAULT_MODEL = "claude-sonnet-4-5"

        JUDGE_PROMPT = <<~PROMPT
          You are an evaluation judge. Assess the following AI assistant response against the provided rubric.

          ## Rubric
          %{rubric}

          ## Conversation
          %{conversation}

          ## Instructions
          Respond with ONLY a JSON object (no markdown, no code fences):
          {"passed": true/false, "reasoning": "brief explanation"}
        PROMPT

        def evaluate(grader_config, transcript)
          rubric = grader_config[:rubric]
          raise Error, "Model-based grader requires :rubric" unless rubric

          model = grader_config[:model] || DEFAULT_MODEL
          conversation = format_conversation(transcript)
          prompt = format(JUDGE_PROMPT, rubric: rubric, conversation: conversation)

          begin
            require "ruby_llm"
            chat = RubyLLM.chat(model: model)
            response = chat.ask(prompt)
            parse_judgment(response.content)
          rescue LoadError
            GraderResult.new(
              name: :llm_judge,
              passed: false,
              message: "ruby_llm gem not available for model-based grading"
            )
          rescue => e
            GraderResult.new(
              name: :llm_judge,
              passed: false,
              message: "LLM judge error: #{e.message}"
            )
          end
        end

        private

        def format_conversation(transcript)
          transcript.messages.map do |entry|
            "#{entry.role}: #{entry.content}"
          end.join("\n\n")
        end

        def parse_judgment(text)
          json = text.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
          result = JSON.parse(json, symbolize_names: true)
          GraderResult.new(
            name: :llm_judge,
            passed: !!result[:passed],
            message: result[:reasoning]
          )
        rescue JSON::ParserError
          GraderResult.new(
            name: :llm_judge,
            passed: false,
            message: "Failed to parse LLM judge response: #{text[0..200]}"
          )
        end
      end
    end
  end
end
