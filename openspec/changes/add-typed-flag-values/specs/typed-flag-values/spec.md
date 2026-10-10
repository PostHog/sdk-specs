## ADDED Requirements

### Requirement: Typed accessor surface

The SDK SHALL expose typed flag accessors for four value types: boolean, string, number and object. Each type SHALL have a value form, which returns the value, and a details form, which returns an evaluation-details object. Every accessor SHALL take the flag key and a required caller default of the accessor's type, and SHALL return a value of that type. Accessors SHALL NOT throw or reject for a missing, failed, unreadable or mismatched flag; they return the caller default instead.

Names follow the OpenFeature client methods in the host language's casing:

| Language family | Value form | Details form |
| --- | --- | --- |
| JavaScript / TypeScript, PHP, Dart, Java / Kotlin, Swift | `getBooleanValue`, `getStringValue`, `getNumberValue`, `getObjectValue` | `getBooleanDetails`, `getStringDetails`, `getNumberDetails`, `getObjectDetails` |
| Python, Ruby, Elixir | `get_boolean_value`, `get_string_value`, `get_number_value`, `get_object_value` | `get_boolean_details`, … |
| Go, .NET | `GetBooleanValue`, … (with the platform's async suffix where its flag getters have one) | `GetBooleanDetails`, … |

Number values are IEEE-754 binary64. A language with distinct integer and floating-point types SHOULD expose integer and floating-point accessors (for example `getIntegerValue` and `getDoubleValue`) in place of, or next to, the number accessor. An integer accessor SHALL treat a number that is not integral, or does not fit the integer type, as a value of another type. Object values are JSON objects. The SDK SHALL return them in the platform's JSON-object representation, and SHALL NOT let a caller change the evaluated flag state by mutating a returned object.

Where the platform's existing flag getters are asynchronous, the typed accessors MAY be asynchronous in the same way.

#### Scenario: Value form returns the typed value
- **GIVEN** the evaluated flag "upload-limit" has the number value 25
- **WHEN** the number value accessor is called for "upload-limit" with caller default 10
- **THEN** it returns 25

#### Scenario: Details form returns the same value with its details
- **GIVEN** the evaluated flag "banner-copy" has the string value "Hello" with reason code `targeting_match`
- **WHEN** the string details accessor is called for "banner-copy" with caller default "Welcome"
- **THEN** the details value is "Hello"
- **AND** the details reason is `TARGETING_MATCH`
- **AND** the details have no error code

### Requirement: Accessor placement

Server SDKs that implement `evaluate-flags` SHALL expose the typed accessors on the `FeatureFlagEvaluations` snapshot (see the `evaluate-flags` requirement "Snapshot typed accessors"). They are not required to add typed single-flag methods to the client. A server SDK that adds them SHALL make each one behave like an `evaluateFlags(...)` call scoped to that one key followed by the snapshot's typed accessor.

Client SDKs SHALL expose the typed accessors on the client. They SHALL read the currently loaded flag state, like `getFeatureFlag(...)`, and SHALL NOT start a network request. Client accessors MAY accept the per-call event-suppression option that the platform's existing flag getters accept.

#### Scenario: Server reads a typed value from a snapshot
- **GIVEN** remote evaluation for distinct id "user-123" returns flag "upload-limit" with the number value 25
- **WHEN** `evaluateFlags("user-123")` is called
- **AND** the number value accessor is called for "upload-limit" on the snapshot
- **THEN** it returns 25
- **AND** the accessor makes no feature-flag evaluation request

#### Scenario: Client reads a typed value from loaded flags
- **GIVEN** a client SDK has loaded flag "banner-copy" with the string value "Hello"
- **WHEN** the string value accessor is called for "banner-copy" with caller default "Welcome"
- **THEN** it returns "Hello"
- **AND** no feature-flag request is made

### Requirement: Typed values resolve without coercion

A typed accessor SHALL compare the JSON type of the flag's value with the requested type and SHALL NOT convert one type to another. It SHALL resolve the value in this order:

1. If a situation listed in "Caller default on missing, failed and unreadable flags" applies, return the caller default with that requirement's error code.
2. If the value has the requested type, return it. For the boolean accessor this includes `false`: a configured flag default of `false` wins over the caller default.
3. If the value is `null`, return the caller default without an error code. The details carry the reason of the flag's record.
4. If the value is `false` and the requested type is not boolean, return the caller default without an error code. The details carry the reason of the flag's record. A disabled config version 1 flag, or an older server's rendering of a `null` value, therefore reads as "no value" rather than as a type error.
5. Otherwise return the caller default with error code `TYPE_MISMATCH` and reason `ERROR`.

The rules apply to every flag, including config version 1 flags: a boolean flag reads through the boolean accessor, and a multivariate flag reads its variant key through the string accessor. A multivariate flag read through the boolean accessor is a `TYPE_MISMATCH`, unlike the legacy enablement accessor, which treats a variant as enabled.

#### Scenario: Typed resolution table
- **GIVEN** a flag "f" whose evaluated value is <value>
- **WHEN** the <type> details accessor is called for "f" with caller default <default>
- **THEN** the details value is <returned>
- **AND** the details error code is <error_code>

  | value         | type    | default  | returned      | error_code    |
  | true          | boolean | false    | true          | none          |
  | false         | boolean | true     | false         | none          |
  | null          | boolean | true     | true          | none          |
  | "compact"     | boolean | false    | false         | TYPE_MISMATCH |
  | 1             | boolean | false    | false         | TYPE_MISMATCH |
  | "compact"     | string  | "x"      | "compact"     | none          |
  | false         | string  | "x"      | "x"           | none          |
  | null          | string  | "x"      | "x"           | none          |
  | true          | string  | "x"      | "x"           | TYPE_MISMATCH |
  | 12.5          | number  | 10       | 12.5          | none          |
  | 0             | number  | 10       | 0             | none          |
  | "12"          | number  | 10       | 10            | TYPE_MISMATCH |
  | true          | number  | 10       | 10            | TYPE_MISMATCH |
  | false         | number  | 10       | 10            | none          |
  | {"steps": 3}  | object  | {}       | {"steps": 3}  | none          |
  | {}            | object  | {"a": 1} | {}            | none          |
  | true          | object  | {}       | {}            | TYPE_MISMATCH |

#### Scenario: Integer accessor rejects a fractional number
- **GIVEN** the SDK's language has distinct integer and floating-point types
- **AND** flag "ratio" has the number value 0.25
- **WHEN** the integer accessor is called for "ratio" with caller default 1
- **THEN** it returns 1 with error code `TYPE_MISMATCH`
- **WHEN** the floating-point accessor is called for "ratio" with caller default 1.0
- **THEN** it returns 0.25

### Requirement: Caller default on missing, failed and unreadable flags

Every typed accessor SHALL return the caller default, with reason `ERROR` and the error code below, when:

| Situation | Error code |
| --- | --- |
| The key is absent from the evaluated flags | `FLAG_NOT_FOUND` |
| A client SDK has no flag state yet: no response, no persisted flags and no bootstrap | `PROVIDER_NOT_READY` |
| A known field of the flag's record has the wrong JSON type, or the record is not an object | `PARSE_ERROR` |
| The record has reason code `missing_group_key` (config version 2) | `INVALID_CONTEXT` |
| The record is marked `failed` (any config version) | `GENERAL` |

A failed record's `reason.description` SHALL become the error message. An unreadable record SHALL fail only that flag; other flags in the same response SHALL stay readable. The caller default wins over any configured flag default in these cases.

#### Scenario: Absent flag returns the caller default
- **GIVEN** the evaluated flags do not contain "typo-flag"
- **WHEN** the boolean details accessor is called for "typo-flag" with caller default true
- **THEN** the details value is true
- **AND** the error code is `FLAG_NOT_FOUND` and the reason is `ERROR`

#### Scenario: Failed flag returns the caller default with its description
- **GIVEN** the record for "checkout-flow-child" has `failed: true`, value `null` and reason code `dependency_error` with description "Dependency 'checkout-flow' could not be resolved"
- **WHEN** the boolean details accessor is called for "checkout-flow-child" with caller default true
- **THEN** the details value is true
- **AND** the error code is `GENERAL`
- **AND** the error message is "Dependency 'checkout-flow' could not be resolved"

#### Scenario: A malformed record does not affect its siblings
- **GIVEN** a response whose record for "broken" has an array as its value
- **AND** whose record for "healthy" has the string value "Hello"
- **WHEN** the string details accessors are called for both keys with caller default "x"
- **THEN** "broken" returns "x" with error code `PARSE_ERROR`
- **AND** "healthy" returns "Hello" with no error code

#### Scenario: Client read before any flag state exists
- **GIVEN** a client SDK with no bootstrap and no persisted flags has not received a flags response
- **WHEN** the string details accessor is called for "banner-copy" with caller default "Welcome"
- **THEN** the details value is "Welcome"
- **AND** the error code is `PROVIDER_NOT_READY`

### Requirement: Evaluation details object

The details form SHALL return an object with these fields. Field names SHALL be the same in every SDK, adapted to the language's casing (`error_code` / `errorCode`):

| Field | Content |
| --- | --- |
| `key` | The flag key passed to the accessor. |
| `value` | The resolved value, or the caller default. |
| `variant` | The record's `metadata.variant_key` when the accessor returned the flag's value and the record has one. Absent when an error code is set. |
| `reason` | The OpenFeature reason from the table below, as a string. |
| `error_code` | An OpenFeature error code, or absent. |
| `error_message` | Human-readable detail for the error code, or absent. |
| `flag_metadata` | A map with string keys and boolean, string or number values, taken from the record. |

`reason` SHALL use the OpenFeature reason vocabulary. The first matching row applies:

| Source | `reason` |
| --- | --- |
| The details carry an error code (including any failed record) | `ERROR` |
| Client-side override | `override` (a custom reason) |
| Bootstrapped value | `CACHED` |
| Reason code `flag_disabled` (local definitions only) | `DISABLED` |
| Config version 2 reason code `targeting_match` | `TARGETING_MATCH` |
| Config version 2 reason code `experiment_split` | `SPLIT` |
| Config version 2 reason codes `rollout_miss`, `experiment_paused`, `holdout`, `no_rule_match` | `DEFAULT` |
| Any other config version 2 reason code | `UNKNOWN` |
| Config version 1 record whose value is `true` or a string | `TARGETING_MATCH` |
| Config version 1 record with any other value | `DEFAULT` |

The config version 2 rows are the public contract's OpenFeature mapping. The config version 1 rows match what PostHog's OpenFeature providers report today.

`error_code` SHALL be one of the OpenFeature codes `FLAG_NOT_FOUND`, `PARSE_ERROR`, `TYPE_MISMATCH`, `INVALID_CONTEXT`, `PROVIDER_NOT_READY` or `GENERAL`. The SDK SHALL NOT add PostHog-specific error codes; the fine-grained cause stays in `flag_metadata.reason_code`.

`flag_metadata` SHALL contain each of these keys that the record carries, with its wire name in every language: `id`, `version`, `config_version`, `reason_code`, `condition_index`, `rule_type`, `rule_id`, `experiment_id`, `variant_key`, `holdout_id`. `reason_code` and `condition_index` come from the record's `reason`; the others come from its `metadata`. Absent or `null` fields SHALL be omitted. The map SHALL be present, possibly empty, on every details object. It SHALL NOT contain the payload, assignment seeds or the human-readable reason description.

#### Scenario: Details of an experiment split
- **GIVEN** the record for "checkout-flow" has value true, reason code `experiment_split`, condition index 1, and metadata id 123, version 8, config version 2, rule type `experiment`, rule id "6bb788aa-df76-4a77-8bed-9f247e279ccd", experiment id 456 and variant key "test"
- **WHEN** the boolean details accessor is called for "checkout-flow" with caller default false
- **THEN** the details are:
  | field         | value         |
  | key           | checkout-flow |
  | value         | true          |
  | variant       | test          |
  | reason        | SPLIT         |
  | error_code    | absent        |
- **AND** `flag_metadata` contains `reason_code` "experiment_split", `condition_index` 1, `id` 123, `version` 8, `config_version` 2, `rule_type` "experiment", `rule_id` "6bb788aa-df76-4a77-8bed-9f247e279ccd", `experiment_id` 456 and `variant_key` "test"

#### Scenario: Details of a null flag default
- **GIVEN** the record for "banner-copy" has value `null`, reason code `no_rule_match` and config version 2
- **WHEN** the string details accessor is called for "banner-copy" with caller default "Welcome"
- **THEN** the details value is "Welcome"
- **AND** the reason is `DEFAULT` and there is no error code
- **AND** `flag_metadata.reason_code` is "no_rule_match"

#### Scenario: Details of a type mismatch keep the record's metadata
- **GIVEN** the config version 1 record for "legacy-layout" has value "compact", reason code `condition_match` and variant key "compact"
- **WHEN** the boolean details accessor is called for "legacy-layout" with caller default false
- **THEN** the details value is false
- **AND** the reason is `ERROR` and the error code is `TYPE_MISMATCH`
- **AND** the details have no variant
- **AND** `flag_metadata` contains `config_version` 1 and `reason_code` "condition_match"

### Requirement: Typed values come from the v3 flags response

An SDK that implements typed accessors SHALL request the `/flags` response version that carries typed values (`v=3`) and SHALL read each record by the reader rules of the public wire contract (`contracts/feature_flag_rules_v2` in `posthog-sdk-test-harness`). It SHALL keep each flag's typed value, structured reason and metadata with the evaluated flag state instead of reducing the record to a legacy value.

A record without a `value` member comes from a server that does not send typed values. The SDK SHALL then use the record's `variant` as the value, or its `enabled` boolean when there is no variant, SHALL read the config version as 1, and SHALL ignore any rule or experiment metadata in that record. It SHALL NOT mix this reading with v3 fields in one record. Consequences the SDK SHALL document:

- Number and object values reach such a server's records only as a payload, so the number and object accessors return the caller default with `TYPE_MISMATCH`. The error message SHALL say that the value may need a server that sends typed values.
- A `null` flag default reaches such a server's records as `enabled: false`, so the boolean accessor returns `false`, not the caller default.

The SDK SHALL log one diagnostic per client instance the first time it reads a record without `value`, and SHALL NOT probe, retry or cache server capabilities to avoid it.

A client SDK that persists flag state SHALL persist the typed value and details with it, so a typed read from restored state returns the same result as from the response that produced it. State persisted by an SDK version that stored no typed values SHALL be read like a record without `value`.

#### Scenario: Record from an older server
- **GIVEN** the record for "legacy-layout" has `enabled: true`, `variant: "compact"` and no `value`
- **WHEN** the string details accessor is called for "legacy-layout" with caller default "grid"
- **THEN** the details value is "compact"
- **AND** `flag_metadata.config_version` is 1

#### Scenario: Number flag on an older server
- **GIVEN** the record for "upload-limit" has `enabled: true`, no variant, the payload "25" and no `value`
- **WHEN** the number details accessor is called for "upload-limit" with caller default 10
- **THEN** the details value is 10
- **AND** the error code is `TYPE_MISMATCH`
- **AND** the payload accessor for "upload-limit" still returns 25

#### Scenario: The typed value wins over legacy fields in one record
- **GIVEN** a record for "garden-layout" has `value: false` and also carries `enabled: true` and `variant: "wrong-channel"`
- **WHEN** the boolean value accessor is called for "garden-layout" with caller default true
- **THEN** it returns false

### Requirement: Legacy accessors keep their return values

Every accessor that existed before typed values SHALL return what it returned for the same flag before `v=3`, regardless of whether the SDK read a v3 record or an older record. The SDK SHALL derive this legacy rendering from the typed value in one place:

| Typed value | Enablement | Legacy value (`getFeatureFlag`, `getFlag`) | Payload accessor |
| --- | --- | --- | --- |
| `true` | `true` | `true` | the record's payload |
| `false` | `false` | `false` | the record's payload |
| `null` | `false` | `false` | none |
| string | `true` | the string, as the variant | the record's payload |
| number or object | `true` | `true` | the value |

A `failed` record SHALL keep its existing legacy rendering. The same rendering SHALL feed every legacy surface: `isFeatureEnabled`, `getFeatureFlag`, `getFeatureFlagPayload`, `getFeatureFlagResult`, the bulk getters, the snapshot's enablement, value and payload accessors, `$feature/<key>` and `$active_feature_flags` on captured events, `onFeatureFlags` callbacks and bootstrap export.

A v3 record leaves `metadata.payload` `null` for a config version 2 number or object flag. The SDK SHALL supply the value itself to the payload accessors, in the same representation the platform uses for a decoded payload. Config version 1 payloads keep their existing source and decoding.

Documentation SHALL present the typed accessors as the recommended way to read flag values in new code and the only way to read config version 2 number and object values without the payload accessor. This capability does not deprecate any legacy accessor.

#### Scenario: Number flag on legacy accessors
- **GIVEN** the record for "upload-limit" has the number value 25 and config version 2
- **WHEN** the legacy accessors are called for "upload-limit"
- **THEN** enablement is true
- **AND** the legacy value is true
- **AND** the payload accessor returns 25
- **AND** the number value accessor with caller default 10 returns 25

#### Scenario: Null value on legacy accessors
- **GIVEN** the record for "banner-copy" has value `null` and reason code `no_rule_match`
- **WHEN** the legacy accessors are called for "banner-copy"
- **THEN** enablement is false and the legacy value is false
- **AND** the payload accessor returns the platform's no-payload value

#### Scenario: Legacy results do not depend on the response version
- **GIVEN** a server returns the same evaluation once as a v3 record and once as an older record
- **WHEN** every legacy accessor is called for that flag after each response
- **THEN** both responses give the same legacy results and the same `$feature_flag_called` properties

### Requirement: Bootstrapped and overridden values

A typed accessor SHALL read a bootstrapped flag value (see `bootstrap`) as a typed value: a boolean as a boolean and a string as a string. The details SHALL have reason `CACHED`, no variant and empty `flag_metadata`. The bootstrap format is unchanged: a number or object flag can only be bootstrapped through its legacy rendering, so the number and object accessors return the caller default with `TYPE_MISMATCH` until a flags response replaces the bootstrapped value.

A typed accessor SHALL read a client-side override in the same way, with reason `override` and empty `flag_metadata`. An override is never reported as `TARGETING_MATCH`.

#### Scenario: Bootstrapped string value
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "banner-copy": "Hello" }`
- **WHEN** the string details accessor is called for "banner-copy" with caller default "Welcome" before any flags response
- **THEN** the details value is "Hello"
- **AND** the reason is `CACHED` and `flag_metadata` is empty

### Requirement: Locally evaluated flags

A server SDK that evaluates config version 1 flags locally SHALL resolve typed reads of those results by the same rules, taking the value as the variant, or the boolean result when there is no variant. The details SHALL have `config_version` 1 in `flag_metadata` and the reason derived for config version 1 records. A flag whose local definition is inactive SHALL read as its existing inactive result, `false`, with reason `DISABLED`. Local evaluation of config version 2 flags is not part of this capability.

#### Scenario: Locally evaluated multivariate flag
- **GIVEN** local evaluation resolves "legacy-layout" for distinct id "user-123" to variant "compact"
- **WHEN** `evaluateFlags("user-123")` is called and the string details accessor is called for "legacy-layout" with caller default "grid"
- **THEN** the details value is "compact"
- **AND** the reason is `TARGETING_MATCH` and `flag_metadata.config_version` is 1

### Requirement: OpenFeature providers wrap the details accessors

A PostHog OpenFeature provider SHALL build its resolution details from the SDK's details accessors: OpenFeature `value`, `variant`, `reason`, `errorCode`, `errorMessage` and `flagMetadata` come from the matching details fields without remapping. A provider for a server SDK SHALL evaluate through `evaluateFlags(...)` scoped to the requested key, or through equivalent single-flag typed methods.

A provider that has released coercions for config version 1 flags (boolean as enabled, number parsed from the variant, object from the payload) MAY keep them for config version 1 flags until its next major release. It SHALL NOT apply them to config version 2 flags.

#### Scenario: Provider passes details through
- **GIVEN** a server SDK snapshot where "banner-copy" has the string value "Hello" with reason code `targeting_match`
- **WHEN** an OpenFeature client resolves "banner-copy" as a string with default "Welcome" through the PostHog provider
- **THEN** the OpenFeature evaluation details have value "Hello", reason `TARGETING_MATCH` and flag metadata `reason_code` "targeting_match"
