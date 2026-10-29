## ADDED Requirements

### Requirement: Typed reads share the flag-called event

A typed value or details read (see `typed-flag-values`) that would emit `$feature_flag_called` SHALL emit the same event, through the same tracker, as a legacy value read of the same flag in the same evaluation context:

- `$feature_flag_response` SHALL be the legacy rendering of the flag's value (`true`, `false` or the variant string), never a number, an object, `null` or the caller default. A number or object value is reported as `true`, and a `null` value as `false`.
- The dedupe key SHALL be the existing one: flag key, legacy rendering, and the distinct id and canonical group context where the SDK includes them. A typed read and a legacy read of the same flag and value therefore dedupe together, in either order.
- Returning the caller default because of a `null` value, a `false` value read as another type, or a type mismatch SHALL NOT change the event. `TYPE_MISMATCH` is not an evaluation error and SHALL NOT be reported in `$feature_flag_error`.
- Missing and failed flags SHALL be reported as the SDK reports them for a legacy read.
- Event opt-out, per-call suppression and minimal-event mode SHALL apply to typed reads as they apply to legacy reads.
- The value form and the details form of an accessor SHALL emit the same event for the same read.
- A repeated typed read of the same flag and value SHALL NOT emit a second event while the dedupe tracker holds its key.

This requirement does not add properties to `$feature_flag_called`. The rule and experiment attribution properties of the public wire contract, and any change to the dedupe key that they need, belong to the change that adds `$experiment_exposure`. That change SHALL treat a typed read like a legacy read of the same flag: a read that returned the caller default because of a `null` value, a `false` value read as another type, or a type mismatch still reports the assignment the flag's record carries.

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

#### Scenario: Type mismatch still reports the flag's own value
- **GIVEN** flag "legacy-layout" has the value "compact"
- **WHEN** the boolean value accessor is called for "legacy-layout" with caller default false
- **THEN** it returns false
- **AND** one "$feature_flag_called" event is enqueued with `$feature_flag_response` "compact"
- **AND** the event has no `$feature_flag_error` property
