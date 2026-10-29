## Context

Capture v1 is PostHog's new ingestion API: `POST /i/v1/analytics/events` and `POST /i/v1/ai/events` (`rust/capture/src/v1/` in PostHog/posthog). It authenticates with a bearer token, requires four `PostHog-*` headers, answers a 2xx with a per-event `results` map, and reads processing settings from a per-event `options` object instead of `$`-prefixed properties. It is live in PostHog Cloud.

Four server SDKs implement it on their next-major branches, with one shared set of rules the SDK owners worked out while porting:

- posthog-python `v1` (8.0): `posthog/capture_send.py`, `capture_event.py`, `client.py`, `consumer.py`
- posthog-go `v1` (v2, module `/v2`): `capture_event.go`, `capture_send.go`, `capture_lane.go`, `backoff.go`, `request_context.go`
- posthog-rs `v1` (1.0): `src/capture_event.rs`, `src/client/capture.rs`, `transport.rs`, `retry.rs`, `on_error.rs`
- posthog-node 6 (posthog-js PR series on `capture-v1`): `packages/node/src/capture-v1/*`, `capture-lane/*`, `client.ts`

The canonical specs predate the port. `capture` still says server SDKs stamp `$lib` and apply global defaults after the caller's properties; `retry-queue` lists 429 as retryable and 413 as a reason to shrink batches; `http-client` describes `/batch` with the token in the body.

## Goals / Non-Goals

**Goals:**
- Record the capture v1 contract every server SDK must satisfy, so the next port (Ruby, PHP, .NET, Elixir, Java, and the client SDKs later) copies one contract.
- Keep the legacy SDKs conformant with the rules that still apply to them: every new requirement is scoped to "an SDK that delivers through capture v1", and legacy behavior is noted as superseded rather than deleted.
- Give the existing `capture_v1` harness cases a canonical home.

**Non-Goals:**
- The AI lane (`capture_ai`, `/i/v1/ai/events`, lane configuration). That is the `add-capture-ai-v1` change.
- Client-SDK specific scenarios. Client SDKs that deliver through capture v1 (posthog-ios 4.0, posthog-android 4.0 and the posthog-flutter 6.0 Windows and Linux lane) are bound by these wire rules, with the client variations the requirements name: a durable disk queue with no attempt limit, 413 batch halving, request identity that resets when a resend's events change or the app restarts, a wrapper's own SDK name, and no global options. No scenario is tagged `@client` yet.
- New harness scenarios. The scenarios below use the existing step vocabulary where one exists but are not opted in with `@sdk:server`; opting in needs an end-to-end run against a real adapter.
- Deleting the legacy `/batch/` narrative or the `capture_v0*` harness features.

## Decisions

**One canonical target, no parallel legacy spec.** `openspec/project.md` says a spec names the winner where SDKs diverge. A released old major is not a divergence to keep converging on. The precedent is the GeoIP-default requirement ("each SDK makes it, if at all, in its next major release") and the canonical-uuid change ("SDKs still on the legacy `/batch/` wire are unaffected… they conform once they normalize"). So the new requirements say what a capture v1 SDK does; a one-line "Legacy capture:" note records what changed. Alternative rejected: a separate `capture-v1` capability folder. It would split one method's contract across two specs and leave `capture` describing a wire PostHog plans to retire.

**Scope by delivery wire, not by SDK name.** Requirements open with "An SDK that delivers events through capture v1 SHALL…". The harness already selects by the adapter's `capture_v1` / `capture_v0` capability, so a legacy SDK is neither selected nor failed. Per-SDK option names appear only as examples.

**Record variations the SDK owners accepted instead of picking a new winner.** Where the four implementations differ on purpose, the requirement names the allowed variation:
- Non-finite numbers: every server SDK sends `NaN` and `±Infinity` as JSON `null` and keeps the event, as #140 proposes. Rust and Node get `null` from their encoders; Python and Go v2 encode each event strictly first and rewrite non-finite numbers only for an event whose encoding fails (posthog-python #1125, posthog-go #394), so events without one cost nothing extra. iOS and Android drop the non-finite property and keep the event.
- Compression default: Python, Go and Rust default to none; Node keeps gzip. #81 says gzip by default; it was written for client SDKs and needs a scope note or an exception.
- A missing distinct id: Python, Rust and Node generate a personless id; Go without a request context returns an error. Both are long-standing and kept.
- Timestamp digits: any count at or above milliseconds.
- Hoisting the legacy option properties and the AI per-event measurement are mechanisms the SDK chooses; the observable result is fixed.

**Flag properties are folded into the layer-order requirement.** #145 proposes the same rule (flag properties fill under the call, the context and the global defaults, before `before_send`). This change states the whole order once and cites #145; if #145 merges first, the archive step reconciles the two requirements into one.

**Scenarios stay black-box.** Every scenario asserts received traffic or a public return value: endpoint paths, headers across attempts, the serialized event, the error handler's input. Nothing inspects a private queue.

## Risks / Trade-offs

- [Legacy SDKs read as non-conformant on new rows of `compliance/<sdk>.md`] → the rows are scoped to capture v1, so an audit records "not yet on capture v1" rather than a defect. Their next-major port closes the rows.
- [The posthog-node series is unmerged and can still change] → requirements cite only behavior that is also in Python, Go or Rust; Node-only details are limited to option names in examples. Re-check at the Node 6 release.
- [Open spec PRs #140, #81, #145 overlap] → named in the proposal's Impact; each needs a decision before this change merges.
- [404 and 429 were terminal in the first draft] → decided 2026-10-27: both are retried like `408` and the `5xx` statuses, so a transient status does not drop data. The requirement and both scenario tables carry the decided rule.

## Migration Plan

Spec-only. The four SDK branches already implement these rules; their migration guides carry the user-facing changes. Archive on this branch after review.

## Open Questions

- #140: resolved, `null` everywhere. Go v2 moved to `null` with a strict-encode-first fallback (posthog-go #394), which avoids the per-event cost of the sanitizing pass.
- #81: scope the gzip-by-default requirement to client SDKs, or record the v1 server default of no compression as an exception?
