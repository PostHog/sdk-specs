## Why

A config version 2 `$feature_flag_called` event carries the record's config version, reason code, rule ID, rule type and variant key, and a complete experiment split also sends `$experiment_exposure` (#162). The specs take these from "the record that supplied the value", and they name bootstrapped and overridden values as values the record did not supply. They do not name two other cases where a server SDK has a config version 2 record but reports another value:

- a payload read with a caller-supplied match value reports the caller's value;
- a stale cached value, reported after a failed flags request or a failed cache write, is the cache's value, not the current record's.

`experiment-exposure` already keeps a match-value read from sending an exposure, but neither spec says what its `$feature_flag_called` carries, and neither names the stale cached value. Pairing a caller's value or a stale value with the record's rule and variant would attribute an exposure to the wrong arm.

## What Changes

- `feature-flag-called-tracker` states the general rule: config version 2 attribution only when the record supplied the reported value. Otherwise the event is sent as for a config version 1 flag: it keeps `$feature_flag_reason`, carries none of the five attribution properties, uses the config version 1 dedupe key, and the read sends no `$experiment_exposure`. The requirement lists bootstrapped values, client-side overrides, caller-supplied match values and stale cached values. A `failed` record that no other value replaces keeps its config version and reason code, as before.
- The attribution requirement lists the two new cases with bootstrap and overrides, and scopes its `$feature_flag_response` rule to values the record supplied, so a match-value read can report the caller's value.
- The `experiment-exposure` trigger lists the same four cases.
- `acceptance/private/feature-flag-called-tracker.feature` gets a match-value and a stale-cache scenario outline, each with a record value that equals the reported value and one that does not.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `feature-flag-called-tracker`: new requirement **Values the record did not supply are reported as config version 1**; **Config version 2 attribution on `$feature_flag_called`** names the new cases and scopes its `$feature_flag_response` rule.
- `experiment-exposure`: **Experiment exposure trigger** names the new cases.

## Impact

- posthog-python already behaves this way ([PostHog/posthog-python#1154](https://github.com/PostHog/posthog-python/pull/1154), released in 7.87.0).
- posthog-node has neither case: its payload read sends no flag events, and it keeps no cache of remote results.
- No wire contract, event schema or harness change. The new acceptance scenarios keep the legacy `@server` tag, so the integration suite does not select them.
