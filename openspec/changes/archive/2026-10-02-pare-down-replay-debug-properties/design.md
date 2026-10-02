## Context

`session-replay-debug-properties` was written against posthog-js attaching its whole debug map to
every captured event bar `$snapshot`. That map had grown to roughly forty keys, and on a
high-volume page the optional ones dominated the payload. posthog-js #5119 proposed throttling
all of them together, which broke the recording controls and the capture diagnostics that read
replay state off an individual `$exception` or custom event. #5144 landed the alternative: keep
the fields those features consume on every eligible event, send ten supporting fields at most
once per thirty seconds, and delete twenty.

## Goals / Non-Goals

**Goals:** Record the required-versus-supporting split as the contract, keep the per-event
guarantees the recording controls depend on, and let the drop counters live where the dropped
data would have been.

**Non-goals:** Requiring any SDK to rate-limit, requiring the drop counters, changing the
`$recording_status` value set, promoting any Tier-2 counter key into scope, or changing mobile
behavior.

## Decisions

- The required set is the state a consumer reads off one event: status, queue depth, replay
  buffer depth, and trigger status, plus the browser's script-loading and URL-trigger keys and
  the rrweb/flush-size keys where an SDK has them. Everything else is supporting.
- Rate limiting is a `MAY`, with the interval and eligible event set implementation-defined.
  Fixing posthog-js's thirty seconds and `$`-prefix rule as the contract would bind mobile SDKs
  to a browser-shaped decision; naming them as the reference keeps the spec checkable without
  that.
- Compute properties, then consume the interval. The alternative — consume on entry to capture —
  makes the event that starts an interval the one event that lacks the keys, and lets a
  `before_send` rejection silence an accepted event.
- A withheld key is explicitly not evidence of SDK state. Without that, the mobile hold-reason
  rule ("absent outside `buffering`") would make rate-limiting unimplementable on mobile.
- `$sdk_debug_current_session_duration` becomes optional rather than forbidden. posthog-js
  removed it, mobile reads it from the session manager and still sends it; forbidding it would
  require a mobile change this drift does not justify.
- The drop counters are permitted on `$snapshot` only, and only when non-zero. They measure loss
  in that payload, and a zero counter on every snapshot is the payload cost the change set out to
  remove.

## Risks / Trade-offs

- Dashboards and saved queries over the removed and throttled keys degrade → the required set is
  chosen to cover what the product itself reads; the rest was diagnostic detail.
- A supporting key sampled once per interval can be read as a per-event fact → stated explicitly
  as "not reported", with the hold-reason rule called out as the case that would otherwise be
  misread.
- Per-SDK-instance scoping means a short session may contribute one sample, or none after its
  first event → accepted, since the required keys still describe every event.

## Migration Plan

Sync and archive on this branch. No SDK has to change: mobile SDKs are already conformant under
the reduced requirement, and posthog-js is conformant once the spec permits the reduction.
