# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Suite do
  describe ".define" do
    it "registers a suite with scenarios" do
      suite = described_class.define("test-suite") do
        scenario "greets" do
          input "Hello"
          grader :response_includes, pattern: "Hi"
        end

        scenario "farewells" do
          input "Bye"
          grader :response_includes, pattern: "Goodbye"
        end
      end

      expect(suite.name).to eq("test-suite")
      expect(suite.size).to eq(2)
      expect(suite.scenarios.first.name).to eq("greets")
    end
  end

  describe ".fetch" do
    it "retrieves a registered suite" do
      described_class.define("findme") do
        scenario "s1" do
          input "x"
          grader :response_includes, pattern: "y"
        end
      end

      found = described_class.fetch("findme")
      expect(found.name).to eq("findme")
    end

    it "raises for unknown suite" do
      expect {
        described_class.fetch("nope")
      }.to raise_error(RubyLLM::Eval::Error, /not found/)
    end
  end

  describe ".all" do
    it "returns all registered suites" do
      described_class.define("a") do
        scenario("s") { input("x"); grader(:response_includes, pattern: "y") }
      end
      described_class.define("b") do
        scenario("s") { input("x"); grader(:response_includes, pattern: "y") }
      end

      expect(described_class.all.size).to eq(2)
    end
  end
end
