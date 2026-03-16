# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Scenario do
  subject(:scenario) do
    described_class.new(
      name: "test scenario",
      input: "Hello",
      graders: [{ type: :response_includes, pattern: "Hi" }],
      category: :capability,
      tags: [:greeting]
    )
  end

  it "is frozen" do
    expect(scenario).to be_frozen
  end

  it "has a UUID id" do
    expect(scenario.id).to match(/\A[0-9a-f-]{36}\z/)
  end

  it "stores attributes" do
    expect(scenario.name).to eq("test scenario")
    expect(scenario.input).to eq("Hello")
    expect(scenario.category).to eq(:capability)
    expect(scenario.tags).to eq([:greeting])
    expect(scenario.trial_count).to eq(1)
  end

  it "freezes graders" do
    expect(scenario.graders).to be_frozen
  end

  it "enforces minimum trial count of 1" do
    s = described_class.new(name: "t", input: "x", graders: [{ type: :custom }], trial_count: 0)
    expect(s.trial_count).to eq(1)
  end

  it "rejects invalid categories" do
    expect {
      described_class.new(name: "t", input: "x", graders: [{ type: :custom }], category: :invalid)
    }.to raise_error(ArgumentError, /Invalid category/)
  end

  describe "#to_h" do
    it "serializes all fields" do
      h = scenario.to_h
      expect(h[:name]).to eq("test scenario")
      expect(h[:category]).to eq(:capability)
      expect(h[:input]).to eq("Hello")
    end
  end
end
