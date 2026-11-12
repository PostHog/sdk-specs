## ADDED Requirements

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
