# frozen_string_literal: true

RSpec.describe RubyLLM::Eval::Grader::ModelBased do
  subject(:grader) { described_class.new }

  let(:transcript) do
    t = RubyLLM::Eval::Transcript.new
    t.add(role: :user, content: "What is 2+2?")
    t.add(role: :assistant, content: "The answer is 4.")
    t
  end

  describe "#evaluate" do
    it "raises without rubric" do
      expect {
        grader.evaluate({ type: :llm_judge }, transcript)
      }.to raise_error(RubyLLM::Eval::Error, /requires :rubric/)
    end

    context "when ruby_llm is not available" do
      before do
        allow(grader).to receive(:require).with("ruby_llm").and_raise(LoadError)
      end

      it "returns failure with message" do
        result = grader.evaluate({ type: :llm_judge, rubric: "Is the answer correct?" }, transcript)
        expect(result).to be_failed
        expect(result.message).to include("not available")
      end
    end

    context "with mocked RubyLLM" do
      let(:chat) { double("chat") }

      before do
        # Prevent loading the real ruby_llm gem; define .chat for stubbing
        allow(grader).to receive(:require).with("ruby_llm").and_return(true)
        RubyLLM.define_singleton_method(:chat) { |**_| nil } unless RubyLLM.respond_to?(:chat)
        allow(RubyLLM).to receive(:chat).and_return(chat)
      end

      it "passes when judge says passed" do
        response = double("response", content: '{"passed": true, "reasoning": "Correct answer"}')
        allow(chat).to receive(:ask).and_return(response)

        result = grader.evaluate({ type: :llm_judge, rubric: "Is the answer correct?" }, transcript)
        expect(result).to be_passed
        expect(result.message).to eq("Correct answer")
      end

      it "fails when judge says failed" do
        response = double("response", content: '{"passed": false, "reasoning": "Wrong answer"}')
        allow(chat).to receive(:ask).and_return(response)

        result = grader.evaluate({ type: :llm_judge, rubric: "Is the answer correct?" }, transcript)
        expect(result).to be_failed
      end

      it "handles unparseable response" do
        response = double("response", content: "I think it is correct")
        allow(chat).to receive(:ask).and_return(response)

        result = grader.evaluate({ type: :llm_judge, rubric: "test" }, transcript)
        expect(result).to be_failed
        expect(result.message).to include("Failed to parse")
      end

      it "strips markdown fences from response" do
        response = double("response", content: "```json\n{\"passed\": true, \"reasoning\": \"ok\"}\n```")
        allow(chat).to receive(:ask).and_return(response)

        result = grader.evaluate({ type: :llm_judge, rubric: "test" }, transcript)
        expect(result).to be_passed
      end
    end
  end
end
