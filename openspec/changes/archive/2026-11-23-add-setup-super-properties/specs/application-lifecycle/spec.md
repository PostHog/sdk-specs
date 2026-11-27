## ADDED Requirements

### Requirement: Startup lifecycle events carry setup super properties

Because `setup()` merges configured `superProperties` into the super-properties store before installing the application lifecycle integration (see `setup` — **Super properties at setup**), every startup lifecycle event emitted during `setup()` — `Application Installed`, `Application Updated`, and the initial `Application Opened` — SHALL carry those configured super properties.

On an update launch, keys in `config.superProperties` overwrite any stale previously persisted values for those keys before `Application Updated` and `Application Opened` are captured, while other persisted super properties remain attached. Lifecycle events' own properties (such as `from_background`, `previous_version`, and `previous_build`) retain normal per-event precedence over super properties.

#### Scenario: First app start lifecycle events carry setup super properties (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the platform app version is "1.0.0" and build is "100"
- **WHEN** setup is called with token "test-token", application lifecycle capture enabled, and super properties:
  | property    | value      |
  | environment | production |
  | app         | consumer   |
- **AND** the application lifecycle integration starts
- **THEN** the enqueued "Application Installed" event properties should include:
  | property    | value      |
  | environment | production |
  | app         | consumer   |
- **AND** the enqueued "Application Opened" event properties should include:
  | property    | value      |
  | environment | production |
  | app         | consumer   |

#### Scenario: App update lifecycle event carries updated setup super properties and preserved persisted properties (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** lifecycle storage remembers version "1.0.0" and build "100"
- **AND** persistent storage contains registered properties:
  | property | value |
  | locale   | en_US |
  | plan     | pro   |
- **AND** the platform app version is "1.1.0" and build is "110"
- **WHEN** setup is called with token "test-token", application lifecycle capture enabled, and super properties:
  | property | value |
  | locale   | fr_FR |
- **AND** the application lifecycle integration starts
- **THEN** the enqueued "Application Updated" event properties should include:
  | property         | value |
  | $app_version     | 1.1.0 |
  | $app_build       | 110   |
  | previous_version | 1.0.0 |
  | previous_build   | 100   |
  | locale           | fr_FR |
  | plan             | pro   |
