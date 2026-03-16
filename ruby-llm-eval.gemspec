# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "ruby-llm-eval"
  spec.version       = File.read(File.expand_path("VERSION", __dir__)).strip
  spec.authors       = ["Dick Dowdell"]
  spec.email         = ["dick@vvhq.com"]

  spec.summary       = "Behavioral evaluation framework for RubyLLM agents"
  spec.description   = "Scenario-based eval suite for testing LLM agent behavior — " \
                        "multi-trial execution, code-based and model-based graders, " \
                        "pass@k/pass^k metrics, baseline regression detection, and " \
                        "CI-friendly reporting (JSON, Markdown, JUnit XML)."
  spec.homepage      = "https://github.com/vvhq/ruby-llm-eval"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files         = Dir["lib/**/*.rb", "VERSION", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby_llm", ">= 1.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
end
