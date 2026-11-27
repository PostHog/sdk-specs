## ADDED Requirements

### Requirement: Ordered hand-over while a before-send hook can complete asynchronously

In most SDKs the hook chain runs synchronously inside the capture call, so an event is handed to
delivery before the call returns and no later call can overtake it. Where an SDK accepts a hook
that may complete asynchronously (today only posthog-flutter's Dart-layer `beforeSend`, which may
return a `Future`), the SDK SHALL hand calls to the underlying SDK in the order the application
made them, so an event is sent with the distinct ID, registered properties, groups and consent in
force when it was captured.

- While an event's hook chain is running, a later event-producing or state-changing call —
  `capture`, `screen`, `captureException`, `identify`, `alias`, `reset`, `register`, `unregister`,
  `group`, `optIn`, `optOut` — and a later state-reading getter SHALL NOT reach the underlying SDK
  until that event has been handed over.
- A call made from inside a running hook SHALL NOT wait on the hook it runs inside, so a hook that
  calls back into the SDK cannot deadlock. This includes a hook that re-captures, such as one that
  renames a `$screen` event.
- The SDK SHALL bound how long one event holds later calls back (posthog-flutter: 10 seconds,
  measured from the capture rather than per hook, so a chain of never-finishing hooks holds later
  calls for that bound in total). When the bound expires the SDK SHALL release the later calls and
  SHALL still hand the event over when its chain finishes: exceeding the bound is not a drop.
- An SDK whose hook chain is synchronous satisfies this requirement with no queueing of any kind.

posthog-flutter applies ordered hand-over on web and, through the method channel, on iOS, Android
and macOS. Its Dart-only Windows and Linux path does not. Making the hook synchronous removes the
window this requirement describes, and is the convergent answer where an SDK can take it.

#### Scenario: An event keeps the user it was captured under
- **GIVEN** the SDK accepts a before-send hook that completes asynchronously
- **AND** the SDK is initialized with token "test-token" and identified as "user-a"
- **AND** before-send is configured with a hook that completes asynchronously
- **WHEN** capture is called with event "Logged Out" without awaiting it
- **AND** reset is called immediately afterwards
- **THEN** the enqueued "Logged Out" event distinct ID should equal "user-a"
- **AND** the reset should take effect only after that event has been handed over

#### Scenario: A hook that captures does not deadlock
- **GIVEN** the SDK accepts a before-send hook that completes asynchronously
- **AND** the SDK is initialized with token "test-token"
- **AND** before-send is configured with a hook that itself calls capture with event "From Hook"
- **WHEN** capture is called with event "Checkout Started"
- **THEN** one event named "Checkout Started" should be enqueued
- **AND** one event named "From Hook" should be enqueued

#### Scenario: A hook past the bound releases later calls and still sends its event
- **GIVEN** the SDK accepts a before-send hook that completes asynchronously
- **AND** the SDK is initialized with token "test-token"
- **AND** before-send is configured with a hook that has not completed after the SDK's bound
- **WHEN** capture is called with event "Slow Event" without awaiting it
- **AND** capture is called with event "Later Event"
- **THEN** the "Later Event" event should be handed over once the bound has expired
- **AND** the "Slow Event" event should be handed over when its hook completes
- **AND** the "Slow Event" event should not be dropped
