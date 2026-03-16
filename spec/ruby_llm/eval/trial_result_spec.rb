# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::TrialResult do
  it "is frozen" do
    result = described_class.new(trial_number: 1, status: :pass, duration_ms: 100)
    expect(result).to be_frozen
  end

  it "reports passed?" do
    result = described_class.new(trial_number: 1, status: :pass, duration_ms: 100)
    expect(result).to be_passed
  end

  it "reports failed?" do
    result = described_class.new(trial_number: 1, status: :fail, duration_ms: 100)
    expect(result).to be_failed
  end

  it "reports error?" do
    result = described_class.new(trial_number: 1, status: :error, duration_ms: 100, error_message: "boom")
    expect(result).to be_error
    expect(result.error_message).to eq("boom")
  end

  describe "#to_h" do
    it "includes error_message when present" do
      result = described_class.new(trial_number: 1, status: :error, duration_ms: 50, error_message: "fail")
      expect(result.to_h[:error_message]).to eq("fail")
    end

    it "excludes error_message when nil" do
      result = described_class.new(trial_number: 1, status: :pass, duration_ms: 50)
      expect(result.to_h).not_to have_key(:error_message)
    end
  end
end
