## Why

The `capture-ai` spec still describes the AI route as a Python and Node beta on `/i/v0/ai/batch/`, with routing of PostHog's own AI wrappers tied to the `enable_full_ai_capture` flag. Four server SDKs now ship AI capture on capture v1 (`/i/v1/ai/events`) in their next majors, posthog-go and posthog-rs among them, and the wrappers always use the AI method. The harness has no `capture_ai_v1` capability, so the AI parity cases cannot select a capture v1 SDK at all.

## What Changes

- Extend applicability to posthog-go v2 (`EnqueueAI`) and posthog-rs 1.0 (`capture_ai`), next to posthog-python 8.0 and posthog-node 6.0.
- Add the capture v1 AI lane: `POST /i/v1/ai/events`, the same body, headers and per-event results as analytics capture, `misrouted_event` for a non-AI event on that endpoint, and the analytics endpoint's temporary acceptance of `$ai_*` events.
- **BREAKING** for the wrapper contract: PostHog's AI wrapper libraries always send through the SDK's AI method; `enable_full_ai_capture` controls only truncation and media redaction. A wrapper given a client without the AI method turns its own capture off instead of falling back to `capture`.
- Add the AI lane's configuration surface (compression, queue capacity, request timeout, an optional lower-only per-event cap) with its defaults and the rule that analytics settings never reach the AI lane. This supersedes draft #118.
- Add the AI size rules: an 8 MiB ceiling on `properties`, a 5 MiB request target, size-aware batching that keeps order, and the oversize log line that names only the event and its size.
- Replace the transport section's v0 values with capture v1.
- Add `migration/yaml-parity-v1/capture-ai-v1.feature` under a new `capture_ai_v1` capability, mirroring the v0 cases on the v1 endpoint, and document the capability in the suite README.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture-ai`: capture v1 AI lane, wrapper routing, lane configuration, size rules, extended applicability.

## Impact

- posthog-python `v1`, posthog-go `v1`, posthog-rs `v1` and the posthog-node capture v1 series conform, with one recorded variation: posthog-node 6 defaults the AI lane's compression to gzip, the other three to none.
- Draft #118 covers the lane configuration; this change absorbs it and drops its "rejected at construction" scenario, which posthog-go does not satisfy (a non-positive AI queue size takes the default).
- SDKs without AI capture (Ruby, PHP, .NET, Elixir, Java, the client SDKs) are unaffected until they add it.
- The harness adapters for the four SDKs can declare `capture_ai_v1`; the existing `capture_ai_v0` feature stays for the legacy route.
