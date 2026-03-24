# ruby_llm vs ruby-llm-eval Runner

## TL;DR

`runner.rb` is not redundant with `ruby_llm`. Keep it.

`ruby_llm` provides `Chat#ask` and `Agent#ask` for single-turn execution.
`Runner` adds everything that turns a single call into a behavioral eval.

| Capability | `ruby_llm` | `Runner` |
|---|---|---|
| Call a model | ✅ | delegates to it |
| Multi-trial execution (run N times) | ❌ | ✅ |
| Error capture → `:error` status (not crash) | ❌ | ✅ |
| Transcript building (user/assistant/tool turns) | ❌ | ✅ |
| Grader evaluation → `GraderResult[]` | ❌ | ✅ |
| Per-trial timing | ❌ | ✅ |
| `RunResult` / `EvalResult` aggregation | ❌ | ✅ |

The only overlap is calling `agent.ask(input)` — which is intentional API design, not duplication. `Runner` is the eval harness wrapper around `ruby_llm`'s execution primitives, not a re-implementation of them.

---

## What ruby_llm provides

**`Chat`** (`ruby_llm/chat.rb`) — low-level provider abstraction

- `ask(message)` — single-turn prompt → response
- `complete()` — streaming completion
- `with_tools()`, `with_model()`, `with_temperature()`, `with_instructions()`
- Returns response objects with `.content`, `.tool_calls`, `.input_tokens`, `.output_tokens`

**`Agent`** (`ruby_llm/agent.rb`) — high-level wrapper around Chat

- Class DSL: `model()`, `tools()`, `instructions()`, `temperature()`
- Delegates `ask`, `say`, `complete`, `with_tool` to an internal Chat
- Optionally persists conversation to a database

What ruby_llm does **not** provide:

- Multi-trial execution
- Evaluation or grading of responses
- Transcript or result aggregation
- Error capture into structured pass/fail results
- Statistical metrics (pass@k, pass_pow)
- Reporting (JSON, Markdown, JUnit XML)

---

## What Runner adds

### Multi-trial execution

```ruby
trial_results = (1..scenario.trial_count).map do |trial_num|
  run_trial(scenario, trial_num)
end
```

Runs the same input N times and aggregates results, enabling statistical analysis: pass rate, pass@k, pass_pow.

### Error capture into structured results

```ruby
rescue => e
  TrialResult.new(
    trial_number: trial_num,
    status: :error,
    error_message: "#{e.class}: #{e.message}"
  )
```

Errors don't crash the suite — they're recorded as `:error` status with the message preserved for debugging.

### Transcript building

```ruby
transcript = Transcript.new
transcript.add(role: :user, content: input)
transcript.add(role: :assistant, content: ..., tool_calls: ..., tokens: ...)
```

Builds a structured conversation record that graders and reports consume. `ruby_llm` manages its own internal message history for continuity; `Transcript` is an immutable eval artifact.

### Grader evaluation

```ruby
grader_results = evaluate_graders(scenario.graders, transcript)
status = grader_results.all?(&:passed?) ? :pass : :fail
```

Runs code-based graders (`:response_includes`, `:tool_called`, `:turn_count`, etc.) and model-based graders (`:llm_judge`) against the transcript. Neither exists in `ruby_llm`.

### Agent interface flexibility

```ruby
if @agent.respond_to?(:ask)
  @agent.ask(input)
elsif @agent.respond_to?(:call)
  @agent.call(input)
end
```

Accepts a `ruby_llm` Agent, any object responding to `#ask` or `#call`, or a plain block — so the eval harness is not coupled to a specific `ruby_llm` class.

### Result hierarchy

- **`RunResult`** — suite level: `scenario_count`, `trial_count`, `pass_rate`, `summary()`
- **`EvalResult`** — per scenario: `status`, `pass_count`, `fail_count`, `pass_at(k)`, `pass_pow(k)`, `avg_duration_ms`
- **`TrialResult`** — per trial: `status`, `grader_results[]`, `transcript`, `duration_ms`, `error_message`

None of these exist in `ruby_llm`.

---

## The relationship in one diagram

```
ruby_llm                          ruby-llm-eval
─────────────────────────────     ─────────────────────────────────────────
Chat / Agent                      Runner
  └─ ask(input) ──────────────────► execute_agent(input)
       └─ Response                    └─ Transcript  ◄── graders evaluate this
            .content                       └─ TrialResult (:pass / :fail / :error)
            .tool_calls                         └─ EvalResult (N trials aggregated)
            .input_tokens                            └─ RunResult (M scenarios)
```

`ruby_llm` handles the left side. `Runner` handles the right side and calls into `ruby_llm` only for the `ask` step.

---

## Example showing the distinction

```ruby
# ruby_llm — single execution, no grading
agent = RubyLLM.chat(model: "claude-sonnet-4-5")
response = agent.ask("Calculate 2 + 2")
puts response.content  # "4"

# ruby-llm-eval — eval harness, 10 trials, graded
suite = RubyLLM::Eval::Suite.define("math") do
  scenario "addition" do
    input "Calculate 2 + 2"
    grader :response_includes, pattern: "4"
    trials 10
  end
end

runner = RubyLLM::Eval::Runner.new(agent: agent)
result = runner.run(suite)
puts result.pass_rate   # 1.0 (10/10 passed)
puts result.summary     # "1 scenarios, 10 trials, 1/1 passed (100.0%)"
```
