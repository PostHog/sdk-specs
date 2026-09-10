## Why

The `traces` spec preceded its first implementation. That implementation has now shipped —
[PostHog/posthog-js#4579](https://github.com/PostHog/posthog-js/pull/4579), `posthog-node` — after
review against W3C Trace Context, OTLP and OpenTelemetry JS, and it had to decide things the spec
leaves open. Other ports will meet the same questions, so the answers belong in the contract.
Each item below is either behavior that shipped and was verified by running it, or an error in the
spec that production contradicts.

**The spec states the wrong body limit.** `traces` and `logs` both say the ingestion body cap is
2 MB. That is only the service default (`MAX_REQUEST_BODY_SIZE_BYTES`, 2 MiB); PostHog's hosted
ingestion runs 10 MiB. Verified on 2026-09-10 against `/i/v1/traces` and `/i/v1/logs`, in both US
and EU: 9.9 MiB accepted, 10.1 MiB refused with `413`. An SDK that measures bodies before sending
(which the spec permits) and takes the spec's 2 MB at its word refuses bodies production accepts,
and drops them with no `413` to show for it.

**Several validity rules are unstated, and one gap costs a whole batch.**

- An unpaired UTF-16 surrogate in any string makes the service reject the entire request —
  verified: `Failed to decode JSON: unexpected end of hex escape`. The client-side validity
  requirement covers ids, names and timestamps, not string well-formedness.
- The spec says an invalid `traceparent` is ignored, but not what invalid means. Uppercase hex,
  version `ff`, and version `00` with trailing fields are all invalid under W3C; accepting them
  continues a trace a conformant peer restarts, splitting it across services.
- `tracestate` has a member limit (32, a grammar rule) and a propagation length (512, a size
  guideline to trim to, not a validity ceiling). Treating the length as validity discards state a
  peer expects forwarded.
- Empty attribute keys are stored verbatim as nameless attributes.
- OpenTelemetry caps attributes per event (default 128); the spec caps only attributes and events
  per span, so one event can carry an unbounded bag.

**`service.name` can be crowded out.** A `resourceAttributes` value large enough to exhaust the
encoder's traversal budget cost the resource its `service.name`, leaving records unattributed.

**Two runtime shapes are missing.** A serverless host holds an invocation open only for work
registered with its keep-alive (`waitUntil`); a handler that records spans but captures no events
registered nothing, and its spans were lost with the invocation. And edge runtimes lack an
async-context primitive, so spans there nest across an `await` only with an explicit `parent` —
the same limitation the spec already allows the browser.

**Child spans can land outside their parent.** Each span anchoring to its own millisecond
wall-clock reading lets a child start before or end after its parent by up to a millisecond, and
by more across a wall-clock step. Observed in production: a child ended 0.6 ms after its parent
root. OpenTelemetry JS (sdk-trace-base 1.30.1, sdk-trace 2.11) behaves the same way, so this is
an improvement on the reference rather than parity.

## What Changes

- **Body limit corrected** in `traces` and `logs`: deployment configuration, 2 MiB by default and
  10 MiB on PostHog's hosted ingestion. An SDK that measures bodies measures against the largest
  known deployment limit, not the default; batch-size defaults stay sized for the default.
- **String well-formedness** added to client-side validity: unpaired surrogates become U+FFFD in
  every wire string.
- **`traceparent` and `tracestate` validity** spelled out per W3C, with `tracestate` trimmed by
  whole members past 512 characters rather than discarded. An SDK MAY accept a single-value
  multi-value header as `parent`.
- **Empty attribute keys** dropped with a debug warning.
- **Per-event attribute cap** of 128, counted in the event's `droppedAttributesCount`; MAY be
  fixed rather than configurable.
- **`service.name` survives an oversized `resourceAttributes` value**, in `traces` and `logs`: the
  SDK-set identity keys encode on their own budget.
- **Serverless keep-alive** becomes a flush trigger: a span ending registers the drain with
  `waitUntil`.
- **Edge runtimes** join the browser as MAY-be-synchronous-only, with documentation required to
  name the explicit `parent`.
- **Shared clock basis** (SHOULD): a span under a local, non-backdated parent takes its start on
  its root's basis — the root's wall-clock start plus monotonic elapsed — so children stay inside
  their parents.

### Not in this change

- **`resourceAttributes` precedence.** The spec says SDK-set `service.*` keys win over
  `resourceAttributes`, and `logs` implements that, but `posthog-js` traces and metrics let
  `resourceAttributes["service.name"]` override `serviceName`. The spec is right and matches
  OpenTelemetry, where `OTEL_SERVICE_NAME` wins over `OTEL_RESOURCE_ATTRIBUTES`; the SDK is what
  changes, so it is left out of this proposal.
- **The retry policy.** Rules the same implementation surfaced about the retry budget and pausing
  automatic sends are in `clarify-otlp-retry-window-and-status-deviation`
  ([#61](https://github.com/PostHog/sdk-specs/pull/61)), which owns that requirement.
- **Empty keys in `logs`.** `posthog-js` drops them for logs too, through the shared encoder; the
  `logs` attribute requirement is left for a logs-focused change.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `traces`: **Active span context and parenting**, **Trace context interop**, **Span data model**,
  **Client-side validity**, **Span limits**, **Attribute value encoding**, **Resource and scope**,
  **Flush triggers**, **Batch assembly and concurrency**, **Server-side contract**.
- `logs`: **Resource and scope**, **Batch assembly and concurrency**, **Server-side contract**.

## Impact

- `openspec/specs/traces/spec.md` and `openspec/specs/logs/spec.md` — source of truth, updated via
  this change's delta on archive.
- `posthog-js` implements everything here as of #4579, except the shared clock basis, which is
  [PostHog/posthog-js#4908](https://github.com/PostHog/posthog-js/pull/4908).
- Other ports inherit these rules when they implement traces. Nothing changes in ingestion.
