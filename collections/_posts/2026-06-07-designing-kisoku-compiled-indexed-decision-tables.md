---
layout: post
title: "Designing Kisoku: Compiled, Indexed Decision Tables in Java"
date: 2026-06-07 08:00:00 -0500
categories:
- Software Engineering
- Computer Science
tags:
- software
- java
- design
- performance
- compilers
- decision-tables
- computer-science
- AI-assisted
comments: true
toc: true
description: "I built a Java rule engine around one idea: author decision tables in an agent-friendly format, then compile them into a runtime-friendly one. This post walks through the tradeoffs behind every major design decision."
---

I have been building Kisoku, a Java rule engine that evaluates large decision tables. It is anchored to a single idea: decision tables should be authored in a format ~people~ AI agents can read and review, then compiled into a format the runtime can execute efficiently.[^repo]

This post explains those decisions, the tradeoffs behind them, and what is implemented now versus what is still planned. It is a design post in the strict sense: each choice is stated with the constraint that motivated it, and the alternative I rejected.

## The Constraints I Designed For

The whole design is anchored to hard product constraints in the project spec:[^prd]

- Large tables: 5,000,000 rows is the typical case, up to 20,000,000 supported.
- Deterministic behavior under single, bulk, and concurrent evaluation.
- Bounded per-evaluation memory, with JVM heap under 1 GB for typical workloads.
- Explicit lifecycle phases: validate, compile, load, and evaluate.

So the naive approach of "parse the CSV and scan every row on every request" fails the latency, heap, and determinism requirements.

## Decision 1: Lifecycle-First Architecture

Kisoku uses an explicit four-phase lifecycle:

1. Validate source and schema.
2. Compile to a binary artifact.
3. Load the artifact into an immutable runtime form.
4. Evaluate inputs against the loaded state.

Why this decision: it isolates the expensive work (parsing, normalization, indexing) from request-time work. Evaluation never needs source parsing, so runtime behavior becomes predictable and the failure boundaries stay clean — validation returns a structured result, and the compile, load, and eval phases throw their own exceptions.

This shows up in the module boundaries: the validator and compiler sit in one module, the loader and evaluator in another, and both are governed by a split between public API and runtime implementation (Decision 2).

## Decision 2: Stable API, Swappable Runtime

The library is split into `kisoku-api`, holding public contracts and data types, and `kisoku-runtime`, holding the implementation. The runtime is discovered via `ServiceLoader`, which makes this a plugin-style architecture rather than packaging convenience.

The encoders, decoders, and indexes stay out of the public contract. A future runtime could replace the implementation without user code changing, and application code depends only on stable interfaces.

## Decision 3: CSV Is an Authoring Format, Not an Execution Format

Currently Kisoku supports CSV sources; JSON and database sources are declared in the API's source-form enum, but not yet implemented. The CSV format is deliberately opinionated:

- Row 1 is column names.
- Row 2 is operators, fixed per column.
- Data rows contain operands only.

Tables usually also carry the reserved columns `RULE_ID` and `PRIORITY`, which hold rule identity and priority ordering respectively; both have implicit types and need no schema declaration.

- Row 1 is column names.
- Row 2 is operators, fixed per column.
- Data rows contain operands only.

A small example looks like this:

```text
CUSTOMER_ID,AGE,TOTAL_DUE,DECISION
EQ,GTE,LTE,SET
C1,18,5000,APPROVE
```

Columns with a `SET` operator are outputs; everything else is an input condition. A blank cell means "no condition."

The non-engineers can author and review tables directly, the operator row removes ambiguity about what each column means, and it maps cleanly to the columnar encoding in Decision 4. There is no per-cell operator parsing at runtime.

Two details in the parser are worth calling out. Cells like `(A,B,C)` (used for `IN`/`NOT_IN` and `BETWEEN_*`) require a streaming parser that tracks parentheses depth, because values can themselves contain the separator. And operators are normalized from aliases to canonical forms (`>=` becomes `GTE`, `BETWEEN` becomes `BETWEEN_INCLUSIVE`) so authors can write either and the runtime sees one thing.[^csv-adrs]

## Decision 4: Compile to a Columnar Binary Artifact

At runtime, Kisoku evaluates compiled bytes, not CSV text. The artifact has a fixed high-level structure:

- Header (version, artifact kind, offsets, counts).
- String dictionary.
- Column definitions.
- Columnar rule data.
- Rule order index.

Strings are dictionary-encoded to integer IDs, so the same literal that appears in a million rows is stored once. Scalar, range, and set operators use different encoded layouts, and the artifact kind is explicit: `PRODUCTION` or `TEST_INCLUSIVE`.[^artifact]

This decision helps with compact storage, predictable decoding, and better cache locality for column-wise filtering. A single persisted format can be compiled once and loaded repeatedly — this is what later makes `load(Path)` mmap friendly (Decision 8).

## Decision 5: Keep Test Columns in Artifacts, Exclude at Evaluation

`TEST_` columns are retained during compilation for both artifact kinds and marked with a `0x02` flag. The evaluator skips test-only columns in both input matching and output projection.

Why this decision: one source table supports both production behavior and test or diagnostic workflows, so I do not maintain separate rule files. The cost is a little metadata and artifact bytes; the benefit is that a table used for experiments ships unchanged to production when it is ready.

## Decision 6: Indexed Candidate Filtering Over Full Scans

For tables in the millions of rows, evaluating every rule for every request fails the latency goal. Kisoku therefore builds indexes at load time and uses them to filter candidates before verification.

Current index coverage:

- `EQ` via a hash-based bitmap index.
- `GT`, `GTE`, `LT`, `LTE` via sorted-threshold bitmap indexes.
- `IN`, `NOT_IN` via an inverted set-membership index, where `NOT_IN` is served by bitmap complement.

The evaluation algorithm is best described as a pipeline:

1. Start with the "all rows" bitmap.
2. For each indexed input column, fetch the candidate bitmap for the input value.
3. Intersect (`AND`) into the current candidate set.
4. Iterate the survivors in deterministic rule order and run full-match verification.

The "rule order" is priority order: the compiled artifact carries a rule order index built from the priority column, so candidates are verified highest-priority first, deterministically.

Why bitmaps: intersections are fast word-level operations, they compose naturally across columns, and blank or no-condition rows can be represented once and OR-ed back in. The result is a candidate set that is usually a tiny fraction of the table, so the expensive full-match step touches only the few rows that survive.[^indexing]

## Decision 7: Immutability and Isolation Over Stateful Runtime Tricks

The loaded ruleset is immutable shared state. Evaluations build request-local state and never mutate the loaded rule structures.

Why this decision: concurrent evaluation becomes simple and safe, determinism is easy to reason about, and memory behavior is predictable under load. There are no caches-in-place, no counters, nothing that changes based on who evaluated before you.

Bulk evaluation follows the same philosophy. `evaluateBulk(base, variants)` merges the base input with each variant, variant values override the base, and variants are evaluated independently and returned in input order. Everything the runtime does is a pure function of its inputs.

## Decision 8: Load Strategy Is an API Choice

`LoadOptions` makes load behavior explicit at the call site:

- `memoryMap()` (default): a direct `ByteBuffer` path.
- `onHeap()`: a heap-backed `ByteBuffer` path.
- `withPrewarmIndexes(boolean)`: control whether indexes are built at load time. With prewarming disabled, the index list stays null and evaluation falls back to a full deterministic scan.

The default path memory-maps the artifact file directly via `FileChannel.map()`, so the bytes stay off-heap and decoders read column data lazily through the mapped buffer rather than copying sections eagerly.

I made this decision as different workloads want different startup-versus-memory tradeoffs, and those choices belong in user code rather than being hard-coded into the runtime. A single compiled artifact can be written once and loaded identically across processes or pods, which is what makes the compiled format from Decision 4 pay off operationally.[^mmap]

## Decision 9: Two Execution Paths, One Immutable Ruleset

Single-eval and high-volume scoring pull in opposite directions. A REST request wants the lowest possible per-call overhead; scoring millions of inputs from a file or stream wants raw throughput. I did not want one kernel forced to serve both, so Kisoku is moving toward a dual execution model over the same immutable ruleset:

- Single-eval (latency): the existing `evaluate(DecisionInput)` path, unchanged — indexed, immutable, thread-safe, sub-millisecond of compute.
- Vectorized bulk (throughput): a columnar kernel that takes pre-coerced `int` codes (no `Map`, no boxing per input), prunes through the most selective indexed columns into a reusable per-thread candidate bitmap with early exit, then verifies the few survivors in priority order. The "pre-coerced" part matters: dictionary codes are resolved once before the kernel runs, so string inputs never pay a per-evaluation lookup. Parallelism is caller-owned through a supplied `Executor`; the engine never spins up its own pool.

The the row-at-a-time `Map`-based call is structurally too costly for millions of evaluations per second, regardless of threading. Columnar input plus selectivity pruning cut the per-evaluation cost, and parallelism multiplies it. Both paths reuse the same indexes and the same off-heap decoders, so correctness is shared between them.

Current status: the scalar bulk kernel is implemented internally with no public API yet. It is proven by a parity oracle — bulk results must equal single-eval results across operators, priority, indexing on and off, and parallelism. SIMD acceleration of the bitmap `AND` is the planned second step once the scalar kernel is public.[^dual]

## Implemented vs Planned

| Area               | Implemented now                                                              | Planned next                                                |
|--------------------|------------------------------------------------------------------------------|-------------------------------------------------------------|
| Source formats     | CSV validate/compile/load                                                    | JSON and database sources                                   |
| Lifecycle          | Explicit validate/compile/load/evaluate                                      | Diagnostics and tooling around the lifecycle                |
| Runtime indexing   | `EQ`, `GT`, `GTE`, `LT`, `LTE`, `IN`, `NOT_IN` with parity tests             | Index support for `BETWEEN_*`                               |
| Load strategy      | On-heap, direct buffer, and file-backed mmap with lazy section reads         | Further off-heap and streaming refinements                  |
| Execution model    | Indexed single-eval; scalar vectorized bulk kernel (internal), parity-tested | Public bulk API, columnar input/output adapters, SIMD `AND` |
| Test columns       | `TEST_` columns persisted with the `0x02` flag, skipped at evaluation        | Evaluation-time inclusion controls                          |
| Scale verification | Gated scale and memory test suites                                           | Regular benchmark reporting against PRD latency targets     |

## Tradeoffs I Knowingly Accepted

Three compromises stand out, each chosen consciously:

1. **Compilation simplicity over minimum compile-time memory.** The compiler uses a streaming row reader but currently collects data rows in memory before encoding. This keeps the implementation straightforward and deterministic today, at the cost of higher compile-time memory pressure for very large inputs.

2. **Fast progress over full operator-index coverage.** The index layer started with the operators that give immediate runtime wins, then added set membership. Range variants (`BETWEEN_*`) are still pending.

3. **API clarity over hidden defaults.** Compile and load behavior is explicit (`CompileOptions`, `LoadOptions`) rather than implicit global configuration. It is slightly more verbose for users, and easier to reason about in production.

## Closing

When I started, I had planned to not use AI Agents. But AI-agents are here to stay and make my life easier. Without an AI-agent, it will take me weeks and months to reason and implement much of the rule engine. But with AI agents, I can brainstorm and implement (or have AI-agent implement) faster.

As I develop Kisoku further, I plan to write more of my learnings with both Kisoku and using AI Agents. Subscribe to the RSS feed.

---

[^repo]: Kisoku is a Java decision-table rule engine. The repository also holds the design record this post condenses: `docs/PRD.md`, `docs/architecture.md`, `docs/artifact-format.md`, and an ADR series referenced throughout. <code>docs/design-decisions.md</code> is the non-public equivalent of this post.

[^prd]: Kisoku product requirements. The constraints cited here — 5M typical / 20M maximum rows, deterministic evaluation, sub-1 GB heap, and the validate/compile/load/evaluate lifecycle — come from this document.

[^csv-adrs]: The streaming parser and operator normalization decisions are recorded in the repository as ADR-0006 (operator aliasing normalization) and ADR-0007 (streaming CSV parser).

[^artifact]: The full binary artifact format is specified in the repository's artifact format document. The columnar encoding, dictionary compression strategy, and artifact kinds are captured in ADR-0002 and ADR-0008.

[^indexing]: The bitmap-based indexing strategy (ADR-0005) and the set-membership index (ADR-0009) cover the runtime index design. The index-vs-linear parity tests are part of the test suite.

[^mmap]: The memory-mapped, defensively-copied buffer strategy is recorded in ADR-0003.

[^dual]: The dual execution model is ADR-0010 in the repository, currently in proposed status.
