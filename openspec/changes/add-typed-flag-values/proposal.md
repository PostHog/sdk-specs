## Why

The `/flags?v=3` response gives every flag one typed `value` (boolean, string, number, object or `null`) plus a structured `reason` and rule metadata ([PostHog/posthog#107732](https://github.com/PostHog/posthog/pull/107732), wire contract in [posthog-sdk-test-harness 1.13.1](https://github.com/PostHog/posthog-sdk-test-harness/releases/tag/1.13.1), `contracts/feature_flag_rules_v2`). Flags can now return string, number and object values directly ([PostHog/posthog#107733](https://github.com/PostHog/posthog/pull/107733)). The SDK specs only describe the older `enabled` / variant / payload surface, so there is no shared contract for how an application reads a typed value, learns why it got that value, or handles a missing or failed flag. [posthog-python#1031](https://github.com/PostHog/posthog-python/pull/1031) is the first SDK to add typed accessors. Other SDKs need the same contract before they follow.

## What Changes

- Add typed accessors that follow the OpenFeature client model: `getBooleanValue` / `getBooleanDetails`, and the same for string, number and object, each with a required caller default. Names follow each language's casing.
- Define how a typed accessor resolves a value without coercion: a `false` or `null` value means "no value" for a non-boolean accessor; a `false` boolean value wins over the caller default; a value of another type returns the caller default with `TYPE_MISMATCH`.
- Define one evaluation-details object for every SDK: `key`, `value`, `variant`, `reason` (OpenFeature vocabulary), `error_code` (OpenFeature codes), `error_message` and `flag_metadata` (scalar keys from the public contract, such as `reason_code`, `rule_id` and `config_version`).
- Put the accessors on the `evaluateFlags()` snapshot in server SDKs and on the client in client SDKs.
- Make typed accessors work for every flag, including config version 1 flags, so users have one API to move to.
- Keep every existing accessor's return value. Number and object values render as `true` on the legacy value accessors, and the payload accessor returns them. A `null` value renders as `false`.
- Typed reads emit the same `$feature_flag_called` event, with the same `$feature_flag_response` and dedupe key, as a legacy read of the same flag.
- Define behaviour against servers that do not send `value`, for bootstrapped and overridden values, for locally evaluated config version 1 flags, and for client SDKs before flags load.
- Let PostHog's OpenFeature providers become thin wrappers over the details accessors, while they keep their released config version 1 coercions until a major release.

No breaking changes. No existing accessor changes its return value or events.

## Capabilities

### New Capabilities

- `typed-flag-values`: typed flag value and evaluation-details accessors, their resolution rules, the details object, the legacy rendering that keeps existing accessors unchanged, and behaviour against older servers, bootstrap, overrides and local evaluation.

### Modified Capabilities

- `evaluate-flags`: snapshot value and enablement projections for number, object and `null` values; caller-default rules reconciled with the typed boolean accessor; snapshot typed accessors and their access tracking.
- `feature-flag-called-tracker`: typed reads share the `$feature_flag_called` event and dedupe key with legacy reads.

## Impact

- Specs and decisions only. No SDK code changes in this repository.
- Server SDKs with `evaluateFlags()` (Node, Python, Ruby, PHP, Go, .NET, JVM) add snapshot accessors. Client SDKs (browser, React Native, iOS, Android, Flutter) add client accessors. SDKs must read `/flags?v=3` and keep each flag's details to implement them.
- The OpenFeature providers for Python, Node, web and Elixir can move onto the details accessors.
- posthog-python#1031 is the reference implementation. Its details type differs from this proposal in a few places, listed in `design.md`.
- `$experiment_exposure`, the rule and experiment attribution properties on `$feature_flag_called`, local evaluation of config version 2 flags and the wire contract are out of scope.
