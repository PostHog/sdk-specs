## ADDED Requirements

### Requirement: Typed reads share the flag-called event

A typed value or details read (see `typed-flag-values`) that would emit `$feature_flag_called` SHALL emit the same event, through the same tracker, as a legacy value read of the same flag in the same evaluation context, unless it returns the caller default with `TYPE_MISMATCH`:

- `$feature_flag_response` SHALL be the legacy rendering of the flag's value (`true`, `false` or the variant string), never a number, an object or the caller default. A number or object value is reported as `true`, and a `null` value as `false`. A missing key keeps the legacy accessors' `null` response.
- The dedupe key SHALL be the key a legacy read of the same flag uses: the flag key, the legacy rendering, and the distinct id and canonical group context where the SDK includes them, together with any config version 2 attribution the tracker adds to the key. A typed read and a legacy read of the same flag and outcome therefore dedupe together, in either order.
- Returning the caller default because of a `null` value or a `false` value read as another type SHALL NOT change the event.
- A read that returns the caller default with `TYPE_MISMATCH` SHALL NOT emit the event and SHALL NOT consult or update the tracker, so the next read of the flag with the right type emits it. The SDK logs the mismatch instead (see `typed-flag-values` "Type mismatches are logged, not reported").
- Missing and failed flags SHALL be reported as the SDK reports them for a legacy read.
- Event opt-out, per-call suppression and minimal-event mode SHALL apply to typed reads as they apply to legacy reads.
- The value form and the details form of an accessor SHALL emit the same event for the same read.
- A repeated typed read of the same flag and value SHALL NOT emit a second event while the dedupe tracker holds its key.

This requirement does not add properties to `$feature_flag_called`. The rule and experiment attribution properties of the public wire contract, and any change to the dedupe key that they need, belong to the change that adds `$experiment_exposure`. That change SHALL treat a typed read like a legacy read of the same flag: a read that returned the caller default because of a `null` value or a `false` value read as another type still reports the assignment the flag's record carries. A read that returned it because of a type mismatch reports nothing.

#### Scenario: Typed and legacy reads dedupe together
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key         | value |
  | banner-copy | Hello |
- **WHEN** the string value accessor is called for "banner-copy" with caller default "Welcome"
- **AND** get feature flag "banner-copy" is called
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "banner-copy"
- **AND** the enqueued event properties should include:
  | property               | value       |
  | $feature_flag          | banner-copy |
  | $feature_flag_response | Hello       |

#### Scenario: Value and details forms emit the same event
- **GIVEN** flag "banner-copy" has the string value "Hello"
- **WHEN** the string details accessor is called for "banner-copy" with caller default "Welcome"
- **AND** the string value accessor is called for "banner-copy" with caller default "Welcome"
- **AND** the string details accessor is called for "banner-copy" again
- **THEN** exactly one "$feature_flag_called" event is enqueued for flag "banner-copy"
- **AND** its properties are the same as those a value-form read alone would produce

#### Scenario: Number value is reported with its legacy rendering
- **GIVEN** flag "upload-limit" has the number value 25
- **WHEN** the number value accessor is called for "upload-limit" with caller default 10
- **THEN** one "$feature_flag_called" event is enqueued with `$feature_flag_response` true

#### Scenario: A type mismatch emits no event and reserves nothing
- **GIVEN** flag "legacy-layout" has the value "compact"
- **WHEN** the boolean value accessor is called for "legacy-layout" with caller default false
- **THEN** it returns false
- **AND** no "$feature_flag_called" event is enqueued
- **WHEN** the string value accessor is called for "legacy-layout" with caller default "grid"
- **THEN** it returns "compact"
- **AND** one "$feature_flag_called" event is enqueued with `$feature_flag_response` "compact"

#### Scenario: A null value still emits the event
- **GIVEN** flag "banner-copy" has value `null` and reason code `no_rule_match`
- **WHEN** the string value accessor is called for "banner-copy" with caller default "Welcome"
- **THEN** it returns "Welcome"
- **AND** one "$feature_flag_called" event is enqueued with `$feature_flag_response` false
