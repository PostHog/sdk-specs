## Why

`evaluateFlags()` is the preferred server API, and the single-flag getters it supersedes now log deprecation warnings that point callers to it. Those getters let the caller turn `$feature_flag_called` off per call, and some SDKs also have a client-level default. The snapshot contract mentions neither control. posthog-node snapshot reads ignore `sendFeatureFlagEvent: false` ([PostHog/posthog-js#5252](https://github.com/PostHog/posthog-js/pull/5252) is a draft fix), and no SDK's snapshot reads take the per-call option. A caller that turned events off gets them back after migrating. Once snapshot reads honor a client-level default, a client that turned events back on only for experiment flags has no way to keep those exposures.

Customers turn these events off for flags they do not use with flag analytics or experiments, to cut event volume and noise in their project. Following our own deprecation guidance should not undo that setting.

## What Changes

- Snapshot enablement and value reads accept an optional per-read `sendFeatureFlagEvents` option (platform casing), with the same meaning as the per-call option on the single-flag getters.
- The SDK decides each read in this order: the per-read option, then the SDK's client-level default where it has one, then send. The single-flag getters already use this order.
- A read that does not send emits no `$feature_flag_called` (including `flag_missing`), leaves the dedupe tracker untouched, and still counts as access for `onlyAccessed()`.
- `evaluateFlags()` takes no per-snapshot event option.
- The supersession map now preserves exposure-event control: `getFeatureFlag(key, id, { sendFeatureFlagEvents: x })` becomes `evaluateFlags(id).getFlag(key, { sendFeatureFlagEvents: x })`.
- Acceptance scenarios for each rule.

Unchanged: creating a snapshot emits nothing, payload reads stay silent, a read with no option anywhere still emits, and the other documented migration differences (bulk maps, Go's legacy payload getter) stay as they are.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: add the snapshot feature flag event control, and amend lazy access tracking and the supersession map to defer to it.

## Impact

Specs and acceptance documentation only. Every server SDK that implements `evaluateFlags` needs the per-read option. An SDK with a client-level default must also honor that default on snapshot reads: the JVM server SDK already does, and posthog-node will with #5252. An SDK whose snapshot reads ignored its client-level default until now should say in its changelog that callers who relied on snapshot reads for exposures while that default was off must now opt those reads in.
