# Integration Testing with llama-1b-container

The integration tests in `test/integration/` run behavioral evals against a locally-hosted Llama-3.2-1B-Instruct model served by [laquereric/llama-1b-container](https://github.com/laquereric/llama-1b-container). They use the same `ruby-llm-eval` framework as the unit specs, but call a real model over HTTP instead of using test doubles.

## Upstream dependencies

`ruby-llm-eval` is a clean extension of [crmne/ruby_llm](https://github.com/crmne/ruby_llm). It adds no monkey-patches and requires no changes to `ruby_llm` itself — it consumes the public `RubyLLM::` namespace and builds the eval harness on top.

| Dependency | Source | Role |
|---|---|---|
| [crmne/ruby_llm](https://github.com/crmne/ruby_llm) | `Gemfile` (GitHub), gemspec runtime dep | LLM provider abstraction; agents, chat, tool-call interfaces |
| [laquereric/llama-1b-container](https://github.com/laquereric/llama-1b-container) | cloned into `test/llama-3.2-1b-container/` | Local Llama-3.2-1B-Instruct server for integration tests |

The `Gemfile` pins `ruby_llm` directly to the GitHub source so development always tracks the canonical upstream:

```ruby
gem "ruby_llm", github: "crmne/ruby_llm", branch: "main"
```

The gemspec declares the looser rubygems constraint (`>= 1.0`) so published releases of `ruby-llm-eval` are compatible with any stable `ruby_llm` release.

## Prerequisites

- Apple Silicon Mac (M1/M2/M3/M4)
- Homebrew
- ~10 GB free disk space
- Podman with the `libkrun` machine provider

## Getting the container

Clone `llama-1b-container` into the `test/` directory of this project under the name `llama-3.2-1b-container`:

```bash
git clone https://github.com/laquereric/llama-1b-container.git \
  test/llama-3.2-1b-container
```

This keeps the container tooling co-located with the integration tests and out of the gem's production files.

## Starting the container

`mac/bin/manage.rb` is the single entry point for all container lifecycle operations on macOS. Pass `--ok` to run the full setup-and-start sequence in one step:

```bash
ruby test/llama-3.2-1b-container/mac/bin/manage.rb --ok
```

`--ok` orchestrates the following steps automatically, skipping any that are already complete:

| Step | Underlying script | What it does |
|------|------------------|--------------|
| Install | `mac/bin/install.sh` | Installs Podman and krunkit via Homebrew |
| Start | `mac/bin/start.sh` | Initializes and starts the Podman machine with the `libkrun` provider (4 CPUs, 8 GB RAM, 100 GB disk) |
| Pull | `mac/bin/pull.sh` | Pulls `ghcr.io/laquereric/llama-cpp-vulkan:latest` |
| Download | `mac/bin/download_model.sh` | Downloads `Llama-3.2-1B-Instruct-Q4_K_M.gguf` into `~/models/` (~4 GB) |
| Run | `mac/bin/run.sh` | Starts the llama.cpp server on port 8080 with full GPU offload |

When `--ok` completes the server is listening at `http://localhost:8080/v1`. Leave it running in the background or a separate terminal while you run the tests.

To verify the server is up before running tests:

```bash
curl -s http://localhost:8080/v1/models | ruby -e "require 'json'; puts JSON.parse(STDIN.read)['data'].map{|m| m['id']}"
```

## Running the tests

```bash
ruby test/integration/llama_container_test.rb
```

If the container is not running, all tests are automatically skipped — the suite will not fail.

### Custom host

If you are running the container on a different host or port, set `LLAMA_HOST`:

```bash
LLAMA_HOST=http://192.168.1.50:8080 ruby test/integration/llama_container_test.rb
```

## Test structure

| File | Purpose |
|------|---------|
| `test/test_helper.rb` | Minitest setup, `LlamaContainerHelper` module |
| `test/integration/llama_container_test.rb` | All integration test classes |

### Test classes

**`LlamaContainerConnectivityTest`**

Verifies the container is reachable and the API is responsive before any eval logic runs.

- `test_models_endpoint_lists_available_models` — `GET /v1/models` returns a valid response with a `data` array.
- `test_raw_completion_returns_non_empty_response` — A basic chat completion returns a non-empty string.

**`LlamaContainerBasicCapabilityTest`**

Behavioral evals using code-based graders against the live model.

- `test_greeting_scenario_passes` — Model responds to a greeting with a message containing "hello".
- `test_instruction_following_yes_no_answer` — Model follows the instruction to answer YES or NO.
- `test_basic_arithmetic` — Model correctly answers 2 + 2 = 4.
- `test_response_excludes_opposite_answer` — Model does not say "goodbye" when asked to say hello.
- `test_turn_count_is_one` — The transcript contains exactly one assistant turn per invocation.

**`LlamaContainerMultiTrialTest`**

Exercises the multi-trial eval path to check answer consistency.

- `test_consistent_factual_answer_across_trials` — Runs "capital of France?" 3 times at `temperature: 0`; requires at least 2/3 trials to include "Paris".

**`LlamaContainerReportTest`**

Verifies the `Report` class works end-to-end with real model output.

- `test_run_result_produces_valid_json_report` — `Report#to_json` returns a Hash with the expected keys.
- `test_run_result_produces_markdown_report` — `Report#to_markdown` includes the scenario name and suite name.

## How it works

The tests bypass ruby_llm's provider configuration and call the container directly via Ruby's stdlib `net/http`. This keeps the integration layer thin and dependency-free.

```
test block
  └─ call_llama(prompt)           # POST /v1/chat/completions → plain string
       └─ RubyLLM::Eval::Runner   # wraps the block, builds a Transcript
            └─ Grader::CodeBased  # evaluates the response deterministically
```

The `LlamaContainerHelper` module (in `test/test_helper.rb`) provides:

- `container_available?` — probes `GET /v1/models`; returns `false` on `ECONNREFUSED`.
- `call_llama(prompt, temperature: 0.0)` — sends a chat completion request; raises on non-2xx.
- `llama_runner` — returns a `Runner` whose block calls `call_llama`.

All test classes call `skip` in `setup` if `container_available?` returns false, so CI passes cleanly when no container is present.

## Adding new scenarios

Use the scenario DSL inside any test method:

```ruby
suite = RubyLLM::Eval::Suite.define("my-suite") do
  scenario "my scenario" do
    input "Your prompt here."
    grader :response_includes, pattern: /expected pattern/i
    trials 3
  end
end

result = llama_runner.run(suite)
assert result.passed?, "Expected scenario to pass"
```

Available code-based grader types: `:response_includes`, `:response_excludes`, `:tool_called`, `:tool_not_called`, `:tool_args`, `:tool_count`, `:turn_count`, `:custom`.

## Troubleshooting

**All tests are skipped**

The container is not reachable at `LLAMA_HOST` (default `http://localhost:8080`). Start it with:

```bash
ruby test/llama-3.2-1b-container/mac/bin/manage.rb --ok
```

Then confirm the server is up:

```bash
curl http://localhost:8080/v1/models
```

**Slow responses / timeouts**

The `read_timeout` is set to 120 seconds. On first load the model may take longer. If the container has started but is still loading the model, wait for the log line `llama server listening` before running tests.

**GPU not recognized**

Re-run `podman machine ssh ls /dev/dri`. If `card0` is absent, the `libkrun` machine provider may not have been set before `podman machine init`. Reinitialize:

```bash
podman machine stop
podman machine rm
CONTAINERS_MACHINE_PROVIDER=libkrun podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine start
```
