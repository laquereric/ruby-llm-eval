# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::ContextRecordIntegration do
  let(:helper) { described_class::ScenarioInputHelper }

  describe "ScenarioInputHelper.extract_string" do
    it "passes through a plain String unchanged" do
      expect(helper.extract_string("hello")).to eq("hello")
    end

    it "extracts text from a Record with a plain string payload" do
      record = ContextRecord::Record.new(
        action: :execute,
        target: "scenario/input",
        payload: { "text" => "what is 2+2?" }
      )
      expect(helper.extract_string(record)).to eq("what is 2+2?")
    end

    it "extracts text from a Record with a ContextPrimitive payload" do
      primitive = ContextRecord::ContextPrimitive.new(type: "vv:Literal", value: "describe the sky")
      record = ContextRecord::Record.new(
        action: :execute,
        target: "scenario/input",
        payload: { "text" => primitive }
      )
      expect(helper.extract_string(record)).to eq("describe the sky")
    end

    it "falls back to to_json when no text key is present" do
      record = ContextRecord::Record.new(
        action: :execute,
        target: "scenario/input",
        payload: { "other" => "data" }
      )
      result = helper.extract_string(record)
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end

  describe "Runner with ContextRecord::Record input" do
    it "passes extracted string to block" do
      primitive = ContextRecord::ContextPrimitive.new(type: "vv:Literal", value: "what is ruby?")
      record = ContextRecord::Record.new(
        action: :execute,
        target: "scenario/input",
        payload: { "text" => primitive }
      )

      received = nil
      runner = RubyLLM::Eval::Runner.new { |input| received = input; "Ruby is a language." }

      suite = RubyLLM::Eval.define("record_input_test") do
        scenario "s1" do
          input record
          grader :exact_match, expected: "Ruby is a language."
        end
      end

      runner.run(suite)
      expect(received).to eq("what is ruby?")

      RubyLLM::Eval.reset!
    end
  end

  describe "Transcript#to_context_records" do
    let(:transcript) do
      t = RubyLLM::Eval::Transcript.new
      t.add(role: :user, content: "ping")
      t.add(role: :assistant, content: "pong", tokens: { input: 1, output: 1 })
      t.add(role: :tool, content: "tool_result")
      t
    end

    subject(:records) { transcript.to_context_records }

    it "returns one Record per entry" do
      expect(records.size).to eq(3)
    end

    it "maps user role to action :execute and target transcript/user" do
      user_rec = records.first
      expect(user_rec.action).to eq(:execute)
      expect(user_rec.target).to eq("transcript/user")
    end

    it "maps assistant role to action :create and target transcript/assistant" do
      asst_rec = records[1]
      expect(asst_rec.action).to eq(:create)
      expect(asst_rec.target).to eq("transcript/assistant")
    end

    it "maps tool role to action :read and target transcript/tool" do
      tool_rec = records[2]
      expect(tool_rec.action).to eq(:read)
      expect(tool_rec.target).to eq("transcript/tool")
    end
  end

  describe "EvalResult#to_context_record" do
    let(:trial) do
      RubyLLM::Eval::TrialResult.new(
        trial_number: 1,
        status: :pass,
        grader_results: [],
        transcript: RubyLLM::Eval::Transcript.new,
        duration_ms: 100
      )
    end

    let(:eval_result) do
      RubyLLM::Eval::EvalResult.new(
        scenario_name: "my_scenario",
        suite_name: "my_suite",
        trial_results: [trial]
      )
    end

    subject(:record) { eval_result.to_context_record }

    it "has action :evaluate" do
      expect(record.action).to eq(:evaluate)
    end

    it "has correct target string" do
      expect(record.target).to eq("eval_result/my_suite/my_scenario")
    end

    it "includes status in payload as ContextPrimitive" do
      expect(record.payload["status"]).to be_a(ContextRecord::ContextPrimitive)
      expect(record.payload["status"].value).to eq("pass")
    end
  end

  describe "RunResult#to_context_record" do
    let(:trial) do
      RubyLLM::Eval::TrialResult.new(
        trial_number: 1,
        status: :pass,
        grader_results: [],
        transcript: RubyLLM::Eval::Transcript.new,
        duration_ms: 50
      )
    end

    let(:eval_result) do
      RubyLLM::Eval::EvalResult.new(
        scenario_name: "s1",
        suite_name: "suite1",
        trial_results: [trial]
      )
    end

    let(:run_result) do
      RubyLLM::Eval::RunResult.new(suite_name: "suite1", eval_results: [eval_result])
    end

    subject(:record) { run_result.to_context_record }

    it "has action :evaluate" do
      expect(record.action).to eq(:evaluate)
    end

    it "has correct target" do
      expect(record.target).to eq("run_result/suite1")
    end

    it "includes result_ids array in metadata" do
      expect(record.metadata["result_ids"]).to be_an(Array)
      expect(record.metadata["result_ids"].size).to eq(1)
      expect(record.metadata["result_ids"].first).to match(/\A[0-9a-f-]{36}\z/)
    end
  end
end
