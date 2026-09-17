# Proposal

## Why

`posthog-js` now records outgoing network-request timing through PostHog Metrics, and
the Metrics capability in the parent change needs a requirement for this source. Teams
also need a support record that distinguishes shipped support from a safe future
candidate, without counting Session Replay network recording as Metrics support.

## What Changes

- Add a Network Request Timing requirement to the existing `metrics` capability for
  recording the duration and outcome of outgoing application requests.
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

_None._

### Modified Capabilities

- `metrics`: add optional automatic network-request timing capture as a Metrics source,
  with privacy, cardinality, lifecycle, and failure-isolation requirements.

## Impact

- `openspec/specs/metrics/spec.md` will gain the canonical requirement, based on the
  `posthog-js` implementation and the existing Metrics ingestion contract.
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
