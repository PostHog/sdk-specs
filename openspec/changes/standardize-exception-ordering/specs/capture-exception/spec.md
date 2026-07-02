# Capture Exception Delta: Standardize Exception Ordering

## ADDED Requirements

### Requirement: Stack frame ordering

Within each `$exception_list[].stacktrace.frames` array, the SDK SHALL order frames bottom-up:
`frames[0]` MUST be the outermost frame (the entry point — the oldest call) and the last
element MUST be the innermost frame (the crash site). SDKs whose runtime yields
innermost-first (crash-first) stacks MUST reverse the frames before building the payload.

> Note (non-normative): bottom-up matches the majority of PostHog's current event volume and
> is the order the ingestion pipeline's fingerprinting and inline-frame expansion assume.

#### Scenario: Frames are ordered entry point first, crash site last (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the test exception is raised through the call chain "main" → "handler" → "boom"
- **WHEN** capture exception is called for the exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the first frame of the enqueued exception's stacktrace should reference "main"
- **AND** the last frame of the enqueued exception's stacktrace should reference "boom"

#### Scenario: Crash-first runtime stacks are reversed before sending (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the platform runtime reports exception stacks innermost-first (crash site first)
- **WHEN** capture exception is called for an exception with stack information
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued exception's stacktrace frames should be in the reverse of the runtime
  order, with the crash site as the last frame

### Requirement: Exception list ordering

The SDK SHALL order `$exception_list` outermost-first: `$exception_list[0]` MUST be the
exception the SDK caught (the outermost/wrapping exception), and each cause/inner/wrapped
exception MUST be appended after its wrapper in unwrap order, so the root cause is the last
element. SDKs on platforms without exception chaining SHALL send a single-element list.

#### Scenario: Chained exceptions are listed caught-first, root cause last (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the test exception "WrapperError" wraps a cause "RootError"
- **WHEN** capture exception is called for the caught "WrapperError"
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event's exception list should have "WrapperError" at index 0
- **AND** the enqueued event's exception list should have "RootError" as the last element

#### Scenario: Platforms without exception chaining send a single-element list (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the platform has no exception cause/chain concept
- **WHEN** capture exception is called for an exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event's exception list should contain exactly one exception

### Requirement: Source context line ordering

For SDKs that attach source context to stack frames, each frame's context SHALL use the fields
`context_line` (string — the frame's own source line), `pre_context` (array of strings — lines
before the frame's line), and `post_context` (array of strings — lines after the frame's
line). Both arrays MUST be in file order (ascending line numbers): `pre_context[0]` is the
furthest line before the frame's line and the last element of `pre_context` is the line
immediately above `context_line`; `post_context[0]` is the line immediately after
`context_line` and the last element of `post_context` is the furthest line after. Source
context is OPTIONAL per frame; SDKs that do not capture source context omit these fields. The
RECOMMENDED window is 5 lines on each side; receivers MAY truncate longer windows (the
ingestion pipeline caps at 10 per side).

#### Scenario: Context arrays are in ascending file order (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK attaches source context with a 5-line window
- **WHEN** capture exception is called for an exception raised at line 40 of a source file
- **THEN** one event named "$exception" should be enqueued
- **AND** the crash-site frame's "context_line" should be the source line 40
- **AND** the crash-site frame's "pre_context" should be source lines 35 through 39 in
  ascending order
- **AND** the crash-site frame's "post_context" should be source lines 41 through 45 in
  ascending order

#### Scenario: Frames without source context are valid (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK does not capture source context
- **WHEN** capture exception is called for an exception with stack information
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued exception's stacktrace frames should omit "context_line",
  "pre_context", and "post_context"
