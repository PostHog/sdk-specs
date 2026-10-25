## Context

Capture's AI lane is a separate deployment that serves `POST /i/v1/ai/events` with the same request and response contract as `/i/v1/analytics/events` (`rust/capture/src/v1/analytics/router.rs` `ai_routes` in PostHog/posthog). It accepts larger bodies, applies an 8 MiB ceiling to each event's `properties`, drops a non-`$ai_` event with `misrouted_event`, and shares the AI byte budget and quota with the analytics endpoint. The analytics endpoint still accepts `$ai_*` events and forwards them to the AI topic; PostHog plans to stop that once every shipped SDK has an AI method.

The four server SDKs implement one AI lane on their next-major branches:

- posthog-python `v1`: `capture_ai` and `capture_ai_immediate`; `capture_ai_compression`, `capture_ai_max_queue_size`, `capture_ai_timeout`, `capture_ai_max_event_bytes`
- posthog-go `v1`: `EnqueueAI` / `EnqueueAIWithContext`; `CaptureAICompression`, `CaptureAIMaxQueueSize`, `CaptureAIBatchUploadTimeout`
- posthog-rs `v1`: `capture_ai`, `capture_ai_batch` and their immediate variants; `capture_ai_compression`, `capture_ai_max_queue_size`
- posthog-node capture v1 series: `captureAi` / `captureAiImmediate`; `captureAiCompression`, `captureAiMaxQueueSize`, `captureAiRequestTimeoutMs`

The current spec predates all four: it names only Python and Node, ties wrapper routing to `enable_full_ai_capture`, and lists `/i/v0/ai/batch/` as the transport.

## Goals / Non-Goals

**Goals:**
- State the capture v1 AI lane so the next SDK adds AI capture the same way.
- Fix the wrapper contract: the AI method is the only route for PostHog's wrappers, with no fallback to `capture`.
- Give the harness a `capture_ai_v1` capability and cases.

**Non-Goals:**
- The analytics wire, headers, retries and layer order, which `add-capture-v1` covers and this change references.
- The OpenTelemetry AI bridge requirement, unchanged.
- Client-SDK AI capture (posthog-ios 4.0 adds `captureAi` in review; not covered here).

## Decisions

**The AI method is the only route for wrappers, whatever the flag says.** On legacy capture the wrappers sent through `capture` unless `enable_full_ai_capture` was set, and the spec made that the contract. The SDK owners reversed it during the ports: an AI event can be megabytes, and the analytics endpoint will stop accepting `$ai_*` events once every SDK has an AI method, so a wrapper that still falls back to `capture` would start losing events on that day. The flag now governs truncation and media redaction only. Alternative rejected: keep the fallback for a client object that lacks the AI method. Only a user's stand-in or mock can lack it on a v1 client, and the fallback would route those events to the lane that is going away; the wrapper logs one error at construction and turns its own capture off instead.

**Lane configuration is required; the per-event cap stays optional and lower-only.** Compression, queue capacity and request timeout are public on all four SDKs with the same defaults (none, 1000, 30 s), so they are a SHALL. Only Python exposes the per-event cap, and only to lower it, so that stays a MAY. Draft #118 also required rejecting invalid values at construction; posthog-go substitutes the default for a non-positive AI queue size, so this change asks for validation of the effective values and leaves the failure mode to the SDK.

**Node's gzip default is recorded, not overruled.** posthog-node 5.x gzips every request by default and the series keeps that for both lanes; the other three default to no compression. The requirement states the default as the SDK's choice and names both.

**Size is measured where the server measures it, or with headroom.** Capture measures `properties` only. posthog-rs and posthog-node measure `properties` exactly; posthog-python and posthog-go measure the whole event and add 64 KiB of headroom. The requirement fixes the observable rule (never refuse an event capture accepts; never send one it refuses) and allows either mechanism.

**The harness feature mirrors the v0 one.** `capture-ai-v1.feature` reuses the registered step phrases of `capture-ai.feature` with the v1 path, so no new bindings are needed. It is selected by `@requires:capture_ai_v1`; the v0 feature keeps `capture_ai_v0`.

## Risks / Trade-offs

- [The analytics endpoint's acceptance of `$ai_*` events ends on a date PostHog has not set] → the requirement says "temporary" and that SDKs never rely on it, as the public docs do.
- [The posthog-node series is unmerged] → every rule here is also in Python, Go or Rust; Node appears only in option names and the compression variation.
- [Draft #118 and this change both touch the Configuration section] → #118 is superseded; its author is the PostHog bot, so closing it is a maintainer call.

## Migration Plan

Spec-only. Archive on this branch after review. SDK adapters declare `capture_ai_v1` when they move to the v1 AI endpoint.

## Open Questions

- Whether capture v1 SDKs should retry `404` on the AI endpoint (a deployment without the AI lane) is under review on the PostHog side; today it is terminal, like analytics.
