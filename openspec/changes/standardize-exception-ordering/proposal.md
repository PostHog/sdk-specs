# Standardize Exception Ordering

## Why

PostHog SDKs disagree on the order of stack frames, chained exceptions, and source-context
lines inside `$exception` payloads, and the `capture-exception` spec currently says nothing
about ordering (its only ordering language covers capture-queue ordering). The ingestion
pipeline (cymbal) preserves incoming order end-to-end and its fingerprint (SHA512) hashes
exceptions and in-app frames in stored order, so today:

- the same logical error groups differently per platform (mixed frame conventions feed the
  fingerprint in opposite orders);
- the no-in-app-frame fingerprint fallback picks `frames.first()`, whose meaning flips per SDK
  (entry point on some platforms, crash site on others);
- the UI renders stored order, so stack traces display in opposite orientations depending on
  which SDK sent the event.

One canonical ordering restores cross-SDK grouping and display parity.

## What Changes

- Amend the `capture-exception` capability with three normative ordering requirements:
  - **Frame order** within `$exception_list[].stacktrace.frames`: bottom-up — `frames[0]` is
    the outermost frame (entry point / oldest call), the last element is the innermost frame
    (crash site). SDKs whose runtime yields innermost-first stacks MUST reverse before sending.
  - **Exception list order**: `$exception_list[0]` is the caught/outermost exception; each
    cause/inner/wrapped exception is appended after in unwrap order; root cause last. SDKs
    without chain support send a single-element list.
  - **Source context line order** (for SDKs that attach it): `context_line` plus `pre_context`
    / `post_context` arrays in file order (ascending line numbers).
- **BREAKING** (wire order) for SDKs that emit crash-first frames today: posthog-android,
  posthog-flutter, posthog-php, posthog-go, posthog-rs, posthog-elixir, and posthog-server
  MUST reverse frames.
- **BREAKING** (wire order) for posthog-python: `$exception_list` is currently root-cause-first
  and must flip to outermost-first.
- The source-context requirement codifies existing behavior — every SDK that sends context
  already sends it in file order — so it introduces no breaking change.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `capture-exception`: adds ordering requirements for `$exception_list`,
  `stacktrace.frames`, and per-frame source context (`context_line`, `pre_context`,
  `post_context`). Existing requirements are unchanged; the ordering concerns are new.

## Impact

Audit basis: SDK implementations and pipeline behavior verified 2026-07-02.

- **Spec artifacts:** `openspec/specs/capture-exception/spec.md` (via this change's delta) and
  `acceptance/public/capture-exception.feature` (new ordering scenarios).
- **Frame order on the wire today:**
  - Already bottom-up (compliant): posthog-js browser (`$lib` `web`), posthog-node,
    posthog-react-native, posthog-python, posthog-ruby, posthog-ios, posthog-dotnet.
  - Crash-first (need reversal): posthog-android (`ThrowableCoercer.kt`), posthog-flutter
    (`dart_exception_processor.dart`), posthog-php (`ExceptionPayloadBuilder.php` `getTrace`),
    posthog-go (`error_tracking_stack_trace.go`), posthog-rs (`error_tracking.rs` — has a test
    asserting crash-first that must be updated), posthog-elixir (`handler.ex`
    `do_stacktrace`), posthog-server (java successor; shares `ThrowableCoercer.kt` with
    posthog-android, so one code change covers both `$lib`s).
  - posthog-java is tombstoned; posthog-server (a module in the posthog-android repo) replaces
    it and is audited above.
- **Exception list order today:**
  - `[0]` = outermost (compliant): js-family, posthog-php, posthog-rs (with
    `exception_id`/`parent_id` chain links), posthog-dotnet, posthog-android, posthog-ios,
    posthog-elixir, posthog-server.
  - `[0]` = root cause (non-compliant, must flip): posthog-python (`exception_utils.py:719`
    reverses).
  - Single-element only: posthog-ruby, posthog-go, posthog-flutter.
- **Source context today:** posthog-php, posthog-python, posthog-node, posthog-ruby,
  posthog-dotnet, and posthog-elixir all already send file-order pre/post context (5 lines;
  node 7). posthog-rs, posthog-go, posthog-android, posthog-ios, posthog-flutter, and
  posthog-server send none.
- **Backend:** cymbal gains semver-gated normalization of legacy payloads plus fingerprint
  aliasing (see appendix and `design.md`).

## Appendix: Rollout & compatibility (non-normative)

This appendix is guidance for the rollout, not part of the spec delta.

- SDKs changing wire order MUST ship the change in a minor release (never a patch), so the
  `$lib_version` reported with each event cleanly separates old-order from new-order payloads.
- The ingestion pipeline (cymbal) will normalize legacy payloads per (`$lib`, `$lib_version`)
  using a semver gate: versions below each SDK's flip release are reordered to the canonical
  convention at ingest, so old clients keep working indefinitely.
- Fingerprints are order-sensitive (exceptions and in-app frames are hashed in stored order),
  so the pipeline pairs the ordering flip with fingerprint aliasing — new-order fingerprints
  are aliased to the pre-flip fingerprints of the same logical error to avoid splitting
  existing issues.
