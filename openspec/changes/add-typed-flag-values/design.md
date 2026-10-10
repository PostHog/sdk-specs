## Context

The server can answer `/flags?v=3` ([PostHog/posthog#107732](https://github.com/PostHog/posthog/pull/107732)). A v3 record has five members: `key`, `value`, `failed`, `reason` and `metadata`. `value` is the flag's typed application value: a boolean, a non-empty string, a number, an object, or `null` when the flag default is `null`. `enabled` and `variant` no longer exist at v3; readers derive them from `value`. The public wire contract is `contracts/feature_flag_rules_v2` in [posthog-sdk-test-harness 1.13.1](https://github.com/PostHog/posthog-sdk-test-harness/releases/tag/1.13.1) (contract 2.3.1): the producer schema, the reader fixtures, the OpenFeature mapping in `registries/literals.json`, and the legacy rendering table of the typed value corpus. This change does not touch the wire. It defines what an application calls and sees.

Today's SDK surface is built on `enabled`, a variant key and a payload:

- clients: `isFeatureEnabled`, `getFeatureFlag`, `getFeatureFlagPayload`, `getFeatureFlagResult` (the browser marks `getFeatureFlagPayload` deprecated in favour of `getFeatureFlagResult`);
- servers: the same single-flag getters, superseded by the `evaluateFlags()` snapshot with `isEnabled`, `getFlag`, `getFlagPayload`, `only` and `onlyAccessed`.

PostHog ships OpenFeature providers for Python (in `posthog-python`), Node and web (in `posthog-js`) and Elixir (in `posthog-elixir`). All four call `getFeatureFlagResult` and map it the same way: boolean reads return `enabled` (so a multivariate flag reads as `true`), string reads return the variant, number reads parse the variant string (Python and Elixir also accept hexadecimal), object reads return the payload, and a disabled flag read as a non-boolean type returns the caller default without an error. Reasons are `TARGETING_MATCH` when enabled, `DISABLED` for `flag_disabled`, otherwise `DEFAULT`; the PostHog reason text goes into flag metadata as `posthog_reason`.

[posthog-python#1031](https://github.com/PostHog/posthog-python/pull/1031) (draft) is the reference implementation. It requests `v=3`, keeps each record's value, reason and metadata, adds `get_boolean_value` / `get_boolean_details` and the string, number and object pairs to the `evaluate_flags()` snapshot, and keeps every legacy getter and `$feature_flag_called` unchanged.

This design is a starting point for iteration. Each decision below states the assumption the specs take, the main alternative, and how the choice scores on three lenses: developer experience (DX), OpenFeature compatibility (OF) and migration from today's API (Migration).

## Goals / Non-Goals

**Goals:**

- One small, typed read API that works for every flag, old and new.
- An evaluation-details object with the same fields in every SDK, close enough to OpenFeature that a provider passes it through.
- No change to any existing accessor's return value or events, so users adopt the new API one call at a time.
- Make the open choices visible so the SDK team can settle them.

**Non-Goals:**

- `$experiment_exposure`, its dedupe, and the rule and experiment attribution properties on `$feature_flag_called`.
- Local evaluation of config version 2 flags.
- Changes to the `/flags` wire contract, the bootstrap format, or framework bindings such as React hooks.
- SDK code. Each SDK implements this in its own repository.

## Decisions

### D1. Native typed accessors, not OpenFeature-only

**Assumption.** Every SDK gets native typed accessors. OpenFeature providers wrap them.
**Alternative.** Expose typed values only through OpenFeature providers and leave the native API on `enabled` / variant / payload.
**Why.** Most PostHog users do not use OpenFeature, providers exist for only four languages, and a provider is only thin if the native API already has typed values and details. Native accessors also keep PostHog behaviour that OpenFeature has no place for: `$feature_flag_called` on access and the `evaluateFlags()` snapshot that `capture(flags: snapshot)` reuses.
**Lenses.** DX: one API for everyone. OF: same method shapes, so the provider is a pass-through. Migration: additive.

### D2. Accessor placement

**Assumption.** Server SDKs put the accessors on the `evaluateFlags()` snapshot only. Client SDKs put them on the client and read loaded flags. Server SDKs do not add typed single-flag client methods; one that does must make each method behave like a one-key `evaluateFlags()` followed by the snapshot accessor.
**Alternative.** Also add `client.getBooleanValue(key, default, distinctId, options)` and the rest to server clients.
**Why.** The snapshot is already the preferred server API, it serves the async clients too, and it keeps one evaluation per request. Eight more per-call methods with the full evaluation-context parameter list double the server surface. An OpenFeature server provider can call `evaluateFlags(distinctId, { flagKeys: [key] })` at the same cost as a single-flag getter.
**Lenses.** DX: one obvious server pattern; one extra line for single-flag callers. OF: matches OpenFeature's split between the static-context (client) and dynamic-context (server) paradigms, with the snapshot as the bound context. Migration: server users of single-flag getters must adopt `evaluateFlags()` first.

### D3. Default semantics

The existing `evaluate-flags` and `is-feature-enabled` specs say a present `false` wins over a caller default for enablement. The public contract says a configured flag default of `false` wins over the caller default on a normal no-match, a `null` flag default delegates to the caller default, and abnormal execution returns the caller default.

**Assumption.** Both rules hold, on different accessors:

| Record | Legacy enablement with default `true` | `getBooleanValue(key, true)` | `getStringValue(key, "x")` |
| --- | --- | --- | --- |
| absent | `true` (default) | `true`, `FLAG_NOT_FOUND` | `"x"`, `FLAG_NOT_FOUND` |
| value `false` | `false` | `false` | `"x"`, no error |
| value `null` | `false` (renders as `false`) | `true`, no error | `"x"`, no error |
| failed | `false` (existing rendering) | `true`, `GENERAL` | `"x"`, `GENERAL` |

**Alternative.** Make legacy enablement treat a v3 `null` as "no value" and return the caller default.
**Why.** Legacy accessors must return the same thing whether the server sent a v3 record or an older one, and an older server renders `null` as `enabled: false`. The typed boolean accessor follows the contract and OpenFeature. The one visible difference is a `null` default read through `isEnabled(key, { defaultValue: true })` versus `getBooleanValue(key, true)`. The specs state it and add a scenario for it.
**Lenses.** DX: the typed accessor does the safe thing; the legacy difference needs a docs note. OF: exact. Migration: no legacy change.

### D4. Snapshot value projection for number, object and null

**Assumption.** `getFlag` / `getFeatureFlag` and enablement keep the legacy rendering: number and object values are `true` (enabled), with the value available through the payload accessor and the typed accessors; `null` is `false`. No new untyped `getValue(key)` accessor.
**Alternative.** Let `getFlag` return the typed value, or add an untyped accessor that returns `boolean | string | number | object | null`.
**Why.** `getFlag` is typed `boolean | string | undefined` in several SDKs, and `$feature/<key>`, `$active_feature_flags` and bootstrap export share its rendering. Returning numbers or objects would break typed callers and change event properties. The typed accessors are the projection for typed values.
**Lenses.** DX: number and object flags look "on" to legacy code, which is surprising but safe. OF: n/a. Migration: unchanged.

### D5. Shape of the details object

**Assumption.** Fields `key`, `value`, `variant`, `reason`, `error_code`, `error_message`, `flag_metadata`, in each language's casing. `reason` is the OpenFeature reason string. `variant` is `metadata.variant_key` and is left out when an error code is set. `flag_metadata` is a flat map of the contract's scalar keys (`id`, `version`, `config_version`, `reason_code`, `condition_index`, `rule_type`, `rule_id`, `experiment_id`, `variant_key`, `holdout_id`), with wire (snake_case) key names in every language. It leaves out the payload, `has_experiment` and the reason description.
**Alternatives.** (a) The posthog-python#1031 shape: `reason` is the structured PostHog reason (`code`, `condition_index`, `description`) and `metadata` is a typed metadata object that includes the payload. (b) `flagKey` instead of `key`. (c) camelCase metadata keys, which OpenFeature's telemetry appendix uses.
**Why.** A provider can copy every field without remapping, and OpenFeature hooks and telemetry see the same vocabulary as other providers. The fine-grained `reason_code` and rule identity survive in metadata. `key` matches today's `FeatureFlagResult`. Wire key names in metadata are the same string in every SDK, so dashboards and hooks can rely on them. The description is non-normative text, and exposing it invites code that branches on it; failures still carry it as `error_message`.
**Lenses.** DX: one shape everywhere, but metadata is a map, not a typed object, so no autocompletion. OF: direct. Migration: new type; #1031 must change its details type before it ships.

### D6. Error codes and reason vocabulary

**Assumption.** Only OpenFeature error codes: `FLAG_NOT_FOUND`, `PARSE_ERROR`, `TYPE_MISMATCH`, `INVALID_CONTEXT`, `PROVIDER_NOT_READY`, `GENERAL`. Reasons use the contract's OpenFeature mapping for config version 2 codes. The contract defines no mapping for config version 1 codes, so this change derives one: a failed record is `ERROR`, `flag_disabled` is `DISABLED`, a `true` or string value is `TARGETING_MATCH`, anything else `DEFAULT`. That is what the four providers report today. An unknown config version 2 code is `UNKNOWN`.
**Alternatives.** Add PostHog error codes such as `DEPENDENCY_ERROR`; or map version 1 codes one by one (`condition_match` to `TARGETING_MATCH`, `out_of_rollout_bound` to `DEFAULT`, `holdout_condition_value` to ?).
**Why.** Extra error codes would not survive a provider, and the PostHog code is already in `flag_metadata.reason_code`. The value-based version 1 rule needs no table of version 1 codes and keeps providers' current reasons.
**Lenses.** DX: one small enum; branch on `reason_code` for detail. OF: exact. Migration: providers keep their reasons for existing flags.

### D7. `$feature_flag_called` from typed reads

**Assumption.** A typed read emits the same event as a legacy read of the same flag: same tracker, same dedupe key, and `$feature_flag_response` is the legacy rendering (`true` for number and object values, `false` for `null`), never the caller default. A type mismatch is not reported as `$feature_flag_error`. The rule and experiment attribution properties and any dedupe-key extension come with `$experiment_exposure`.
**Alternative.** Send the value the accessor returned (the typed value, or the caller default), and extend the dedupe key with config version and rule context now.
**Why.** Users can swap one call at a time without double events or broken insights: a typed read and a legacy read of the same flag dedupe together. The public event schema accepts only a boolean or a non-empty string in `$feature_flag_response`, so number and object values cannot go there yet. The caller default is a local fallback, not something the flag evaluated to.
**Lenses.** DX: invisible. OF: n/a (OpenFeature does not capture). Migration: no analytics change.

### D8. Behaviour against older servers

**Assumption.** Follow the contract's reader rule: a record without `value` takes `variant ?? enabled` as its value, config version 1 and no rule context. Typed number and object reads then return the caller default with `TYPE_MISMATCH`, and the error message says the value may need a server that sends typed values. A `null` boolean default reads as `false`. The SDK logs one diagnostic per client instance the first time it reads such a record. No public field marks it.
**Alternatives.** A public field (for example `response_version` in flag metadata, or a snapshot property); reporting older-server records with reason `STALE`; or reconstructing number and object values from the payload.
**Why.** The state is transitional, and a public field outlives it. The symptom appears exactly where a developer looks, in `error_code` and `error_message`. Reconstructing values from payloads would turn every version 1 payload into a typed value, which is coercion.
**Lenses.** DX: clear at the point of failure, but no programmatic check. OF: `TYPE_MISMATCH` is the honest code. Migration: number and object flags need an upgraded server; boolean and string flags work everywhere.

### D9. Payloads

**Assumption.** The payload accessor stays and is the legacy home: version 1 payloads as today, and for config version 2 number and object flags the value itself (the SDK supplies it, because v3 sends `metadata.payload: null` for them). Typed accessors are the recommended way to read number and object values. Users who model configuration as variant plus payload keep using `getFeatureFlag` plus `getFeatureFlagPayload` on those flags. To move, they recreate the flag as a config version 2 object flag whose rule or variant values are the configurations, and read it with `getObjectValue`.
**Alternative.** Make the payload accessor legacy-only, returning nothing for config version 2 flags, or have typed object reads fall back to a version 1 payload.
**Why.** Legacy payload readers keep working when a flag's type changes to number or object, and typed reads never coerce.
**Lenses.** DX: new code needs one call instead of two, and the value cannot disagree with the variant. OF: n/a. Migration: payload users keep working; moving needs a flag change, not just a code change.

### D10. Naming

**Assumption.** OpenFeature method names everywhere, on the server snapshot and on the client root (`posthog.getStringValue('banner-copy', 'Welcome')`). The semantic set is boolean, string, number and object. Languages with separate integer and floating-point types add integer and floating-point accessors (OpenFeature's guidance), and may keep a number accessor. `getFeatureFlagResult` stays as it is; the `get<Type>Details` methods are the details form.
**Alternatives.** Flag-qualified names on clients (`posthog.getStringFlag(...)`, `posthog.getFeatureFlagString(...)`), because `posthog.getStringValue` on a multi-product client does not say it reads a flag. Or extend `FeatureFlagResult` with `value`, `reason` and metadata.
**Why.** One vocabulary across server, client, docs and OpenFeature, and the reference implementation already uses it. Extending `FeatureFlagResult` would put two value channels (`enabled`/`variant` and `value`) on one object and change a type users destructure today.
**Lenses.** DX: consistent, but less self-describing on the client root. OF: identical. Migration: new names, no renames.

### D11. No coercion for config version 1 flags

**Assumption.** Typed accessors never coerce, for any config version. `getBooleanValue` on a multivariate flag is `TYPE_MISMATCH`, while `isFeatureEnabled` returns `true` for it. `getNumberValue` does not parse a variant string, and `getObjectValue` does not read a payload.
**Alternative.** Coerce for version 1 flags the way today's providers do.
**Why.** One rule for every flag; the same code keeps working when a flag moves to config version 2. Coercion hides mistakes such as a variant `"10"` that later becomes `"ten"`.
**Lenses.** DX: strict, with a clear error code. OF: OpenFeature 1.3.4 asks for this. Migration: `isFeatureEnabled` on multivariate flags does not map to `getBooleanValue`. Those callers keep `isFeatureEnabled` or compare `getStringValue`.

### D12. Number and object values

**Assumption.** Numbers are binary64. An integer accessor rejects fractional or out-of-range numbers as `TYPE_MISMATCH`. Objects are JSON objects only; arrays are not typed values (the wire rejects them), and version 1 array payloads stay on the payload accessor. A returned object must not let the caller mutate the snapshot.
**Alternative.** Accept top-level arrays as OpenFeature "structure" values.
**Why.** The config schema only admits top-level objects, so the reader matches the writer.
**Lenses.** DX: predictable. OF: a subset of "structure". Migration: none.

### D13. Client reads before flags load

**Assumption.** With no response, no persisted flags and no bootstrap, a client typed read returns the caller default with `PROVIDER_NOT_READY`.
**Alternative.** `FLAG_NOT_FOUND`.
**Why.** It separates a start-up race from a typo or a deleted flag, and it is the OpenFeature code with that meaning.
**Lenses.** DX: better debugging. OF: direct. Migration: none.

### D14. Bootstrap and overrides

**Assumption.** Bootstrapped values read as typed values with reason `CACHED` and empty metadata; overrides with the custom reason `override`. The bootstrap format is unchanged, so number and object flags can only be bootstrapped through their legacy rendering and read as `TYPE_MISMATCH` until flags load.
**Alternative.** Allow typed values in `bootstrap.featureFlags`.
**Why.** Server SDKs build bootstrap maps that older client SDKs consume. A number or object in that map would break them. Typed bootstrap needs its own versioned change.
**Lenses.** DX: a gap for number and object flags in server-rendered apps. OF: `CACHED` is the contract's mapping. Migration: none.

### D15. OpenFeature providers

**Assumption.** Providers build resolution details from the details accessors. For config version 1 flags they may keep their released coercions (boolean as `enabled`, number from the variant, object from the payload) until their next major release. They never apply them to config version 2 flags.
**Alternative.** Switch providers fully to the typed accessors now, which changes results for existing flags: multivariate boolean reads, numeric variants and object payloads all become `TYPE_MISMATCH`.
**Why.** Existing provider users get no behaviour change. New flags follow OpenFeature exactly.
**Lenses.** DX: no surprise for provider users. OF: exact for config version 2 flags, compatible for version 1 flags. Migration: the major release removes the shim.

### D16. Deprecation guidance

**Assumption.** No deprecation now. Docs present the typed accessors as the recommended API for new code and the way to read config version 2 number and object values. Revisit when every SDK ships typed accessors and config version 2 flags are generally available.
**Alternative.** Soft-deprecate `getFeatureFlagPayload` and `getFeatureFlagResult` now.
**Why.** Version 1 payloads have no other home yet, and warnings before every SDK has a replacement only produce noise.
**Lenses.** DX: no warning noise. OF: n/a. Migration: soft.

## Developer experience: before and after

Python (server snapshot):

```python
# before
flags = posthog.evaluate_flags("user-1")
limit = 10
if flags.is_enabled("upload-limit"):
    payload = flags.get_flag_payload("upload-limit")
    if isinstance(payload, dict) and isinstance(payload.get("limit"), int):
        limit = payload["limit"]

# after
flags = posthog.evaluate_flags("user-1")
limit = flags.get_number_value("upload-limit", 10)

details = flags.get_number_details("upload-limit", 10)
if details.error_code is not None:
    log.info("upload-limit fell back: %s %s", details.error_code, details.error_message)
details.reason                              # "TARGETING_MATCH"
details.flag_metadata.get("reason_code")    # "targeting_match"
```

Node (server snapshot):

```ts
// before
const flags = await posthog.evaluateFlags('user-1')
const copy = flags.getFlag('banner-copy')
const text = typeof copy === 'string' ? copy : 'Welcome'

// after
const flags = await posthog.evaluateFlags('user-1')
const text = flags.getStringValue('banner-copy', 'Welcome')
const { value, variant, reason, errorCode, flagMetadata } = flags.getStringDetails('banner-copy', 'Welcome')
```

Browser JS (client):

```js
// before
const result = posthog.getFeatureFlagResult('checkout-config')
const config = result?.enabled && result.payload ? result.payload : { steps: 3 }

// after
const config = posthog.getObjectValue('checkout-config', { steps: 3 })

// a multivariate flag: same value, same $feature_flag_called event
const arm = posthog.getStringValue('pricing-test', 'control') // was posthog.getFeatureFlag('pricing-test')

// a missing or failed flag
const nav = posthog.getBooleanDetails('new-nav', false)
if (nav.errorCode === 'FLAG_NOT_FOUND') {
    /* typo, deleted flag, or not in this project */
}
```

## OpenFeature fit

Kept: typed `get<Type>Value` / `get<Type>Details`, a required caller default, no throwing, the evaluation-details fields, the reason and error-code vocabulary, scalar flag metadata, and the caller default on abnormal execution. A provider becomes:

```ts
async resolveStringEvaluation(flagKey, defaultValue, context) {
    const snapshot = await this.client.evaluateFlags(context.targetingKey, { flagKeys: [flagKey], ...split(context) })
    const { value, variant, reason, errorCode, errorMessage, flagMetadata } = snapshot.getStringDetails(flagKey, defaultValue)
    return { value, variant, reason, errorCode, errorMessage, flagMetadata }
}
```

Deliberate differences:

- **Event capture on access.** PostHog emits `$feature_flag_called` on every read, because experiments and flag analytics depend on it. OpenFeature leaves this to hooks and its tracking API.
- **Snapshot model.** Server SDKs bind the evaluation context once per request in `evaluateFlags()`, and `capture(flags: snapshot)` reuses the exact values. OpenFeature evaluates per call with a dynamic context.
- **No hooks or evaluation options** on the native accessors; providers add them.
- **`version` metadata** is the flag's integer row version. OpenFeature's telemetry guidance suggests a string; providers may convert it.
- **Group context.** A missing group is `INVALID_CONTEXT`, because PostHog keeps the person in `targetingKey` and groups in other context fields.

## Migration story

How far the model moves:

- **Today:** a flag is on or off, may name a variant, and may carry a payload per variant. Code asks "is it on?", "which variant?" and "what payload?", in up to three calls.
- **Typed:** a flag returns one value of a declared type, plus the reason. Code asks once, with the fallback it wants. For config version 2 experiments the variant key names the arm and the value is what the arm returns; branch on the value, and read `details.variant` only to know the arm.

What each kind of user does:

- **Boolean flags:** `isFeatureEnabled(k)` becomes `getBooleanValue(k, false)`. Same result for boolean flags. Differences: a multivariate flag is `TYPE_MISMATCH` (keep `isFeatureEnabled` or use `getStringValue`), and a config version 2 flag with a `null` default returns your default instead of `false`.
- **Multivariate flags:** `getFeatureFlag(k)` becomes `getStringValue(k, 'control')`. Same variant key; no-match returns your default instead of `false` or `undefined`.
- **Payload users:** nothing changes on existing flags. New number and object flags read in one call. Moving variant-plus-payload configuration means recreating the flag as an object flag; `details.variant` keeps the arm key.
- **OpenFeature users:** no change for existing flags (D15). Config version 2 flags resolve natively with full reasons and metadata.
- **Analytics:** unchanged. Typed and legacy reads produce the same event and dedupe together, so a code base can mix them.

Each call moves on its own. A code base can keep `isFeatureEnabled` everywhere and adopt `getObjectValue` for one new flag.

## Differences from posthog-python#1031

| Topic | #1031 | This change |
| --- | --- | --- |
| `reason` | Structured PostHog reason object (`code`, `condition_index`, `description`) | OpenFeature reason string; `reason_code` and `condition_index` in `flag_metadata` |
| Metadata | Typed `metadata` object, includes the payload | Scalar `flag_metadata` map of the contract's keys, without the payload |
| `variant` on an error | Taken from metadata even when the default is returned | Left out when an error code is set |
| Locally evaluated version 1 flags | No reason or metadata | Derived reason and `config_version` 1 |
| Older-server records | Silent | One diagnostic log; `TYPE_MISMATCH` message names the cause |

Placement, resolution rules, error codes, legacy rendering, payload synthesis and the event behaviour match.

## Risks / Trade-offs

- [`isEnabled(key, { defaultValue: true })` and `getBooleanValue(key, true)` disagree for a `null` flag default] → State it in the spec and docs; it is the price of keeping legacy results identical across response versions.
- [`posthog.getStringValue` on a client is not obviously a flag read] → Docs and the key argument; D10 lists flag-qualified names as the alternative.
- [Number and object flags are invisible to typed reads on servers that do not send `value`] → `TYPE_MISMATCH` with a message that names the cause, plus a one-time log.
- [Providers keep version 1 coercions for a while] → Limited to config version 1 flags and removed in a major release.
- [Persisted client caches from older SDK versions have no typed values] → Read them like older-server records until the next flags load.
- [The contract has no OpenFeature mapping for config version 1 reason codes] → The value-based rule in D6; raise it with the contract owners if they want an explicit table.

## Migration Plan

1. Review this proposal and settle the decisions in the PR description.
2. Adjust the specs, add `acceptance/public/typed-flag-values.feature`, add the capability to the README index, then apply and archive in the same PR, as the repository requires.
3. SDKs implement against the archived spec. posthog-python#1031 adjusts its details type first; Node is next.

## Open Questions

The decisions above are assumptions, not settled answers. The PR description lists each with its alternative. Questions not covered there:

- Should the details object expose the human-readable reason description for debugging, outside `error_message`?
- Should older-server records keep the legacy `variant` as `details.variant`? The contract treats all metadata of such records as absent, so this change leaves it out.
- What do framework bindings (React hooks, Vue composables) look like? They can wait for this contract.
