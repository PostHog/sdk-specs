# Proposal

## Why

`posthog-js` now records outgoing network-request timing through PostHog Metrics, but
sdk-specs has no capability that defines this behaviour or shows its status in the
per-SDK compliance record. Teams therefore cannot distinguish shipped support from a
platform that is a safe future candidate, and can incorrectly count Session Replay
network recording as Metrics support.

## What Changes

- Add a `network-request-metrics` capability for recording the duration and outcome of
  outgoing application requests through the existing SDK Metrics surface.
- Define automatic capture as an optional platform adapter. It applies only where an SDK
  can observe the host request API without changing request behaviour; a manual adapter
  remains a valid implementation path.
- Define privacy, cardinality, lifecycle, and failure behaviour so request metadata is
  useful for performance analysis without collecting request bodies, headers, query
  values, user identifiers, or other sensitive values.
- Add a per-SDK support classification during implementation. It will keep **shipped and
  verified**, **partial/manual**, **candidate**, and **out of scope** separate. Only the
  first two are compliance results.

## Capabilities

### New Capabilities

- `network-request-metrics`: capture safe, bounded timing and outcome metrics for outgoing
  application network requests, with automatic and manual adapter rules.

### Modified Capabilities

_None._

## Impact

- `openspec/specs/network-request-metrics/spec.md` will become the canonical contract,
  based on the `posthog-js` implementation and the existing Metrics ingestion contract.
- `compliance/README.md` and each `compliance/<sdk>.md` will gain one clearly-scoped
  tracking row when the capability is implemented. Candidate status will be kept outside
  the Pass/Partial/Fail/N/A conformance score.
- The first support map will treat browser `posthog-js` as the shipped reference. Mobile
  UI SDKs require an evidence audit: their Session Replay network recording is related but
  is not proof that they emit Metrics. Server SDKs must use a deliberate HTTP-client
  adapter or a manual capture API; this change does not require global interception.
- No application request payload, header, query-string value, full URL, session id, or
  user id may become a metric attribute. The feature must obey existing metrics enablement
  and opt-out controls.
