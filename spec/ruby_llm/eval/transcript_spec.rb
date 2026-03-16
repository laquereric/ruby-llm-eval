# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Transcript do
  subject(:transcript) { described_class.new }

  before do
    transcript.add(role: :user, content: "Hello")
    transcript.add(
      role: :assistant,
      content: "Hi there! The temperature is 72°F.",
      tool_calls: [{ name: "get_weather", arguments: { city: "SF" } }],
      tokens: { input: 10, output: 20 }
    )
  end

  it "tracks entries" do
    expect(transcript.size).to eq(2)
  end

  it "extracts messages" do
    expect(transcript.messages.size).to eq(2)
  end

  it "extracts tool calls" do
    expect(transcript.tool_calls).to eq([{ name: "get_weather", arguments: { city: "SF" } }])
  end

  it "extracts unique tool names" do
    expect(transcript.tool_names).to eq(["get_weather"])
  end

  it "computes total tokens" do
    expect(transcript.total_tokens).to eq(input: 10, output: 20, total: 30)
  end

  it "counts assistant turns" do
    expect(transcript.turn_count).to eq(1)
  end

  it "extracts response text" do
    expect(transcript.response_text).to include("72°F")
  end

  it "serializes to array" do
    arr = transcript.to_a
    expect(arr.size).to eq(2)
    expect(arr.first[:role]).to eq(:user)
  end

  describe "Entry" do
    it "detects tool calls" do
      entry = transcript.entries[1]
      expect(entry).to be_tool_call
    end

    it "detects non-tool entries" do
      entry = transcript.entries[0]
      expect(entry).not_to be_tool_call
    end
  end
end
