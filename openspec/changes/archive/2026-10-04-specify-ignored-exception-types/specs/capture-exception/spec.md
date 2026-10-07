## ADDED Requirements

### Requirement: Ignored exception types

Where an SDK exposes an option that drops `$exception` events by exception type, it SHALL honor
the rules below (`errorTrackingConfig.ignoredExceptionTypes` on posthog-ios and posthog-android).
The option is optional: an SDK that does not expose it is conformant.

Where the option exists:

- It SHALL default to empty, so a default-configured SDK drops nothing.
- A non-empty list SHALL drop the matching `$exception` event before it enters the capture
  pipeline, on **every** path that produces one: manual `capture-exception`, exception
  autocapture and crash reports, and `$exception` events handed to the generic capture API (how
  wrapper SDKs such as the React Native and Flutter bridges report errors).
- Dropping SHALL be silent apart from a debug log, and SHALL NOT throw.
- Matching SHALL consider every exception in the chain (every `$exception_list` entry, or every
  link of the cause chain the SDK would serialize), not only the outermost one, and SHALL be
  case-sensitive.
- The identifier matched on is platform-idiomatic. An SDK holding the live error object MAY match
  the platform error type, in which case a subtype of a listed type matches. An SDK holding only
  the event payload SHALL match the serialized `$exception_list[*].type`, rejoined with the
  entry's `module` where the SDK splits a qualified name across the two fields.

#### Scenario: default configuration drops nothing
- **GIVEN** an SDK configured with defaults
- **WHEN** the app captures any exception
- **THEN** the ignore list is empty and an `$exception` event is captured

#### Scenario: a listed type is dropped
- **GIVEN** the ignore list contains `MyNoisyError`
- **WHEN** the app calls `captureException(MyNoisyError("boom"))`
- **THEN** no `$exception` event enters the capture pipeline

#### Scenario: a listed type nested in the chain is dropped
- **GIVEN** the ignore list contains `MyNoisyError`
- **WHEN** an exception whose cause chain contains `MyNoisyError` is captured
- **THEN** no `$exception` event enters the capture pipeline

#### Scenario: an externally built exception event is dropped
- **GIVEN** the ignore list contains `MyNoisyError`
- **WHEN** a wrapper SDK calls the generic capture API with `$exception` and an `$exception_list`
  entry whose `type` is `MyNoisyError`
- **THEN** no `$exception` event enters the capture pipeline

#### Scenario: matching is case-sensitive
- **GIVEN** the ignore list contains `mynoisyerror`
- **WHEN** an exception of type `MyNoisyError` is captured
- **THEN** the `$exception` event is captured
