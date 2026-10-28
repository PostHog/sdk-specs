## Why

`session-replay-debug-properties` says SDK-computed `$recording_status` and `$sdk_debug_*` values take precedence over a registered or caller-supplied property of the same name, and that the merge writes the debug map last. Capture's **Caller-supplied event properties take precedence** (simplified in #143) now gives client SDKs one order with no exceptions: properties the SDK sets itself, then registered (super) properties, then the caller's properties, then `before_send`. #143 listed the replay debug properties among the keys that move under that order, but didn't update this spec, so the two specs now disagree.

## What Changes

- **Session, queue, hold-reason, trigger, and mode keys**: the debug keys follow capture's merge order. A registered property overrides the SDK-computed value, a caller-supplied property overrides both, `before_send` can change any of them, and the override applies to that event only.
- The "Debug values win over same-named caller or registered properties" scenario is replaced by scenarios for a registered override, a caller override, and the next event carrying the SDK-computed value again.
- The posthog-ios references drop the 3.x merge that let the debug map override a same-named property and its covering test, and cite the 4.0 test instead.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-debug-properties`: **Session, queue, hold-reason, trigger, and mode keys** requirement.

## Impact

- **posthog-ios**: conforms in 4.0 (PostHog/posthog-ios#938).
- **posthog-js (browser)**, **posthog-android**, **posthog-react-native**: already listed by #143 as needing to set the replay debug properties before registered and caller properties; no extra work.
- **Server SDKs**: not applicable.
