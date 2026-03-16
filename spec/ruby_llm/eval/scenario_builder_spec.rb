# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::ScenarioBuilder do
  it "builds a scenario via DSL" do
    builder = described_class.new("test")
    builder.input "Hello"
    builder.grader :response_includes, pattern: "Hi"
    builder.category :regression
    builder.tags :greeting, :basic
    builder.trials 3

    scenario = builder.build

    expect(scenario.name).to eq("test")
    expect(scenario.input).to eq("Hello")
    expect(scenario.category).to eq(:regression)
    expect(scenario.tags).to eq([:greeting, :basic])
    expect(scenario.trial_count).to eq(3)
    expect(scenario.graders.size).to eq(1)
  end

  it "raises without input" do
    builder = described_class.new("test")
    builder.grader :response_includes, pattern: "Hi"

    expect { builder.build }.to raise_error(RubyLLM::Eval::Error, /must have an input/)
  end

  it "raises without graders" do
    builder = described_class.new("test")
    builder.input "Hello"

    expect { builder.build }.to raise_error(RubyLLM::Eval::Error, /must have at least one grader/)
  end

  describe "#expected_tool_call" do
    it "adds tool_called and tool_args graders" do
      builder = described_class.new("test")
      builder.input "weather?"
      builder.expected_tool_call "get_weather", city: "SF"

      scenario = builder.build
      expect(scenario.graders.size).to eq(2)
      expect(scenario.graders[0][:type]).to eq(:tool_called)
      expect(scenario.graders[1][:type]).to eq(:tool_args)
    end

    it "adds only tool_called when no args" do
      builder = described_class.new("test")
      builder.input "weather?"
      builder.expected_tool_call "get_weather"

      scenario = builder.build
      expect(scenario.graders.size).to eq(1)
    end
  end

  describe "#setup" do
    it "stores a setup block" do
      called = false
      builder = described_class.new("test")
      builder.input "Hello"
      builder.grader :response_includes, pattern: "Hi"
      builder.setup { called = true }

      scenario = builder.build
      scenario.setup_block.call
      expect(called).to be true
    end
  end
end
