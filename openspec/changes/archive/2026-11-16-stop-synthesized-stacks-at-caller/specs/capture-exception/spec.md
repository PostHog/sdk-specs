## ADDED Requirements

### Requirement: Synthesized stacks stop at the application call site

When the SDK synthesizes a current stack for an exception — the case `exception-event-metadata`
marks with `mechanism.synthetic` equal to `true` — that stack SHALL end at the application frame
that called the public exception-capture API. In the canonical bottom-up order defined by "Stack
frame ordering", the last frame SHALL be the application call site, and the SDK's own
capture-path frames SHALL NOT follow it. This holds in every build configuration the SDK
supports, including a stripped build, an optimized build that inlines the capture path, and a
build that links the SDK statically into the application, so the SDK MUST NOT rely on a fixed
frame count or on its own binary carrying a distinct name. A language-bridge frame that sits
between the caller and the SDK and that the SDK cannot identify at runtime MAY remain; the SDK
SHALL remove it when it can identify it.

This requirement does not change stacks taken from a runtime exception, traceback, or crash
report: those keep their own frames under "Stack trace preservation over synthesis". It does not
change frame order, which "Stack frame ordering" defines.

#### Scenario: A synthesized stack ends at the caller (@both)
- **GIVEN** an initialized SDK with a valid distinct id
- **AND** an application function that calls the public exception-capture API with an input that
  carries no usable stack
- **WHEN** that application function is called
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued exception's `mechanism.synthetic` should be `true`
- **AND** the last frame of the enqueued exception's stacktrace should reference that application
  function
- **AND** no frame of the enqueued exception's stacktrace should reference the SDK's
  exception-capture internals

#### Scenario: A convenience overload does not add an SDK frame (@both)
- **GIVEN** an initialized SDK with a valid distinct id
- **AND** the SDK exposes more than one public exception-capture entry point for the same input
- **AND** an application function that calls one of them with an input that carries no usable stack
- **WHEN** that application function is called
- **THEN** one event named "$exception" should be enqueued
- **AND** the last frame of the enqueued exception's stacktrace should reference that application
  function, with no additional frame contributed by one entry point delegating to another
