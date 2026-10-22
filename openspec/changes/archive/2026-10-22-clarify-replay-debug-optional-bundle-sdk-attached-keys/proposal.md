## Why

The "Attach the optional replay debug bundle only to eligible SDK events" requirement says custom
events "SHALL NOT carry any key of the optional bundle". Reviewers on
[posthog-android#833](https://github.com/PostHog/posthog-android/pull/833#discussion_r4198260625)
read that two ways: as a rule about what the SDK attaches, or as a rule that the SDK must also strip
a same-named key the caller supplied, registered, or set in `beforeSend`. posthog-js only writes the
keys it includes and never strips the caller's, so the second reading would put the mobile SDKs out
of step with the reference.

## What Changes

- Reword the custom-event sentence so it constrains what the SDK attaches itself and states that it
  does not require removing a same-named key that arrived through capture properties, `register`, or
  `beforeSend`.
- Point back to the existing precedence rule: when the SDK does write a key, its value still wins.
- Add one scenario for a caller-supplied optional-bundle key on a custom event, with the posthog-js
  and posthog-android lines that ground it.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-debug-properties`: clarify that the optional-bundle gate governs SDK-attached keys
  only.

## Impact

Clarification of existing behavior; no SDK changes. posthog-js, posthog-android (#833) and
posthog-ios (#859) already behave this way. No other requirement in the spec changes, including the
30-second window rules.
