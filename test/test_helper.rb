# frozen_string_literal: true

require "minitest/autorun"
require "net/http"
require "json"
require_relative "../lib/ruby_llm_eval"

module LlamaContainerHelper
  LLAMA_HOST = ENV.fetch("LLAMA_HOST", "http://localhost:8080")
  MODEL_NAME = "llama"

  def container_available?
    uri = URI("#{LLAMA_HOST}/v1/models")
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue Errno::ECONNREFUSED, SocketError
    false
  end

  def call_llama(prompt, temperature: 0.0)
    uri = URI("#{LLAMA_HOST}/v1/chat/completions")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = JSON.generate(
      model: MODEL_NAME,
      messages: [{ role: "user", content: prompt }],
      temperature: temperature
    )
    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 120) do |http|
      http.request(request)
    end
    raise "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig("choices", 0, "message", "content").to_s.strip
  end

  def llama_runner
    RubyLLM::Eval::Runner.new { |input| call_llama(input) }
  end
end
