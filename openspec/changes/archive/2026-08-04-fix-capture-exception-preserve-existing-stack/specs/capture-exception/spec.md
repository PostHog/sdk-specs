# Capture Exception Delta: Preserve Existing Stack Over Synthesis

## ADDED Requirements

### Requirement: Stack trace preservation over synthesis

When the supplied error-like input already carries stack trace information (for example an
`Error` instance with a native stack, or an object with an existing `stack`/`stacktrace`
string), the SDK SHALL preserve and use that existing stack when building the exception
payload's `stacktrace.frames`, rather than discarding it in favor of a stack synthesized from
other available metadata (such as the message or a source location). Synthesizing frames from
location metadata is appropriate only when the input carries no genuine stack trace.

#### Scenario: An existing stack trace is preserved, not replaced by a synthesized one (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the test exception is an error-like object with a message and a pre-existing
  multi-frame stack trace string
- **WHEN** capture exception is called for the exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued exception's stacktrace frames should reflect the pre-existing stack
  trace, not a synthesized single-frame stack
