# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::GraderResult do
  subject(:result) { described_class.new(name: :test, passed: true, expected: "foo", actual: "foo") }

  it "is frozen" do
    expect(result).to be_frozen
  end

  it "reports passed?" do
    expect(result).to be_passed
    expect(result).not_to be_failed
  end

  it "reports failed?" do
    failed = described_class.new(name: :test, passed: false)
    expect(failed).to be_failed
    expect(failed).not_to be_passed
  end

  it "symbolizes name" do
    result = described_class.new(name: "string_name", passed: true)
    expect(result.name).to eq(:string_name)
  end

  describe "#to_h" do
    it "includes all present fields" do
      h = result.to_h
      expect(h).to eq(name: :test, passed: true, expected: "foo", actual: "foo")
    end

    it "omits nil fields" do
      h = described_class.new(name: :test, passed: true).to_h
      expect(h).to eq(name: :test, passed: true)
    end
  end
end
