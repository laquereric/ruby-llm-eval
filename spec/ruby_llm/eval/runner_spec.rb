# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Runner do
  let(:suite) do
    RubyLLM::Eval::Suite.define("runner-test") do
      scenario "basic response" do
        input "Hello"
        grader :response_includes, pattern: "Hi"
      end
    end
  end

  describe "#run with block" do
    it "passes when grader matches" do
      runner = described_class.new { |_input| "Hi there!" }
      result = runner.run(suite)

      expect(result).to be_passed
      expect(result.scenario_count).to eq(1)
      expect(result.trial_count).to eq(1)
    end

    it "fails when grader does not match" do
      runner = described_class.new { |_input| "Goodbye" }
      result = runner.run(suite)

      expect(result).not_to be_passed
      expect(result.eval_results.first.status).to eq(:fail)
    end

    it "handles hash responses" do
      runner = described_class.new do |_input|
        {
          content: "Hi from hash",
          tool_calls: [{ name: "greet", arguments: { name: "world" } }],
          tokens: { input: 5, output: 10 }
        }
      end
      result = runner.run(suite)
      expect(result).to be_passed
    end

    it "captures errors as error status" do
      runner = described_class.new { |_input| raise "boom" }
      result = runner.run(suite)

      trial = result.eval_results.first.trial_results.first
      expect(trial).to be_error
      expect(trial.error_message).to include("boom")
    end
  end

  describe "#run with agent" do
    it "calls agent.ask" do
      agent = double("agent")
      allow(agent).to receive(:respond_to?).with(:ask).and_return(true)
      allow(agent).to receive(:respond_to?).with(:content).and_return(false)
      allow(agent).to receive(:respond_to?).with(:tool_calls).and_return(false)
      allow(agent).to receive(:respond_to?).with(:input_tokens).and_return(false)
      allow(agent).to receive(:respond_to?).with(:to_s).and_return(true)
      allow(agent).to receive(:ask).and_return("Hi!")

      runner = described_class.new(agent: agent)
      result = runner.run(suite)

      expect(result).to be_passed
      expect(agent).to have_received(:ask).with("Hello")
    end
  end

  describe "multi-trial" do
    it "runs multiple trials per scenario" do
      suite = RubyLLM::Eval::Suite.define("multi-trial") do
        scenario "multi" do
          input "test"
          grader :response_includes, pattern: "ok"
          trials 3
        end
      end

      counter = 0
      runner = described_class.new do |_input|
        counter += 1
        counter.even? ? "ok" : "nope"
      end
      result = runner.run(suite)

      eval_result = result.eval_results.first
      expect(eval_result.trial_count).to eq(3)
      expect(eval_result.pass_count).to eq(1) # trial 2 passes
      expect(eval_result.fail_count).to eq(2) # trials 1, 3 fail
    end
  end

  describe "raises without agent or block" do
    it "errors when no executor" do
      runner = described_class.new
      result = runner.run(suite)

      trial = result.eval_results.first.trial_results.first
      expect(trial).to be_error
      expect(trial.error_message).to include("No agent or block")
    end
  end
end

RSpec.describe RubyLLM::Eval::RunResult do
  it "provides summary" do
    suite = RubyLLM::Eval::Suite.define("summary-test") do
      scenario("s1") { input("x"); grader(:response_includes, pattern: "y") }
    end
    runner = RubyLLM::Eval::Runner.new { |_| "y" }
    result = runner.run(suite)

    expect(result.summary).to include("1 scenarios")
    expect(result.summary).to include("100.0%")
  end

  it "supports bracket access by name" do
    suite = RubyLLM::Eval::Suite.define("bracket-test") do
      scenario("find-me") { input("x"); grader(:response_includes, pattern: "y") }
    end
    runner = RubyLLM::Eval::Runner.new { |_| "y" }
    result = runner.run(suite)

    expect(result["find-me"]).not_to be_nil
    expect(result["find-me"].scenario_name).to eq("find-me")
  end
end
