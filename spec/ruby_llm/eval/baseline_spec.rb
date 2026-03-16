# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Baseline do
  let(:tmpdir) { Dir.mktmpdir }

  before { described_class.directory = tmpdir }
  after { FileUtils.rm_rf(tmpdir); described_class.reset! }

  def make_result(name, status)
    trial = RubyLLM::Eval::TrialResult.new(trial_number: 1, status: status, duration_ms: 50)
    RubyLLM::Eval::EvalResult.new(
      scenario_name: name,
      suite_name: "test",
      trial_results: [trial]
    )
  end

  describe ".save and .load" do
    it "round-trips results" do
      results = [make_result("s1", :pass), make_result("s2", :fail)]
      path = described_class.save("my-baseline", results)

      expect(File.exist?(path)).to be true

      loaded = described_class.load("my-baseline")
      expect(loaded[:name]).to eq("my-baseline")
      expect(loaded[:results].size).to eq(2)
      expect(loaded[:results][0][:scenario_name]).to eq("s1")
    end
  end

  describe ".exists?" do
    it "returns false for missing" do
      expect(described_class.exists?("nope")).to be false
    end

    it "returns true for saved" do
      described_class.save("exists", [make_result("s1", :pass)])
      expect(described_class.exists?("exists")).to be true
    end
  end

  describe ".compare" do
    it "detects regressions" do
      described_class.save("baseline", [make_result("s1", :pass), make_result("s2", :pass)])
      current = [make_result("s1", :pass), make_result("s2", :fail)]

      regressions = described_class.compare("baseline", current)
      expect(regressions.size).to eq(1)
      expect(regressions[0][:scenario_name]).to eq("s2")
      expect(regressions[0][:previous_status]).to eq(:pass)
      expect(regressions[0][:current_status]).to eq(:fail)
    end

    it "returns empty when no regressions" do
      described_class.save("baseline", [make_result("s1", :pass)])
      current = [make_result("s1", :pass)]

      expect(described_class.compare("baseline", current)).to be_empty
    end

    it "returns empty when no baseline exists" do
      expect(described_class.compare("missing", [make_result("s1", :pass)])).to be_empty
    end
  end
end
