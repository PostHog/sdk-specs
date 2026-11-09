## Why

The project remote-config response carries a `quotaLimited` field that the remote-config wire table does not list. When a project has exhausted its session replay quota, the server adds `quotaLimited: ["recordings"]` to the config response and sets `sessionRecording` to `false` in the same response (`posthog/models/remote_config.py:312-324` at PostHog/posthog `f18803ea`). The same field on the flags response reports `feature_flags` when the flags quota is exhausted (`rust/feature-flags/src/handler/billing.rs:25-32`), and the evaluate-flags spec already speaks of a "feature-flag quota limited" response.

sdk-specs#86 proposed this row together with a `mobile_recordings` resource. Its backend change (PostHog/posthog#103077) was closed unmerged, so the server never emits that value, and #86 was closed. This change keeps only the part that review on #86 accepted: the wire-table row with the values the server sends today.

## What Changes

- **Remote-config JSON wire representation**: add the `quotaLimited` row to the wire-field table, and one paragraph stating that the field is absent when no quota is exhausted, that the project config response currently lists only `recordings` while also turning `sessionRecording` off, that the flags response carries the same field and can list `feature_flags`, `recordings`, or both, and that SDKs ignore values they do not recognize.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `remote-config`: the **Remote-config JSON wire representation** requirement.

## Impact

- Descriptive only. No SDK behavior changes.
- posthog-js (`eb11f00d`) reads `quotaLimited` from the flags response and checks it for `feature_flags` (`packages/browser-common/src/feature-flags.ts:1175-1185`). Its `RemoteConfig` type (`packages/browser-common/src/types/remote-config.ts:136`) has no `quotaLimited` member, so the browser SDK does not read the field from the project config response. The paragraph therefore describes the server, and does not require SDKs to act on the field.
- `mobile_recordings` is not specified. `QuotaResource` (`ee/billing/quota_limiting.py:79-93`) has no such member.
