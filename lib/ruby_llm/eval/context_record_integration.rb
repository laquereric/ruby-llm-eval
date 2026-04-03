# frozen_string_literal: true

require "context_record"

module RubyLLM
  module Eval
    module ContextRecordIntegration
      module ScenarioInputHelper
        # Extracts a plain String from either a String or a ContextRecord::Record.
        # @param input [String, ContextRecord::Record]
        # @return [String]
        def self.extract_string(input)
          return input if input.is_a?(String)

          if input.is_a?(ContextRecord::Record)
            payload = input.payload
            text = payload["text"] || payload[:text]
            return text.value if text.is_a?(ContextRecord::ContextPrimitive)
            return text.to_s if text
            return input.to_json
          end

          input.to_s
        end
      end

      module TranscriptMethods
        ACTION_FOR_ROLE = {
          user:      :execute,
          assistant: :create,
          tool:      :read
        }.freeze

        TARGET_FOR_ROLE = {
          user:      "transcript/user",
          assistant: "transcript/assistant",
          tool:      "transcript/tool"
        }.freeze

        def to_context_records
          @entries.map do |entry|
            role   = entry.role
            action = ACTION_FOR_ROLE.fetch(role, :read)
            target = TARGET_FOR_ROLE.fetch(role, "transcript/#{role}")

            payload = {}
            if entry.content
              payload["content"] = ContextRecord::ContextPrimitive.new(
                type: "vv:Literal", value: entry.content.to_s
              )
            end
            if entry.tool_calls
              payload["tool_calls"] = ContextRecord::ContextPrimitive.new(
                type: "vv:Action", value: entry.tool_calls
              )
            end

            metadata = { "role" => role.to_s }
            if entry.tokens
              metadata["tokens"] = ContextRecord::ContextPrimitive.new(
                type: "vv:Literal", value: entry.tokens
              )
            end

            ContextRecord::Record.new(
              action:   action,
              target:   target,
              payload:  payload,
              metadata: metadata
            )
          end
        end
      end

      module EvalResultMethods
        # Convert eval result to a ContextRecord with ontology references.
        #
        # If the scenario carries a :tested_property tag (set by
        # OntologyScenarioGenerator), the resulting Record includes
        # vv:testedProperty in metadata — linking the eval result back
        # to the ontology property under test.
        #
        # @return [ContextRecord::Record]
        def to_context_record
          meta = {
            "suite_name"    => @suite_name,
            "scenario_name" => @scenario_name
          }

          # Attach ontology references when available from scenario tags
          if defined?(@scenario) && @scenario.respond_to?(:tags)
            tested_prop = @scenario.tags.find { |t| t.to_s.start_with?("tested:") }
            meta["vv:testedProperty"] = tested_prop.to_s.sub("tested:", "") if tested_prop
          end

          ContextRecord::Record.new(
            action:   :evaluate,
            target:   "eval_result/#{@suite_name}/#{@scenario_name}",
            rdf_type: "vv:EvalResult",
            payload: {
              "status"          => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: status.to_s),
              "trial_count"     => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: trial_count),
              "pass_count"      => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: pass_count),
              "fail_count"      => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: fail_count),
              "pass_rate"       => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: pass_rate.round(4)),
              "avg_duration_ms" => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: avg_duration_ms.round(1))
            },
            metadata: meta
          )
        end
      end

      module RunResultMethods
        def to_context_record
          result_ids = @eval_results.map { |r| r.to_context_record.id }

          ContextRecord::Record.new(
            action:  :evaluate,
            target:  "run_result/#{@suite_name}",
            payload: {
              "suite_name"     => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: @suite_name),
              "scenario_count" => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: scenario_count),
              "trial_count"    => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: trial_count),
              "pass_rate"      => ContextRecord::ContextPrimitive.new(type: "vv:EvalResult", value: pass_rate.round(4))
            },
            metadata: {
              "result_ids" => result_ids
            }
          )
        end
      end
    end

    Transcript.include(ContextRecordIntegration::TranscriptMethods)
    EvalResult.include(ContextRecordIntegration::EvalResultMethods)
    RunResult.include(ContextRecordIntegration::RunResultMethods)
  end
end
