## Why

The capture v1 server SDKs (posthog-python 8, posthog-go v2, posthog-node 6, posthog-rs 1.0) send a `null` property value as the caller gave it, and PostHog keeps it: capture does not strip nulls and the events table records them. Some client SDKs (posthog-android, posthog-flutter on web and desktop) omit them. "Capture drops null-valued object properties" requires every SDK to omit them, so both groups can't conform at once. Scenarios added for capture v1 already accept a property that is absent or equal to JSON `null`. This follows up sdk-specs #60.

## What Changes

- An SDK MAY omit null/undefined-valued custom object properties when it serializes events. An SDK that keeps them sends JSON `null`, and PostHog stores it.
- The recursion, array-position, enrichment, `before_send` and disk-serialization rules now bind only an SDK that omits.
- The public API rule does not change: an SDK still accepts the null/undefined property values its API accepts today.
- Scenarios that assert omission carry the new acceptance capability tag `@null_property_omission_capable`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: **Capture drops null-valued object properties** makes omission optional and tags its eight scenarios.
- `capture-ai`: **AI capture drops null-valued object properties** tags its scenario. Its text still defers to capture.
- `capture-exception`: **Exception capture drops null-valued custom object properties** tags its scenario. Its text still defers to capture.

## Impact

- `acceptance/public/capture.feature`, `capture-ai.feature` and `capture-exception.feature` tag their omission scenarios, including the `@sdk:server` exception scenario.
- No SDK has to change. An SDK that omits today still conforms, and so does one that sends JSON `null`.
- The requirement titles do not change, because other specs refer to them by name.
