# Design

## Context

See `proposal.md` for motivation. `sdk-specs` has no Metrics capability, while its
compliance matrix only reports conformance against existing canonical specs. Session
Replay already captures network data on some platforms, but its output does not prove
that an SDK emits PostHog Metrics.

## Goals / Non-Goals

**Goals:**

- Define one small, testable contract for application network-request timing metrics.
- Make the first `posthog-js` implementation the reference for metric identity and
  enabled-state behaviour.
- Give maintainers one support record that separates verified support from possible
  future ports without changing compliance scores early.
- Preserve user privacy and predictable metric cardinality.

**Non-Goals:**

- Specify a general Metrics SDK API, ingestion protocol, dashboards, or tracing.
- Require global HTTP interception, automatic support on all SDKs, or ports in this change.
- Reuse or expose Session Replay request payload data.
- Record inbound server-request timing, request content, or personal identifiers.

## Decisions

### One capability, separate from Session Replay and tracing

`network-request-metrics` describes an observable product outcome: outbound application
request timing becomes Metrics data. It is separate from Session Replay because the
capture, privacy expectations, and query surface differ, and separate from tracing
because it does not create a span graph. Extending either existing spec would make
their contracts unclear.

### Automatic capture is conditional; manual capture remains valid

An automatic adapter is allowed only for a platform's documented, stable request API.
This avoids monkey-patching or changing request semantics merely to obtain parity.
Platforms without such an API can implement a manual adapter later. The alternative,
requiring automatic interception everywhere, would turn platform constraints into false
compliance failures.

### Use a dedicated support record before the normal compliance matrix

During apply, add `compliance/network-request-metrics.md` and link it from
`compliance/README.md`. It will use four states:

| State | Meaning | Compliance effect |
| --- | --- | --- |
| Shipped and verified | Source, version, tests, and Metrics output checked | Ready for a normal compliance row |
| Partial or manual | Some valid capture path exists but misses automatic or contract behaviour | Ready for a normal compliance row |
| Candidate | A host API may support a safe adapter; no Metrics implementation is verified | No score change |
| Out of scope | No safe host API or product reason to add it | No score change |

The initial map marks browser `posthog-js` as shipped and verified. It marks iOS,
Android, React Native, Flutter, Unity, and server SDKs as candidates until their source
and output are audited. Session Replay support is linked as discovery evidence only.

### Preserve the `posthog-js` metrics vocabulary

The implementation task must first record the shipped `posthog-js` metric name, unit,
configuration source, and attribute keys. Other SDKs reuse that vocabulary where their
host API supplies the value; unavailable dimensions are omitted. This avoids a second
metric series per SDK and avoids guessing wire names in this proposal.

## Risks / Trade-offs

- [High-cardinality routes or hosts] → Normalize to a configured route template or bounded host category; never send full URLs or query values.
- [Sensitive network data] → Permit only the listed metadata and exclude bodies, headers, IDs, and query values by contract.
- [Observer changes request behaviour] → Only use a documented hook; test that the application result is unchanged and isolate all observer errors.
- [Replay data is mistaken for Metrics] → Require verified metrics output before assigning shipped status.
- [Metrics volume or browser overhead] → Keep capture disabled unless the existing Metrics/remote configuration enables it; monitor emitted series and client errors during rollout in the owning SDK repository.

## Migration Plan

1. Confirm the current `posthog-js` implementation and add its source, release, test, and
   Metrics-query evidence to the support record.
2. Add the canonical spec and support record, then audit candidates without claiming parity.
3. Add a normal compliance row only after a candidate has evidence for the full contract.
4. Roll back an SDK adapter by disabling its existing network-timing configuration; no stored
   replay data or customer request content requires migration.
