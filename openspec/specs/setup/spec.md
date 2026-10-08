# Setup Specification

## Purpose

`setup` initializes a client SDK instance so it can begin persisting state, enriching events, loading feature/config state, and sending analytics to PostHog.

This is the entry point that turns a configured-but-inactive SDK into a usable runtime instance.

Depending on the SDK, setup may:

- validate and store API/host configuration
- create persistence/storage backends
- create transport, queue, retry, and session components
- restore cached identity / flags / config state
- start lifecycle hooks, workers, or timers
- preload feature flags, remote config, surveys, replay, or error tracking integrations

## Applicability

`client` — this is a client-side initialization surface. Server SDKs generally use constructors or per-call clients, but the audited behavior here is the long-lived client/mobile/browser setup path.

## Public signatures

### Canonical client signature

```ts
setup(config: ClientSetupConfig): void | Promise<void> | Client
```

Where `ClientSetupConfig` contains the project token plus runtime options such as host, persistence, batching, privacy, feature flags, replay, surveys, debugging, and integration settings.

### Surface variants

- **browser:** `posthog.init(token, config?, name?) -> PostHog`
- **react-native:** `new PostHog(apiKey, options?) -> PostHog`, with async readiness continuing after construction (`ready(): Promise<void>`)
- **iOS:** `setup(config)`
- **Android:** `setup(config)`
- **Flutter:** `setup(config): Future<void>`
- **Unity:** `PostHogSDK.Setup(config)` / `PostHog.Setup(config)`

The configuration object names the project credential `projectToken` on iOS, Android, Flutter, and KMP, and `ProjectToken` on .NET. posthog-js has not adopted the name: browser takes the token positionally and React Native still calls the constructor parameter `apiKey`.

`setup` is the canonical name here because it is the dominant public naming across the native/mobile SDKs, even though browser uses `init(...)` and React Native commonly uses a constructor/provider surface.

## Behavior

1. **Validate required configuration.**
   - The SDK requires a project token and accepts a host plus optional runtime settings.
   - The SDKs that renamed the option to `projectToken` trim leading and trailing whitespace from the configured value before storing it.
   - Invalid or missing config is handled SDK-specifically: some SDKs log and no-op, while others throw on obviously invalid input.
2. **Prevent accidental double initialization.**
   - Most audited SDKs treat repeated setup of the same singleton/instance as a no-op with logging/warnings.
   - Browser is the main exception: it can also initialize distinct named instances via `init(token, config, name)`.
3. **Store config and establish initial diagnostic state.**
   - Setup records the chosen config and often applies initial debug/logging settings immediately.
4. **Initialize or bind core subsystems.**
   - Common components created during setup include persistence/storage, HTTP/API transport, event queues, retry state, session state, remote-config/feature-flag managers, and identity helpers.
   - Wrapper SDKs may delegate this work to an underlying platform SDK instead of owning every component directly.
5. **Restore persisted local state.**
   - Setup commonly reloads previously-stored identity, consent/opt-out state, super properties, cached feature flags, or cached remote config so early calls use consistent local state.
6. **Start runtime workers and lifecycle hooks.**
   - Queues, timers, background/foreground hooks, session managers, flush-on-background hooks, or callback wiring are activated.
7. **Activate optional integrations and preload work.**
   - Depending on configuration, setup may start or schedule remote config loads, feature-flag preloads, surveys, replay, and error tracking integrations.
   - Some SDKs gate integration installation on current opt-out state.
8. **Expose a usable client, though full readiness may lag.**
   - Some SDKs are effectively ready when setup returns.
   - Others continue asynchronous initialization after the public call returns. React Native continues through storage preload and follow-up remote-config/flag work, and browser finishes certain steps in its later `_loaded()` path.
   - Flutter Web is a special wrapper case: its `setup(config)` binds callbacks/config to an already-existing browser SDK instance rather than fully initializing `posthog-js` itself.

## State & lifecycle

### State read

- project token and host
- runtime config for persistence, batching, replay, surveys, feature flags, privacy, and debugging
- previously-persisted identity / super properties / opt-out state / cached flags / remote config
- existing singleton or named-instance registry state

### State written

- enabled / initialized state
- stored runtime config
- initialized component references (storage, queues, transport, session manager, integrations)
- restored local identity/consent/cache state
- callback registrations and lifecycle subscriptions

### Lifecycle behavior

- Setup is normally called once per process/client instance.
- Repeated setup on an already-enabled singleton usually logs and returns without reinitializing.
- Browser can create separate named instances; most native/mobile SDKs instead require `shutdown()` / `close()` / `Shutdown()` before a fresh reinitialization.
- Setup often begins background work immediately, but not all follow-up work completes before the public call returns.
- Wrapper SDKs can have mixed lifecycle ownership. Flutter stores wrapper config locally, installs Dart-side integrations, and delegates platform setup; Flutter Web primarily attaches to an already-initialized browser client.

## Error handling

- Setup should not crash in normal misconfiguration cases.
- Missing/invalid config may be logged and ignored, or rejected early with an exception, depending on SDK.
- Individual integration-install or preload failures are commonly logged and isolated so the whole SDK can continue in a partially-initialized state.
- Promise-returning setup surfaces resolve after the setup/delegation path completes, not necessarily after all later preload/network work finishes.

## Concurrency & ordering guarantees

- Setup is serialized by singleton locks, setup locks, or constructor-time sequencing in the audited SDKs.
- After setup completes, later API calls observe initialized component state.
- If public APIs are called before setup finishes, behavior is SDK-specific: some log and ignore, while others expose a separate readiness concept (for example React Native's `ready()`).
- Repeated concurrent setup attempts generally collapse to one initialized instance plus warnings/no-ops, except browser named-instance creation which intentionally supports multiple separately-named instances.

## Interactions

- **persistent storage** — created or bound during setup, then used to restore identity, super properties, consent, and caches.
- **retry-queue / event-batcher / http-client** — created or configured during setup so later capture calls can send data.
- **session-manager** — usually started during setup so later events have session context.
- **remote-config / feature flags** — setup may restore cached state and/or trigger initial loads.
- **consent-gating** — restored opt-out state can change whether integrations are installed and whether capture is allowed.
- **debug** — setup commonly applies initial debug/logging settings from config.
- **shutdown** — tears down the state created by setup and, in many SDKs, is the path required before reinitializing.

## Requirements

### Requirement: Canonical setup behavior

The SDK SHALL implement the canonical `setup` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Setup initializes storage transport queue and identity state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with token "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **AND** persistent storage should be available
- **AND** the event queue should be available
- **AND** get distinct id should return a non-empty value

#### Scenario: Setup restores persisted local state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains anonymous id "anon-123"
- **AND** persistent storage contains registered properties:
  | property | value |
  | plan     | pro   |
- **WHEN** setup is called with token "test-token" and host "https://mock.posthog.test"
- **THEN** get anonymous id should return "anon-123"
- **AND** registered property "plan" should equal "pro"

#### Scenario: Repeated setup does not duplicate singleton state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** setup is called with token "test-token" and host "https://mock.posthog.test"
- **WHEN** setup is called again with token "test-token" and host "https://mock.posthog.test"
- **THEN** exactly one active SDK instance should exist for the default name
- **AND** lifecycle observers should be installed at most once

### Requirement: Project token configuration option name

The project credential a client SDK is configured with is a PostHog project token, not an API key. The SDK SHALL name the configuration option carrying it `projectToken`, adapted to platform casing — `ProjectToken`, or `com.posthog.posthog.PROJECT_TOKEN` for a manifest or `Info.plist` auto-init key.

#### Scenario: Setup accepts the project token option
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the project token option set to "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"

### Requirement: Deprecated project credential alias

An SDK that previously named the project token option `apiKey` SHALL keep the old name as a deprecated alias rather than removing it in the same release. The alias SHALL resolve to the same value, SHALL be marked deprecated in whatever way the platform expresses deprecation, and SHALL log a warning naming `projectToken` as the replacement. The alias MAY be removed in the SDK's next major version. When both names are supplied, `projectToken` SHALL win.

#### Scenario: Deprecated alias configures the same token and warns (@legacy_token_alias)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the deprecated project credential option set to "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **AND** a deprecation warning naming the project token option should be logged
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"

#### Scenario: Project token option wins over the deprecated alias (@legacy_token_alias)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the project token option set to "new-token" and the deprecated project credential option set to "old-token"
- **THEN** the SDK should be initialized
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "new-token"

### Requirement: Project token rename stops at the public configuration surface

Renaming the option SHALL NOT change anything below the public configuration surface. Wire payload fields (`api_key`, `token`) keep their names and carry the same value, and persisted queue and preference paths are unchanged so data stored before the rename survives the upgrade. Positional first-argument constructors are unaffected, because the parameter name is not part of the call.

#### Scenario: Setup reads a queue persisted before the rename
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains a queued event named "Earlier" written before the rename
- **WHEN** setup is called with the project token option set to "test-token" and host "https://mock.posthog.test"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"
- **AND** the batch should contain an event named "Earlier"
