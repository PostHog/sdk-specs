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

`both` — the core lifecycle, persistence, and integration narrative below describes the long-lived client/mobile/browser setup path, while cross-SDK initialization requirements (such as **Project token environment variable name** and **Super properties at setup**) also apply to server SDKs.

## Public signatures

### Canonical client signature

```ts
setup(config: ClientSetupConfig): void | Promise<void> | Client
```

Where `ClientSetupConfig` contains the project token plus runtime options such as host, persistence, batching, privacy, feature flags, replay, surveys, debugging, and integration settings.

### Surface variants

- **browser:** `posthog.init(token, config?, name?) -> PostHog`
- **react-native:** `new PostHog(projectToken, options?) -> PostHog`, with async readiness continuing after construction (`ready(): Promise<void>`)
- **iOS:** `setup(config)`
- **Android:** `setup(config)`
- **Flutter:** `setup(config): Future<void>`
- **Unity:** `PostHogSDK.Setup(config)` / `PostHog.Setup(config)`

The configuration object names the project credential `projectToken` on iOS, Android, Flutter, KMP, and React Native (and `ProjectToken` in the .NET server SDK's options). React Native's `PostHogProvider` takes a `projectToken` prop and keeps `apiKey` as a deprecated alias that loses to `projectToken` when both are set. One client SDK has not adopted the name yet: Unity's `PostHogConfig` and `PostHogSettings` expose `ApiKey`. Browser `init(token, …)` and the React Native `new PostHog(projectToken, options?)` constructor take the token positionally, so their parameter name is not part of the contract.

`setup` is the canonical name here because it is the dominant public naming across the native/mobile SDKs, even though browser uses `init(...)` and React Native commonly uses a constructor/provider surface.

## Behavior

1. **Validate required configuration.**
   - The SDK requires a project token and accepts a host plus optional runtime settings.
   - iOS, Android, Flutter, and React Native trim leading and trailing whitespace from the configured value before storing it.
   - Invalid or missing config is handled SDK-specifically: some SDKs log and no-op, while others throw on obviously invalid input.
2. **Prevent accidental double initialization.**
   - Most audited SDKs treat repeated setup of the same singleton/instance as a no-op with logging/warnings.
   - Browser is the main exception: it can also initialize distinct named instances via `init(token, config, name)`.
3. **Store config and establish initial diagnostic state.**
   - Setup records the chosen config and often applies initial debug/logging settings immediately.
4. **Initialize or bind core subsystems.**
   - Common components created during setup include persistence/storage, HTTP/API transport, event queues, retry state, session state, remote-config/feature-flag managers, and identity helpers.
   - Wrapper SDKs may delegate this work to an underlying platform SDK instead of owning every component directly.
5. **Restore persisted local state and apply setup super properties.**
   - Setup commonly reloads previously-stored identity, consent/opt-out state, super properties, cached feature flags, or cached remote config so early calls use consistent local state.
   - If `superProperties` are configured, setup merges them into the super-properties store before bootstrap identity reconciliation and before lifecycle or autocapture integrations are installed.
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

An SDK whose public configuration still names the project token option `apiKey` (or `ApiKey`) SHALL add `projectToken` and keep the old name as a deprecated alias in the same release, so the rename does not require a major version. The alias SHALL resolve to the same value and SHALL be marked deprecated in whatever way the platform expresses deprecation, naming `projectToken` as the replacement: a compile-time deprecation where the platform has one, otherwise a logged warning. An SDK MAY additionally log a runtime warning when the alias is used. The alias MAY be removed only in a major version released after the one that added `projectToken`. Where the configuration surface accepts both names at once — an options object, a provider's props, or a manifest or `Info.plist` key — `projectToken` SHALL win.

#### Scenario: Deprecated alias configures the same token (@legacy_token_alias)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the deprecated project credential option set to "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"

#### Scenario: Project token option wins over the deprecated alias (@both_token_names_capable)
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
- **GIVEN** persistent storage contains a queued event named "Earlier"
- **WHEN** setup is called with the project token option set to "test-token" and host "https://mock.posthog.test"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"
- **AND** the batch should contain an event named "Earlier"

### Requirement: Project token environment variable name

Where an SDK reads the project token from an environment variable — a server SDK initialized without an explicit token, a framework integration's generated configuration, or an executable the SDK ships — the variable SHALL be named `POSTHOG_PROJECT_TOKEN`, the environment spelling of the `projectToken` option name. An SDK that reads the token only from code is conformant: this requirement names the variable, it does not require reading one.

An SDK that already reads `POSTHOG_API_KEY` SHALL add `POSTHOG_PROJECT_TOKEN` and keep the old variable as a deprecated fallback in the same release, under the rules of "Deprecated project credential alias": the fallback resolves to the same value, is documented as deprecated naming `POSTHOG_PROJECT_TOKEN` as the replacement, and MAY be removed only in a major version released after the one that added the new name. `POSTHOG_PROJECT_TOKEN` SHALL win when both are set. A `POSTHOG_PROJECT_TOKEN` that is unset, empty, or only whitespace SHALL fall back as if it were unset, rather than initializing the SDK with a blank token.

An explicit token passed in code SHALL win over both variables.

#### Scenario: The project token environment variable configures the SDK
- **GIVEN** an SDK that reads the project token from the environment
- **AND** `POSTHOG_PROJECT_TOKEN` is set to "test-token"
- **WHEN** setup is called with no project token in code
- **THEN** the SDK should be initialized with project token "test-token"

#### Scenario: The deprecated variable is read only when the new one is blank
- **GIVEN** an SDK that reads the project token from the environment and still supports `POSTHOG_API_KEY`
- **AND** `POSTHOG_PROJECT_TOKEN` is set to "   "
- **AND** `POSTHOG_API_KEY` is set to "old-token"
- **WHEN** setup is called with no project token in code
- **THEN** the SDK should be initialized with project token "old-token"

#### Scenario: The project token variable wins over the deprecated one
- **GIVEN** an SDK that reads the project token from the environment and still supports `POSTHOG_API_KEY`
- **AND** `POSTHOG_PROJECT_TOKEN` is set to "new-token"
- **AND** `POSTHOG_API_KEY` is set to "old-token"
- **WHEN** setup is called with no project token in code
- **THEN** the SDK should be initialized with project token "new-token"

### Requirement: Super properties at setup

Every PostHog SDK (both client and server) SHALL accept an optional map of super properties on its setup or initialization configuration surface, named `superProperties` adapted to platform naming conventions (`super_properties` in Python, PHP, Ruby, Rust, Elixir, Godot, and browser JavaScript; `SuperProperties` in .NET, Go, Unity, and Unreal; `superProperties` in iOS, Android, Flutter, KMP, React Native, Node, Roblox, and Java). An SDK that already ships an equivalent init-time property map under another name (such as Go's `DefaultEventProperties` or Elixir's `global_properties`) SHALL add the canonical name and MAY keep the existing name as a deprecated alias until a subsequent major version; when both are non-empty, the canonical map SHALL win key by key over the deprecated alias (and an absent, `null`, or empty canonical map falls back to the alias). When `superProperties` is absent, `null`, or empty (and no alias is set), initialization SHALL proceed with no super-property side effects.

On a client SDK, during `setup()`, **after** persistent storage is opened and previously persisted super properties are restored, and **before** `bootstrap` identity reconciliation and **before** lifecycle or autocapture integrations are installed, the SDK SHALL merge `config.superProperties` into the SDK's `register()` super-properties store using the same validation, sanitization, reserved-key handling, and persistence semantics as `register(...)`:

- For keys present in `config.superProperties`, the configured value SHALL overwrite any previously persisted value for that key, so launch-time metadata updates before startup events such as `Application Updated` and `Application Opened` are captured.
- Previously persisted super-property keys absent from `config.superProperties` SHALL remain intact.
- Subsequent runtime calls interact with the same store: later `register(...)` calls SHALL override configured keys, `unregister(key)` SHALL remove them, and `reset()` SHALL clear them for the remainder of that session (the next `setup()` re-applies `config.superProperties`).
- Applying `config.superProperties` SHALL NOT emit an event or perform network I/O by itself.
- When a client SDK starts opted out (`optOut: true` or persisted opt-out), `setup()` SHALL still apply `config.superProperties` to the super-properties store (held in memory without writing to persistent storage when consent or configuration disables persistence, per `consent-gating`, and without emitting events) so a subsequent `optIn()` carries them. When `setup()` rejects or no-ops due to invalid configuration (such as a blank project token) or because the singleton is already initialized, `config.superProperties` SHALL NOT be applied.
- Because configured super properties enter the super-properties store rather than mutating already-assembled events, previously persisted queued events and prior-run crash reports restored from disk SHALL retain the properties they were recorded with.
- Wrapper SDKs (such as Flutter and KMP) SHALL forward `config.superProperties` to the underlying native SDK's setup configuration before native setup runs, rather than registering after setup returns or layering a `beforeSend` workaround. Where a wrapper attaches to an already-initialized SDK (such as Flutter Web attaching to `posthog-js`), `setup()` SHALL register the configured properties on the attached instance; callers that need them on the underlying SDK's initial `$pageview` supply `super_properties` directly to `posthog.init(...)`.

On a server SDK, configured super properties SHALL take effect immediately from client initialization on every event produced through the shared capture path (`capture`, `captureException`, `identify` or person-property events, `alias`, `groupIdentify`, and AI/MCP capture where they share that path), subject to `feature-flag-called-tracker`'s minimal-event allowlist and `capture`'s identify-style person-processing rules. Server SDKs without a persistent `register()` store keep configured super properties for the client's lifetime without disk persistence and are not required to expose `reset()`. A server SDK that also exposes runtime `register()` and `unregister()` (such as `posthog-node`) SHALL seed that registry at initialization so runtime mutations interact with configured super properties consistently. On capture v1, server SDKs that accept init-time super properties also follow `capture`'s **Per-event options replace the legacy option properties** rule for global default options (`superOptions` / `super_options` / `SuperOptions`, with any existing name such as Go's `DefaultEventOptions` allowed as a deprecated alias).

Per-event caller properties SHALL take precedence over configured super properties on both client and server SDKs, following `capture`'s **Caller-supplied event properties take precedence** (client: SDK-set properties < super properties < caller event properties) and **Server SDKs build every event in one layer order** (server: SDK-added defaults < configured super properties < ambient request context < caller event properties). A configured `$process_person_profile` follows the same identify-style exclusion rules as `register()` and server global defaults in `capture`, and a configured `token` SHALL NOT override the project token.

Legacy divergences: `posthog-python` 7.x (`super_properties`), `posthog-go` 1.x (`DefaultEventProperties`), `posthog-dotnet` (`SuperProperties`), and `posthog-elixir` (`global_properties`) currently merge configured default properties over per-event caller properties on legacy capture. `posthog-python` 8.0 and `posthog-go` v2 reverse this to caller-wins on capture v1; `.NET` and `Elixir` SHALL converge on caller-wins in their next major releases.

#### Scenario: Setup super properties are available immediately for the first captured event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **WHEN** setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
  | property    | value      |
  | environment | production |
  | app         | consumer   |
- **AND** capture is called with event "First Action"
- **THEN** the enqueued event properties should include:
  | property    | value      |
  | environment | production |
  | app         | consumer   |

#### Scenario: Per-event properties override setup super properties (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **WHEN** setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
  | property    | value      |
  | environment | production |
  | region      | us         |
- **AND** capture is called with event "Override Check" and properties:
  | property    | value   |
  | environment | staging |
- **THEN** the enqueued event properties should include:
  | property    | value   |
  | environment | staging |
  | region      | us      |

#### Scenario: Setup super properties overwrite matching persisted keys while preserving other persisted keys (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains registered properties:
  | property    | value   |
  | environment | staging |
  | plan        | pro     |
- **WHEN** setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
  | property    | value      |
  | environment | production |
- **AND** capture is called with event "Relaunched"
- **THEN** the enqueued event properties should include:
  | property    | value      |
  | environment | production |
  | plan        | pro        |

#### Scenario: Setup super properties apply before bootstrap identity reconciliation (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the existing local user is anonymous with distinct id "anon-abc"
- **WHEN** setup is called with token "test-token", host "https://mock.posthog.test", bootstrap identified distinct id "user-123", and super properties:
  | property    | value      |
  | environment | production |
- **THEN** the enqueued "$identify" event properties should include:
  | property    | value      |
  | environment | production |

#### Scenario: Setup super properties apply when starting opted out without emitting events (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **WHEN** setup is called with token "test-token", host "https://mock.posthog.test", opt-out enabled, and super properties:
  | property    | value      |
  | environment | production |
- **THEN** no events should be enqueued
- **WHEN** opt-in is called
- **AND** capture is called with event "After Consent"
- **THEN** the enqueued "After Consent" event properties should include:
  | property    | value      |
  | environment | production |

#### Scenario: Setup super properties do not mutate events already persisted from a prior launch (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains a queued event named "Prior Crash" with property "environment" equal to "staging"
- **WHEN** setup is called with token "test-token", host "https://mock.posthog.test", and super properties:
  | property    | value      |
  | environment | production |
- **AND** flush is called
- **THEN** the delivered "Prior Crash" event property "environment" should equal "staging"
