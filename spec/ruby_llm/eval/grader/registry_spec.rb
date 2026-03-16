# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Grader::Registry do
  describe ".types" do
    it "includes all default grader types" do
      expected = %i[response_includes response_excludes tool_called tool_not_called
                    tool_args tool_count turn_count custom llm_judge]
      expected.each do |type|
        expect(described_class.types).to include(type)
      end
    end
  end

  describe ".fetch" do
    it "returns CodeBased for code graders" do
      expect(described_class.fetch(:response_includes)).to eq(RubyLLM::Eval::Grader::CodeBased)
    end

    it "returns ModelBased for llm_judge" do
      expect(described_class.fetch(:llm_judge)).to eq(RubyLLM::Eval::Grader::ModelBased)
    end

    it "raises for unknown types" do
      expect {
        described_class.fetch(:nonexistent)
      }.to raise_error(RubyLLM::Eval::Error, /Unknown grader type/)
    end
  end

  describe ".register" do
    it "allows custom grader registration" do
      custom_class = Class.new(RubyLLM::Eval::Grader::Base)
      described_class.register(:my_grader, custom_class)
      expect(described_class.fetch(:my_grader)).to eq(custom_class)
    end
  end
end
