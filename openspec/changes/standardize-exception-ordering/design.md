# Design: Standardize Exception Ordering

## Context

`$exception` payloads carry `$exception_list[]`, each with a `stacktrace.frames[]` array and,
on some SDKs, per-frame source context. Nothing in `openspec/specs/capture-exception/spec.md`
constrains the order of any of these today, and shipped SDKs diverge (audited 2026-07-02):

| SDK | Frame order | Exception list `[0]` | Source context |
|---|---|---|---|
| posthog-js browser (`web`) | bottom-up | outermost | none (server-side via source maps) |
| posthog-node | bottom-up | outermost | file-order, 7 lines |
| posthog-react-native | bottom-up | outermost | none |
| posthog-python | bottom-up | **root cause** (`exception_utils.py:719` reverses) | file-order, 5 lines |
| posthog-ruby | bottom-up | single-only | file-order, 5 lines |
| posthog-ios | bottom-up | outermost | none |
| posthog-dotnet | bottom-up | outermost | file-order, 5 lines |
| posthog-android | **crash-first** (`ThrowableCoercer.kt`) | outermost | none |
| posthog-flutter | **crash-first** (`dart_exception_processor.dart`) | single-only | none |
| posthog-php | **crash-first** (`ExceptionPayloadBuilder.php` `getTrace`) | outermost | file-order, 5 lines |
| posthog-go | **crash-first** (`error_tracking_stack_trace.go`) | single-only | none |
| posthog-rs | **crash-first** (`error_tracking.rs`, test asserts it) | outermost (`exception_id`/`parent_id` links) | none |
| posthog-elixir | no error tracking | — | — |
| posthog-java | tombstoned; successor posthog-server unaudited | — | — |

Consumer behavior (cymbal, the error-tracking ingestion pipeline):

- Incoming order is preserved end-to-end into storage and the UI.
- The fingerprint (SHA512) hashes exceptions and in-app frames in stored order, so mixed
  conventions make the same logical error group differently per platform.
- The no-in-app-frame fallback fingerprints `frames.first()`, whose meaning flips per SDK.
- The UI renders stored order, so stacks display in opposite orientations per SDK.

## Goals / Non-Goals

**Goals:**

- One canonical, normative ordering for frames, the exception list, and source-context lines.
- Codify the source-context field shape (`context_line`, `pre_context`, `post_context`) that
  every context-sending SDK already uses.
- A rollout that never splits existing error groups and never breaks old clients.

**Non-Goals:**

- Requiring SDKs to capture source context or exception chains they do not have today
  (single-element lists and context-less frames remain valid).
- Changing the fingerprint algorithm itself.
- Specifying error tracking for posthog-elixir or posthog-server (unaudited successor to the
  tombstoned posthog-java).

## Decisions

1. **Frames bottom-up (`frames[0]` = entry point, last = crash site).**
   Rationale: matches the majority of current PostHog event volume (the js-family alone
   dominates, and python/ruby/ios/dotnet also comply); cymbal's fingerprinting and
   inline-frame expansion already assume it; it is also the prevailing wire convention in the
   wider error-tracking ecosystem, which eases migrations. Alternative — crash-first (the raw
   order on JVM/Dart/PHP/Go/Rust runtimes) — rejected: it would flip the high-volume SDKs for
   no consumer benefit.

2. **Exception list outermost-first, root cause last.**
   Rationale: six audited SDKs already do this and only posthog-python deviates; it mirrors
   the frame decision (the wrapper you caught is the outermost thing, unwrap toward the
   cause); rust's `exception_id`/`parent_id` chain links already encode wrapper→cause in this
   direction. Alternative — root-cause-first — rejected: one SDK versus six, and it reads
   backwards next to bottom-up frames.

3. **Source context in file order, `pre_context`/`post_context` as string arrays around
   `context_line`.**
   Rationale: this codifies what all five context-sending SDKs (php, python, node, ruby,
   dotnet) already emit — no wire change anywhere. Window: 5 lines each side RECOMMENDED
   (node's 7 stays valid), receivers MAY truncate, pipeline caps at 10 per side. Context stays
   OPTIONAL per frame so SDKs without file access (mobile, minified web) remain compliant.

4. **Rollout via minor releases + semver-gated normalization + fingerprint aliasing.**
   See Migration Plan. Alternative — flip SDKs with no pipeline support — rejected: fingerprints
   are order-sensitive, so an unaccompanied flip would split every existing issue on the five
   crash-first SDKs plus python.

## Risks / Trade-offs

- [Fingerprint churn when an SDK flips order] → cymbal pairs the flip with fingerprint
  aliasing so new-order fingerprints map to the same issues.
- [Old SDK versions emit legacy order indefinitely] → cymbal normalizes per
  (`$lib`, `$lib_version`) semver gate at ingest; the gate is permanent, not a transition
  window.
- [posthog-rs has a test asserting crash-first order] → that test must be inverted in the same
  PR as the reversal; the delta scenario "Crash-first runtime stacks are reversed before
  sending" is the replacement contract.
- [posthog-server (java successor) is unaudited] → audit before porting this capability; the
  semver gate design accommodates whatever it currently sends.
- [SDKs that reverse at capture time pay a small allocation cost] → negligible relative to
  exception coercion and network cost.

## Migration Plan

1. Land this spec change (archive syncs the delta into `specs/capture-exception/spec.md`).
2. cymbal: add per-(`$lib`, `$lib_version`) semver-gated normalization that reorders legacy
   payloads to the canonical convention at ingest, plus fingerprint aliasing keyed on the flip
   release of each SDK.
3. SDKs ship the wire-order change in a **minor** release (never a patch) so `$lib_version`
   cleanly separates old-order from new-order payloads: frame reversal in posthog-android,
   posthog-flutter, posthog-php, posthog-go, posthog-rs; exception-list flip in
   posthog-python.
4. Update `acceptance/public/capture-exception.feature` with the ordering scenarios; SDK
   acceptance harnesses adopt them with their flip release.

Rollback: revert the SDK release; the semver gate makes older versions valid forever, so
rollback needs no pipeline change.

## Open Questions

- Should single-list SDKs (posthog-ruby, posthog-go, posthog-flutter) adopt chain unwrapping
  where the platform supports it (e.g. Go's `errors.Unwrap`)? Out of scope here; the spec
  already permits single-element lists.
- posthog-server (java successor) needs an audit before this capability is ported to it.
