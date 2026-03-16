# frozen_string_literal: true

require "json"
require "fileutils"

module RubyLLM
  module Eval
    class Baseline
      class << self
        def directory
          @directory ||= "evals/baselines"
        end

        def directory=(dir)
          @directory = dir
        end

        def save(name, eval_results)
          FileUtils.mkdir_p(directory)
          path = file_path(name)
          data = {
            name: name,
            saved_at: Time.now.iso8601,
            results: eval_results.map(&:to_h)
          }
          File.write(path, JSON.pretty_generate(data))
          path
        end

        def load(name)
          path = file_path(name)
          return nil unless File.exist?(path)

          JSON.parse(File.read(path), symbolize_names: true)
        end

        def exists?(name)
          File.exist?(file_path(name))
        end

        def compare(name, current_results)
          baseline = self.load(name)
          return [] unless baseline

          baseline_by_name = baseline[:results].each_with_object({}) do |r, h|
            h[r[:scenario_name]] = r[:status]
          end

          current_results.filter_map do |result|
            prev = baseline_by_name[result.scenario_name]
            next unless prev
            next if prev.to_sym == result.status

            {
              scenario_name: result.scenario_name,
              previous_status: prev.to_sym,
              current_status: result.status
            }
          end
        end

        def reset!
          @directory = nil
        end

        private

        def file_path(name)
          File.join(directory, "#{name}.json")
        end
      end
    end
  end
end
