# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::EvalResult do
  def make_trial(num, status)
    RubyLLM::Eval::TrialResult.new(
      trial_number: num,
      status: status,
      grader_results: [],
      duration_ms: 100
    )
  end

  describe "all pass" do
    subject(:result) do
      described_class.new(
        scenario_name: "test",
        suite_name: "suite",
        trial_results: [make_trial(1, :pass), make_trial(2, :pass)]
      )
    end

    it "is passed" do
      expect(result).to be_passed
      expect(result.status).to eq(:pass)
      expect(result.pass_count).to eq(2)
      expect(result.pass_rate).to eq(1.0)
    end
  end

  describe "mixed results" do
    subject(:result) do
      described_class.new(
        scenario_name: "test",
        suite_name: "suite",
        trial_results: [make_trial(1, :pass), make_trial(2, :fail), make_trial(3, :pass)]
      )
    end

    it "is failed with correct counts" do
      expect(result).to be_failed
      expect(result.status).to eq(:fail)
      expect(result.pass_count).to eq(2)
      expect(result.fail_count).to eq(1)
      expect(result.trial_count).to eq(3)
      expect(result.pass_rate).to be_within(0.01).of(0.667)
    end
  end

  describe "with errors" do
    subject(:result) do
      described_class.new(
        scenario_name: "test",
        suite_name: "suite",
        trial_results: [make_trial(1, :pass), make_trial(2, :error)]
      )
    end

    it "reports error status" do
      expect(result.status).to eq(:error)
      expect(result.error_count).to eq(1)
    end
  end

  describe "#pass_at and #pass_pow" do
    subject(:result) do
      described_class.new(
        scenario_name: "test",
        suite_name: "suite",
        trial_results: (1..10).map { |i| make_trial(i, i <= 8 ? :pass : :fail) }
      )
    end

    it "computes pass@1" do
      expect(result.pass_at(1)).to be_within(0.01).of(0.8)
    end

    it "computes pass@5" do
      expect(result.pass_at(5)).to be > 0.99
    end

    it "computes pass^5" do
      expected = 0.8**5
      expect(result.pass_pow(5)).to be_within(0.01).of(expected)
    end
  end

  describe "#to_h" do
    it "serializes all fields" do
      result = described_class.new(
        scenario_name: "test",
        suite_name: "suite",
        trial_results: [make_trial(1, :pass)]
      )
      h = result.to_h
      expect(h[:scenario_name]).to eq("test")
      expect(h[:pass_rate]).to eq(1.0)
      expect(h[:trials]).to be_an(Array)
    end
  end
end
