## Context

The existing spec covers client-side project configuration but leaves its transport implicit. The Node SDK's explicit per-flag `getRemoteConfigPayload` API is unrelated. Browser SDKs can use preloaded configuration or a script instead of requesting JSON.

Implementation evidence inspected locally (HEAD identifiers; working copies may differ):

- posthog-js `3e72e7bb7`: `packages/core/src/posthog-core-stateless.ts#getRemoteConfig`, `packages/core/src/types.ts#PostHogRemoteConfig`, `packages/browser/src/remote-config.ts`, and `packages/node/src/client.ts#_requestRemoteConfigPayload`.
- posthog-android `05bf361a`: `posthog/src/main/java/com/posthog/internal/PostHogApi.kt#remoteConfig`.
- posthog-ios `143d8337e`: `PostHog/PostHogApi.swift#getRemoteConfigRequest`.
- posthog backend `fbc9fc94a9e`: `posthog/models/remote_config.py` generates real camelCase config fields and invalidates both `/config` and `/config.js` CDN resources.

## Goals / Non-Goals

**Goals:** Make the JSON route, method, project-token use, regional routing, response shape, and client-only scope explicit and testable.

**Non-Goals:** Require server SDK bootstrap requests; specify per-flag encrypted payload retrieval; replace product schemas; standardize retries, timeout durations, HTTP-cache policies, or every optional response field.

## Decisions

- Add requirements to the existing remote-config capability rather than a new HTTP capability. This is an endpoint-specific contract, not shared transport policy.
- Use bodyless GET with the public project token in the path, without requiring personal/secret credentials. Do not prohibit caller-supplied proxy authentication headers.
- Specify US/EU ingestion-to-asset host mapping and preserve custom hosts, including path prefixes. Legacy host aliases remain governed by each SDK's existing host normalization.
- Describe representative optional response fields, referencing feature-specific specs for nested configuration. The existing acceptance aliases such as `session_replay_enabled` are not actual wire keys.
- Keep browser preloaded and script delivery valid. A universal requirement to issue JSON at startup would contradict the browser implementation.
- Do not prescribe a universal retry count or mandatory request Content-Type: core uses zero retries and a JSON header, whereas iOS constructs a GET without requiring that header.

## Risks / Trade-offs

- A full response-schema snapshot would become stale → document the envelope and common fields, allow unknown fields, and defer product detail to existing specs.
- Host rules could bypass reverse proxies → preserve nonstandard hosts and configured base paths.
- Calling both APIs “remote config” could imply Node support → explicitly exclude the server-side per-flag API from this client contract.

## Migration Plan

Review the proposal, add matching Gherkin scenarios, validate, and archive on this branch to sync the canonical spec. No runtime rollout is required. Revert the documentation change if needed.

## Open Questions

None blocking the bounded HTTP contract. Exhaustive schema versioning and cross-SDK cache/retry harmonization remain separate work.
