## Why

**Caller-supplied event properties take precedence** lets the caller's properties win over registered and SDK context properties, but then carves out exceptions: the SDK SHALL set `$is_identified` and `$process_person_profile` after the caller's properties, and MAY do the same for `$session_id`/`$window_id`, the session replay debug properties, `$geoip_disable` and posthog-js bookkeeping. That makes the order hard to predict, and SDKs answer the MAY items differently.

The agreed canonical order is simpler: global properties, then the properties the caller passes on the event, then `before_send`, each overwriting the one before. A caller who passes one of these keys on an event means it for that event, and `before_send` can still change any of them.

## What Changes

- **Caller-supplied event properties take precedence** states the three layers. Everything the SDK sets itself, including `$is_identified`, `$process_person_profile`, `$geoip_disable`, `$session_id`/`$window_id` and the session replay debug properties, is a global property that the caller's event properties override.
- The "caller can't override person-processing state" scenario becomes "caller overrides SDK-set properties".
- Capture's Behavior step 4 lists the two client layers to match.
- Server SDKs are unchanged by this requirement.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: **Caller-supplied event properties take precedence** requirement; Behavior step 4.

## Impact

- **posthog-ios**: conforms in 4.0 (PostHog/posthog-ios#938).
- **posthog-js (browser)**, **posthog-android**, **posthog-react-native** and **posthog-js-lite** (via `@posthog/core`): set `$is_identified`, `$process_person_profile` and, where they set them, `$geoip_disable`, the session properties and the replay debug properties before the caller's properties instead of after.
- **posthog-flutter**: no change; follows the native SDK on iOS and Android, and posthog-js on web.
- **Server SDKs**: no change.
- **Acceptance adapters**: the changed scenario reuses existing steps.
