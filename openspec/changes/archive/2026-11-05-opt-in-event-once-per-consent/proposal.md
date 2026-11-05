## Why

The browser SDK captures `$opt_in` when the application grants consent. PostHog's own consent
documentation tells people to call `opt_in_capturing()` from their consent manager's
consent-change callback, and many consent managers fire that callback on every page load once
consent is stored. Until recently the browser captured `$opt_in` every time, so those sites sent
one `$opt_in` per page view — a billable event recording nothing new, observed at real customers.

`opt-in` describes the consent API and acknowledges the browser's consent event and its custom
event name option, but says nothing about when that event is captured. posthog-js now captures it
only on a transition into the opted-in state (PostHog/posthog-js#5504), which is the behavior the
spec should state.

## What Changes

- New requirement in `opt-in`: an SDK that captures a consent event on opt-in SHALL capture it only
  when the call changes the stored consent state, not when the caller is already opted in.
- A custom consent event name is the same event under another name and SHALL be suppressed on the
  same terms.
- Already-stored consent read back on a later page load or SDK instance counts as already opted in,
  so a repeated call across page loads captures nothing.
- Opting out and opting back in, and `reset()` followed by opt-in, are transitions and SHALL capture
  the event again.
- Everything else `optIn()` does — persisting consent, draining the queue, restarting replay and
  surveys, and any initial pageview — SHALL still run on a repeat call. Suppression covers the
  consent event only.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `opt-in`: adds the **Consent event is captured once per opt-in transition** requirement.

## Impact

- **posthog-js (browser)**: conforms as of PostHog/posthog-js#5504.
- Client SDKs that do not emit a consent event on opt-in (iOS, Android, Flutter, React Native,
  Unity) are unaffected — the requirement is conditional on capturing one.
- Server SDKs: not applicable.
- Behavior change for anyone counting `$opt_in` per page load; the count becomes per consent
  transition. The posthog-js PR offered to keep the old behavior behind a config option and shipped
  without one.
