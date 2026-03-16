# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Metrics do
  describe ".pass_at_k" do
    it "returns 1.0 when all pass" do
      expect(described_class.pass_at_k(10, 0, 1)).to eq(1.0)
    end

    it "returns 0.0 when none pass" do
      expect(described_class.pass_at_k(0, 10, 1)).to eq(0.0)
    end

    it "increases with k" do
      p1 = described_class.pass_at_k(5, 5, 1)
      p3 = described_class.pass_at_k(5, 5, 3)
      p5 = described_class.pass_at_k(5, 5, 5)

      expect(p1).to be < p3
      expect(p3).to be < p5
    end

    it "handles edge case of k > n" do
      result = described_class.pass_at_k(5, 5, 20)
      expect(result).to be_between(0.0, 1.0)
    end

    it "handles zero totals" do
      expect(described_class.pass_at_k(0, 0, 1)).to eq(0.0)
    end
  end

  describe ".pass_pow_k" do
    it "returns 1.0 for perfect pass rate" do
      expect(described_class.pass_pow_k(1.0, 5)).to eq(1.0)
    end

    it "returns 0.0 for zero pass rate" do
      expect(described_class.pass_pow_k(0.0, 5)).to eq(0.0)
    end

    it "decreases with k" do
      p1 = described_class.pass_pow_k(0.8, 1)
      p5 = described_class.pass_pow_k(0.8, 5)
      p10 = described_class.pass_pow_k(0.8, 10)

      expect(p1).to be > p5
      expect(p5).to be > p10
    end

    it "computes correctly for known values" do
      expect(described_class.pass_pow_k(0.9, 3)).to be_within(0.001).of(0.729)
    end
  end
end
