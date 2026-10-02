## Why

[posthog-js #5144](https://github.com/PostHog/posthog-js/pull/5144) pared down the per-event
replay debug payload: it removed `$sdk_debug_current_session_duration` and twenty other debug
keys, limited the remaining supporting keys to one event per thirty seconds per SDK instance,
kept eight required keys on every eligible event, and moved four cumulative drop counters onto
`$snapshot`. The reference implementation now contradicts three statements in the canonical
spec — that the duration key accompanies the session start time, that the supporting keys are
attached to every captured event, and that `$snapshot` carries none of these keys. That PR asks
for this follow-up in its own description.

## What Changes

- Split the key list into a **required** set that every event carrying replay state reports, and
  **supporting** keys an SDK MAY withhold.
- Permit rate-limiting supporting keys to one event per interval per SDK instance, and
  restricting them to an eligible event set. Properties are computed before the interval is
  consumed, and only an accepted capture consumes it, so a `before_send` rejection cannot
  silence the next event.
- State that a withheld supporting key means "not reported", never "no hold" — the mobile
  `$sdk_debug_replay_flush_hold_reason` presence rule constrains only events that carry
  supporting keys.
- Drop `$sdk_debug_current_session_duration` from the required keys. It is the difference
  between the event timestamp and `$sdk_debug_session_start`. Mobile SDKs that still attach it
  keep the session-consistency rule and their scenarios unchanged.
- Allow `$snapshot` to carry the four cumulative replay-drop counters when non-zero, and only
  those.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-replay-debug-properties`: required versus rate-limited supporting keys, and the
  cumulative drop counters on `$snapshot`.

## Impact

A reduction in what the contract requires, so an SDK that attaches every key on every event stays
conformant and no mobile SDK has to change. posthog-ios and posthog-android keep their session
keys, hold-reason rule, and capture-mode keys as specified. Consumers of the removed and
throttled keys lose per-event resolution: `$sdk_debug_current_session_duration` has to be
computed from `$sdk_debug_session_start`, and a query over a supporting key now samples rather
than covers the event stream. The Tier-2 counter keys remain out of scope; this change does not
make the `$snapshot` drop counters required of any platform.
