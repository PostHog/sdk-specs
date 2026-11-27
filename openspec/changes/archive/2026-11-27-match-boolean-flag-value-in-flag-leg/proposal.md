## Why

The "Flag leg" requirement says a `{ flag, variant }` object is satisfied only when the flag
resolves to that variant, and in the same requirement says the group reuses the V1 matcher
unchanged. The two disagree when the flag value is boolean `true`: the V1 matcher in posthog-js
and the trigger-group evaluators in posthog-android and posthog-ios treat boolean `true` as a
match whatever variant is configured. The case is reachable when a flag changes from multivariate
to boolean after a group was saved with a variant.

## What Changes

- **Modified: "Flag leg".**
  - The leg reads the resolved flag value. A boolean value satisfies the leg when it is `true` and
    not when it is `false`, whether or not a variant is configured.
  - A string value must equal a configured variant; with no variant, any non-empty string matches.
  - Adds the reference lines for the boolean case and states that no posthog-js test covers it.
  - Adds the scenario "A boolean true flag value satisfies a flag leg with a variant".

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-trigger-groups`: the "Flag leg" requirement states the boolean-value case
  explicitly and gains one scenario.

## Impact

- **posthog-js, posthog-android, posthog-ios:** match the clarified text already.
- **posthog-react-native:** the open trigger-groups PR (PostHog/posthog-js#5854) also matches
  boolean `true` with a configured (non-string) variant.
- No wire, config, or public API change.
