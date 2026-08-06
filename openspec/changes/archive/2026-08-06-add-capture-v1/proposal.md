## Why

Four PostHog SDKs already implement the **capture v1 transport** — a newer analytics ingestion
path at `POST {host}/i/v1/analytics/events` with Bearer-only auth, a per-event envelope, and a
per-event result protocol that supports partial retry. `posthog-rs` is the reference; `posthog-go`,
`posthog-node`, and `posthog-python` explicitly mirror it, and all four ultimately derive from the
backend Rust type `rust/capture/src/v1/analytics/types.rs` in PostHog/posthog.

The spec repo does not describe any of this. The existing `capture` spec covers only the
generic/legacy `capture()` contract — its purpose statement says events go to "`/batch/` or
`/capture/` depending on transport", and it contains zero mentions of `/i/v1/analytics/events`,
Bearer-only auth, per-event result codes, or partial-retry semantics. An implementer porting the
v1 transport to a fifth SDK has no canonical contract to build against, and the four existing
implementations have no shared spec to conform to.

## What Changes

- **New capability `capture-v1`:** the platform-agnostic contract for the capture v1 transport.
  It covers: the versioned endpoint and Bearer-only authentication; the batch envelope
  (`created_at`, optional `historical_migration`, `batch`); the per-event wire shape (`event`,
  `uuid`, `distinct_id`, `timestamp`, optional `session_id`/`window_id`, always-present `options`,
  `properties`); options **sentinel-lifting** with typed coercion; the per-event result protocol
  (`ok`/`warning` terminal-success, `drop` terminal-failure, `retry` resend); **partial retry**
  that resends only the `retry`-tagged uuids while preserving early terminal outcomes; retry
  classification where **`429` is terminal** (deliberately unlike v0) with `Retry-After` honored as
  a minimum clamped to a 30s max backoff; the request headers (`PostHog-Sdk-Info`, `PostHog-Attempt`,
  `PostHog-Request-Id`, `PostHog-Request-Timestamp`); per-codec compression; the attempt budget; and
  the LLM-analytics (`$ai_*`) legacy-transport carve-out.
- Capture v1 is modeled as a **transport** downstream of event production — event enrichment and
  `before_send` are unchanged and remain governed by the `capture` spec. This change does not touch
  the `capture` spec.
- **Not in scope:** the public `capture` API surface, event enrichment, batching/queueing policy
  (queue size, flush interval — governed by `event-batcher`/`capture`), and the legacy v0 wire
  format. This change specifies only how an already-assembled batch is serialized, sent, and
  reconciled with the server response over v1.

## Capabilities

### New Capabilities

- `capture-v1`: the versioned analytics ingestion transport (`/i/v1/analytics/events`), Bearer
  auth, per-event result protocol, and partial retry.

### Modified Capabilities

_None. The generic/legacy `capture` contract is left untouched so it stays readable; capture v1 is
a new sibling capability, per the repo's one-capability-per-folder rule._

## Impact

- `openspec/specs/capture-v1/spec.md` — created on archive from this change's delta.
- `openspec/project.md` — Capabilities prose gains a line for the capture v1 transport.
- `README.md` — Capabilities table gains a Capture V1 row.
- The four shipped implementations (`posthog-rs`, `posthog-go`, `posthog-node`, `posthog-python`)
  are the source of truth; no SDK change is required by this spec. The cross-SDK conformance
  harness already exercises a `capture_v1` suite (posthog-rs `compliance/v1/`, posthog-go
  `sdk_compliance_adapter` capability `"capture_v1"`).
- Two known divergences are surfaced for a human decision rather than papered over (see design.md):
  compression codec breadth, and posthog-node's `$ai_*` legacy-transport routing.
