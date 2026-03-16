# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Grader::CodeBased do
  subject(:grader) { described_class.new }

  let(:transcript) do
    t = RubyLLM::Eval::Transcript.new
    t.add(role: :user, content: "Hello")
    t.add(
      role: :assistant,
      content: "The temperature is 72 degrees.",
      tool_calls: [
        { name: "get_weather", arguments: { city: "San Francisco" } },
        { name: "format_response", arguments: { unit: "fahrenheit" } }
      ]
    )
    t
  end

  describe ":response_includes" do
    it "passes when pattern matches" do
      result = grader.evaluate({ type: :response_includes, pattern: "72 degrees" }, transcript)
      expect(result).to be_passed
    end

    it "passes with regex" do
      result = grader.evaluate({ type: :response_includes, pattern: /\d+ degrees/ }, transcript)
      expect(result).to be_passed
    end

    it "fails when pattern doesn't match" do
      result = grader.evaluate({ type: :response_includes, pattern: "100 degrees" }, transcript)
      expect(result).to be_failed
    end
  end

  describe ":response_excludes" do
    it "passes when pattern doesn't match" do
      result = grader.evaluate({ type: :response_excludes, pattern: "error" }, transcript)
      expect(result).to be_passed
    end

    it "fails when pattern matches" do
      result = grader.evaluate({ type: :response_excludes, pattern: "72" }, transcript)
      expect(result).to be_failed
    end
  end

  describe ":tool_called" do
    it "passes when tool was called" do
      result = grader.evaluate({ type: :tool_called, tool: "get_weather" }, transcript)
      expect(result).to be_passed
    end

    it "fails when tool wasn't called" do
      result = grader.evaluate({ type: :tool_called, tool: "send_email" }, transcript)
      expect(result).to be_failed
    end
  end

  describe ":tool_not_called" do
    it "passes when tool wasn't called" do
      result = grader.evaluate({ type: :tool_not_called, tool: "send_email" }, transcript)
      expect(result).to be_passed
    end

    it "fails when tool was called" do
      result = grader.evaluate({ type: :tool_not_called, tool: "get_weather" }, transcript)
      expect(result).to be_failed
    end
  end

  describe ":tool_args" do
    it "passes with matching args" do
      result = grader.evaluate(
        { type: :tool_args, tool: "get_weather", args: { city: "San Francisco" } },
        transcript
      )
      expect(result).to be_passed
    end

    it "fails with wrong args" do
      result = grader.evaluate(
        { type: :tool_args, tool: "get_weather", args: { city: "New York" } },
        transcript
      )
      expect(result).to be_failed
    end

    it "fails when tool not found" do
      result = grader.evaluate(
        { type: :tool_args, tool: "missing", args: { x: 1 } },
        transcript
      )
      expect(result).to be_failed
    end
  end

  describe ":tool_count" do
    it "passes with correct count" do
      result = grader.evaluate({ type: :tool_count, expected: 2 }, transcript)
      expect(result).to be_passed
    end

    it "fails with wrong count" do
      result = grader.evaluate({ type: :tool_count, expected: 5 }, transcript)
      expect(result).to be_failed
    end
  end

  describe ":turn_count" do
    it "passes within range" do
      result = grader.evaluate({ type: :turn_count, min: 1, max: 3 }, transcript)
      expect(result).to be_passed
    end

    it "fails outside range" do
      result = grader.evaluate({ type: :turn_count, min: 5, max: 10 }, transcript)
      expect(result).to be_failed
    end
  end

  describe ":custom" do
    it "passes with truthy lambda" do
      result = grader.evaluate(
        { type: :custom, check: ->(t) { t.tool_names.include?("get_weather") } },
        transcript
      )
      expect(result).to be_passed
    end

    it "accepts GraderResult return" do
      custom_result = RubyLLM::Eval::GraderResult.new(name: :my_check, passed: true, message: "ok")
      result = grader.evaluate(
        { type: :custom, check: ->(_t) { custom_result } },
        transcript
      )
      expect(result).to be_passed
      expect(result.name).to eq(:my_check)
    end

    it "raises without check lambda" do
      expect {
        grader.evaluate({ type: :custom }, transcript)
      }.to raise_error(RubyLLM::Eval::Error, /requires :check lambda/)
    end
  end
end
