# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Report do
  let(:run_result) do
    suite = RubyLLM::Eval::Suite.define("report-test") do
      scenario("passes") { input("x"); grader(:response_includes, pattern: "y") }
      scenario("fails") { input("x"); grader(:response_includes, pattern: "z") }
    end
    runner = RubyLLM::Eval::Runner.new { |_| "y is here" }
    runner.run(suite)
  end

  subject(:report) { described_class.new(run_result) }

  describe "#to_json" do
    it "includes summary" do
      json = report.to_json
      expect(json[:summary][:total]).to eq(2)
      expect(json[:summary][:pass]).to eq(1)
      expect(json[:summary][:fail]).to eq(1)
    end

    it "includes all results" do
      expect(report.to_json[:results].size).to eq(2)
    end
  end

  describe "#to_markdown" do
    it "produces a formatted report" do
      md = report.to_markdown
      expect(md).to include("# Eval Report: report-test")
      expect(md).to include("## Summary")
      expect(md).to include("## Failures")
      expect(md).to include("fails")
    end
  end

  describe "#to_junit_xml" do
    it "produces valid XML structure" do
      xml = report.to_junit_xml
      expect(xml).to include('<?xml version="1.0"')
      expect(xml).to include('<testsuite name="report-test"')
      expect(xml).to include('tests="2"')
      expect(xml).to include('failures="1"')
      expect(xml).to include("<failure")
    end
  end

  describe "with regressions" do
    it "includes regressions in markdown" do
      regressions = [{ scenario_name: "s1", previous_status: :pass, current_status: :fail }]
      report = described_class.new(run_result, regressions: regressions)
      md = report.to_markdown
      expect(md).to include("## Regressions")
      expect(md).to include("s1")
    end
  end
end
