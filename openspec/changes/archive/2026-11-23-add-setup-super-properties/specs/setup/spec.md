## ADDED Requirements

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
