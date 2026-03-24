# Eval with context-record

`ruby-llm-eval` integrates with [laquereric/context-record](https://github.com/laquereric/context-record) to give eval runs fully typed, deterministically serializable inputs and outputs.

Without the integration, scenario inputs are plain Strings and results are plain Ruby hashes. With it, inputs can be structured `ContextRecord::Record` envelopes, transcripts serialize to JSON-LD documents, and eval results carry typed metadata that can be stored, compared, and replayed byte-identically.

---

## What the integration adds

| Capability | Without integration | With integration |
|---|---|---|
| Scenario input type | `String` only | `String` or `ContextRecord::Record` |
| Transcript serialization | `Transcript#to_a` (plain hashes) | `Transcript#to_context_records` (JSON-LD `Record[]`) |
| `EvalResult` serialization | `EvalResult#to_h` (plain hash) | `EvalResult#to_context_record` (typed `Record`) |
| `RunResult` serialization | `RunResult#to_h` (plain hash) | `RunResult#to_context_record` (typed `Record` with `result_ids`) |
| Deterministic storage | No | Yes — byte-identical JSON-LD output for identical inputs |

---

## Passing a Record as scenario input

The simplest case is a plain String — nothing changes:

```ruby
suite = RubyLLM::Eval.define("math") do
  scenario "addition" do
    input "What is 2 + 2?"
    grader :response_includes, pattern: "4"
  end
end
```

To carry structured metadata alongside the prompt, wrap it in a `Record`:

```ruby
record = ContextRecord::Record.new(
  action:  :execute,
  target:  "scenario/math/addition",
  payload: {
    "text" => ContextRecord::ContextPrimitive.new(
      type:  "vv:Literal",
      value: "What is 2 + 2?"
    )
  },
  metadata: { "source" => "dataset-v3", "difficulty" => "easy" }
)

suite = RubyLLM::Eval.define("math") do
  scenario "addition" do
    input record
    grader :response_includes, pattern: "4"
  end
end
```

`Runner` automatically extracts the string from `payload["text"]` before calling the agent or block. The agent always receives a plain `String` — no changes needed in agent code.

### Extraction rules

`ScenarioInputHelper.extract_string` resolves the input in this order:

1. `String` — returned as-is.
2. `Record` with `payload["text"]` or `payload[:text]` as a `ContextPrimitive` — returns `primitive.value`.
3. `Record` with `payload["text"]` as a plain value — returns `value.to_s`.
4. `Record` with no `text` key — returns `record.to_json`.

---

## Serializing a transcript to JSON-LD

After a trial runs, the `Transcript` holds every turn of the conversation. `to_context_records` converts it to an array of `Record` objects, one per entry:

```ruby
records = transcript.to_context_records

records.each do |r|
  puts "#{r.action} #{r.target}"
  # => execute  transcript/user
  # => create   transcript/assistant
end
```

Role → action/target mapping:

| Role | `action` | `target` |
|------|----------|----------|
| `:user` | `:execute` | `"transcript/user"` |
| `:assistant` | `:create` | `"transcript/assistant"` |
| `:tool` | `:read` | `"transcript/tool"` |

Each `Record`'s payload contains `"content"` and (if present) `"tool_calls"` as `ContextPrimitive(vv:Literal)` and `ContextPrimitive(vv:Action)` respectively. Token counts are stored in metadata as `ContextPrimitive(vv:Literal)`.

---

## Serializing eval results to JSON-LD

### EvalResult

```ruby
result = RubyLLM::Eval::EvalResult.new(
  scenario_name: "addition",
  suite_name:    "math",
  trial_results: [...]
)

record = result.to_context_record

record.action   # => :evaluate
record.target   # => "eval_result/math/addition"
record.payload  # => {
                #      "status"          => ContextPrimitive(vv:EvalResult, "pass"),
                #      "trial_count"     => ContextPrimitive(vv:EvalResult, 3),
                #      "pass_count"      => ContextPrimitive(vv:EvalResult, 3),
                #      "fail_count"      => ContextPrimitive(vv:EvalResult, 0),
                #      "pass_rate"       => ContextPrimitive(vv:EvalResult, 1.0),
                #      "avg_duration_ms" => ContextPrimitive(vv:EvalResult, 142.3)
                #    }
```

### RunResult

```ruby
run = runner.run(suite)
record = run.to_context_record

record.action              # => :evaluate
record.target              # => "run_result/math"
record.payload             # => { "suite_name", "scenario_count", "trial_count", "pass_rate" }
record.metadata["result_ids"]  # => ["uuid-1", "uuid-2", ...]  — one per EvalResult
```

`result_ids` are the UUIDs of each scenario's `EvalResult#to_context_record` — linking the summary record to its children without embedding them inline.

---

## Storing and comparing results

Because `Record#to_json` is deterministic (sorted keys, typed values), identical eval configurations produce byte-identical JSON-LD output. This makes results suitable for content-addressed storage or diff-based regression checks:

```ruby
require "digest"

result = runner.run(suite)
record = result.to_context_record

# Fingerprint everything except the non-deterministic fields (id, timestamp)
stable = record.to_json_ld.reject { |k, _| %w[id timestamp].include?(k) }
fingerprint = Digest::SHA256.hexdigest(stable.to_json)
```

---

## Type vocabulary

The integration uses two `context-record` vocab terms added in version `0.1.1`:

| Term | Kind | Used for |
|------|------|---------|
| `vv:EvalResult` | `ContextPrimitive` type | All payload fields in `EvalResult` and `RunResult` records |
| `:evaluate` | `Record` action | Both `EvalResult#to_context_record` and `RunResult#to_context_record` |

Existing transcript primitives use the standard vocab: `vv:Literal` for content and token counts, `vv:Action` for tool calls.

---

## Where the code lives

| File | Role |
|------|------|
| `lib/ruby_llm/eval/context_record_integration.rb` | All conversion logic — `ScenarioInputHelper`, `TranscriptMethods`, `EvalResultMethods`, `RunResultMethods` |
| `lib/ruby_llm/eval/runner.rb` | Calls `ScenarioInputHelper.extract_string` in `execute_agent` |
| `lib/ruby_llm/eval/scenario_builder.rb` | Type-guards `input` to `String` or `ContextRecord::Record` in `build` |
| `lib/ruby_llm/eval.rb` | Requires `context_record_integration` after all other eval files |
| `spec/ruby_llm/eval/context_record_integration_spec.rb` | 15 examples covering all four modules |

The integration is loaded automatically when `require "ruby_llm_eval"` is called. No opt-in is needed.
