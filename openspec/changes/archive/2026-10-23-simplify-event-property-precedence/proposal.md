## Why

**Caller-supplied event properties take precedence** lets the caller's properties win over registered and SDK context properties, but then carves out exceptions: the SDK SHALL set `$is_identified` and `$process_person_profile` after the caller's properties, and MAY do the same for `$session_id`/`$window_id`, the session replay debug properties, `$geoip_disable` and posthog-js bookkeeping. That makes the order hard to predict, and SDKs answer the MAY items differently.

The agreed canonical order is simpler: properties the SDK sets itself, then registered (super) properties, then the properties the caller passes on the event, then `before_send`, each overwriting the one before. A caller who passes one of these keys on an event means it for that event, and `before_send` can still change any of them.

## What Changes

- **Caller-supplied event properties take precedence** states three merge layers plus `before_send`, so no key is listed as an exception. A registered or caller value changes that event only, and the project token stays request routing outside the layers.
- The "caller can't override person-processing state" scenario becomes "caller overrides SDK-set properties", and a second scenario checks a later event carries the SDK's value again.
- Capture's Behavior step 4 lists the three client layers to match.
- Server SDKs are unchanged by this requirement.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: **Caller-supplied event properties take precedence** requirement; Behavior step 4.

## Impact

- **posthog-ios**: conforms in 4.0 (PostHog/posthog-ios#938).
- **posthog-js (browser)**, **posthog-android**, **posthog-react-native** and **posthog-js-lite** (via `@posthog/core`): set `$is_identified`, `$process_person_profile` and, where they set them, `$geoip_disable`, the session properties and the replay debug properties before registered and caller properties instead of after. posthog-android also merges registered properties before SDK context, so SDK context wins over them today.
- **posthog-flutter**: no change; follows the native SDK on iOS and Android, and posthog-js on web.
- **Server SDKs**: no change.
- **Acceptance adapters**: the changed scenario reuses existing steps; the second-event scenario needs a step that asserts on a named enqueued event.
