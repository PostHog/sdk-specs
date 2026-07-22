## MODIFIED Requirements

### Requirement: Canonical is-feature-enabled behavior

The SDK SHALL implement the canonical `is-feature-enabled` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

The SDK SHALL accept a caller-supplied boolean default (`defaultValue`; parameter casing and placement per platform idiom — e.g. `{ default_value }` in posthog-js options, `{ defaultValue }` in posthog-js core / react-native / js-lite options, a positional `defaultValue` on Android and Unity) and SHALL return it whenever the flag has no value: flags not loaded yet, a failed flags request, or no flag with that key in the loaded flags. A flag that has a value — including `false` and variant strings — always wins over the caller-supplied default.

Allowed variation for the no-default call: SDKs whose signature builds in a `false` default (Android, Unity) or hard-code `false` for missing values (iOS, Flutter) resolve missing flags to `false` by construction. SDKs whose boolean API is three-state (`boolean | undefined` — the posthog-js family) SHALL keep returning `undefined`/nullish when the caller supplies no default; collapsing that bare call to `false` is a breaking change reserved for their next major.

#### Scenario: Enabled check maps flag values to booleans (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value        |
  | feature | <flag_value> |
- **WHEN** is feature enabled "feature" is called
- **THEN** the returned enabled value should be <enabled>
  Examples:
  | flag_value | enabled |
  | true       | true    |
  | false      | false   |
  | variant-a  | true    |

#### Scenario: Enabled check resolves missing flags to the default (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are empty
- **WHEN** is feature enabled "missing" is called with default value <default>
- **THEN** the returned enabled value should be <default>
  Examples:
  | default |
  | false   |
  | true    |

#### Scenario: Enabled check prefers the flag value over the caller default (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value        |
  | feature | <flag_value> |
- **WHEN** is feature enabled "feature" is called with default value <default>
- **THEN** the returned enabled value should be <enabled>
  Examples:
  | flag_value | default | enabled |
  | false      | true    | false   |
  | variant-a  | false   | true    |

#### Scenario: Enabled check can suppress tracking (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | feature | true  |
- **WHEN** is feature enabled "feature" is called with tracking disabled
- **THEN** the returned enabled value should be true
- **AND** no event named "$feature_flag_called" should be enqueued
