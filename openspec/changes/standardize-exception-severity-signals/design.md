## Context

`$exception` carries two independent classification signals:

- event-level `$exception_level`, describing the source severity;
- `$exception_list[].mechanism.handled`, describing whether the exception crossed an uncaught boundary.

The first-party SDK fleet does not produce these consistently. Android, iOS, Flutter, React Native, and Rust provide both on their primary paths. Python, Go, Ruby, PHP, and Elixir omit the level on some or all paths. Go also permits missing handled state. Browser console capture currently marks a deliberate logging call unhandled, while Node does not distinguish a process-fatal exception from a non-fatal unhandled boundary.

Consumers must distinguish an omitted signal from an explicit value because old SDKs, low-level payload builders, and third-party producers legitimately omit metadata.

## Goals / Non-Goals

**Goals:**

- Define trustworthy cross-SDK semantics for exception level and handled state.
- Make manual, unhandled, fatal, and logger-derived capture paths distinguishable.
- Preserve omission as the representation for an unknown signal.
- Give each audited SDK repository a concrete convergence plan.
- Allow SDKs to ship independently without coordinated releases.

**Non-Goals:**

- Require low-level or third-party producers to guess metadata they cannot know.
- Define how downstream products classify or present exceptions from these signals.
- Change exception grouping or include level/handled state in fingerprints.
- Backfill metadata on historical events.
- Standardize stack ordering, mechanism taxonomy, or source context beyond existing contracts.

## Decisions

### 1. Keep level and handled state independent

`$exception_level` expresses severity; `mechanism.handled` expresses capture disposition. SDKs MUST set each independently when known. A fatal level does not imply a serialized handled value, and a missing level does not imply `error`.

The authoritative handled signal remains nested on each `$exception_list` entry. A derived top-level `$exception_handled` property does not replace it because producers and consumers may derive that field at different stages.

Alternative: derive handled state from level. Rejected because handled errors can be severe, and unhandled exceptions can occur at boundaries that do not terminate an application.

### 2. Normalize exception levels to the existing Sentry-compatible vocabulary

SDK-generated `$exception_level` values use `fatal`, `error`, `warning`, `log`, `info`, or `debug`.

Native source levels map as follows:

| Source level | Wire level |
| --- | --- |
| `fatal`, `critical`, `alert`, `emergency` | `fatal` |
| `error` | `error` |
| `warning`, `warn` | `warning` |
| `notice`, `info` | `info` |
| `log` | `log` |
| `trace`, `debug` | `debug` |

This vocabulary already ships in posthog-js and its Sentry integrations. Consumers may continue accepting aliases from legacy and custom producers, but new first-party SDK output converges on one set.

Alternative: reuse the Logs product vocabulary (`trace`, `debug`, `info`, `warn`, `error`, `fatal`). Rejected because `$exception_level` already has a public Sentry-compatible type and changing it would add migration work without improving issue classification.

### 3. Classify at the capture boundary

The boundary that creates the `$exception` event supplies both signals:

| Capture boundary | `$exception_level` | `mechanism.handled` |
| --- | --- | --- |
| Public/manual capture of a caught exception | `error` by default | `true` |
| Logger or console call | normalized source level | `true` |
| Uncaught request, task, thread, promise, or process boundary that may continue | `error` | `false` |
| Crash, panic, or uncaught boundary that is expected to terminate the app/process | `fatal` | `false` |
| Low-level/custom producer without enough context | omitted | omitted when unknown |

An explicit supported level supplied through an SDK's typed exception API overrides the default after normalization. Generic additional properties do not require an SDK to infer handled state.

Alternative: let every SDK choose values from platform conventions. Rejected because consumers would need SDK-specific normalization for the same capture boundary.

### 4. Apply known handled state to the full exception chain

When one capture attempt serializes a cause chain, every generated entry receives the same known handled disposition. The disposition describes the capture boundary, not whether an individual cause was caught earlier. If the boundary is unknown, the SDK omits handled state rather than writing `false`.

Alternative: require handled state only on `$exception_list[0]`. Rejected because complete entries are easier for downstream consumers to interpret and existing chain builders already propagate mechanism metadata.

### 5. Preserve compatibility during SDK convergence

Missing and unknown metadata retain their existing meaning: the producer did not provide a trustworthy signal. Consumers decide how to handle that absence without changing the SDK wire contract. SDKs can therefore converge independently, and old versions remain valid indefinitely.

No semver cutoff is required because the wire changes are additive. Each SDK should include payload-shape tests at its public capture boundary and each automatic integration boundary it owns.

## Risks / Trade-offs

- [Adding signals can change downstream classification] → Keep classification policy outside this contract and preserve omission for unknown values.
- [A logger's `fatal` method may not terminate the process] → Preserve its explicit source severity while keeping `handled: true`; level and disposition remain independent.
- [Framework middleware catches failures to render an error response] → Treat failures uncaught by application code as `handled: false`, even if the framework prevents process termination.
- [Third-party integrations use legacy aliases] → Let consumers remain tolerant while requiring normalized output only from first-party SDK-owned builders.
- [Generic property merging can override reserved keys] → SDK tests assert the final emitted payload at the queue or transport boundary, not only intermediate builder output.

## Migration Plan

1. Archive this change into the canonical `capture-exception` spec and add public acceptance scenarios.
2. Update SDKs with missing or incorrect metadata, starting with Go and Python because their primary paths produce the least reliable signals.
3. Update Node, browser console capture, Ruby, PHP, and Elixir.
4. Add conformance coverage to Android, iOS, Flutter, React Native, and Rust while touching only paths that fail the new scenarios.
5. Monitor emitted signal coverage by `$lib` and `$lib_version` without requiring all historical SDK versions to conform.

Rollback consists of reverting an SDK release. Events from the reverted or older SDK continue to omit signals, so no coordinated consumer rollback or data migration is required.

## Open Questions

None. SDK-specific API spelling and release sequencing remain implementation details as long as the final wire payload satisfies the contract.
