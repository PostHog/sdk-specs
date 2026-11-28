## ADDED Requirements

### Requirement: Configured exception release identity

A client SDK MAY expose a configuration option that names the release its exception events belong to, so an application can supply release identity at startup instead of rebuilding its artifact. posthog-js spells it `error_tracking.release`. The option SHALL accept two mutually exclusive forms: a PostHog release id (`{ id }`), or the name and version of a release that already exists in the project with an optional build (`{ name, version, build? }`). The SDK SHALL NOT create a release from this option; the named release is the one registered through the CLI's `--release-name`, `--release-version`, and optional `--build`.

String values SHALL be trimmed, and a value that is empty after trimming SHALL count as absent. The id form SHALL apply only when no name, version, or build is supplied; the name/version form SHALL apply only when no id is supplied and both name and version are present. A blank, incomplete, or mixed configuration SHALL be ignored rather than partially applied.

A configured id SHALL be reported as `$release_id`. A configured name and version SHALL be reported as `$app_namespace` and `$app_version`, with `$app_build` added only when a build is supplied. The SDK SHALL NOT send both forms for one event.

The configuration SHALL apply to manual and automatically captured `$exception` events only. The SDK MUST NOT register these properties on other events and MUST NOT copy them into `$set`, `$set_once`, or `$group_set`. The properties SHALL be added before `before_send` runs, so a hook can inspect, replace, or remove them.

Release identity already present SHALL win over the configuration, which SHALL in turn win over a build-injected release id. Identity counts as already present when the event properties, the session properties, or the registered/super properties carry a non-null `$release_id`, or carry a non-null `$app_namespace` together with a non-null `$app_version` or `$app_build`. When a valid configuration applies, the SDK SHALL NOT also add a build-injected `$release_id`, because the injected id would otherwise take precedence during release resolution.

#### Scenario: A configured release id lands on an exception (@client)
- **GIVEN** the SDK is configured with an exception release `{ id: "rel-abc123" }`
- **WHEN** an exception is captured
- **THEN** the `$exception` event should have property "$release_id" equal to "rel-abc123"

#### Scenario: A configured name and version map to app identity (@client)
- **GIVEN** the SDK is configured with an exception release `{ name: "example-web", version: "9f2c1ab", build: "4821" }`
- **WHEN** an exception is captured
- **THEN** the `$exception` event should have property "$app_namespace" equal to "example-web"
- **AND** it should have property "$app_version" equal to "9f2c1ab"
- **AND** it should have property "$app_build" equal to "4821"
- **AND** it should omit "$release_id"

#### Scenario: A configured name and version without a build omit the build property (@client)
- **GIVEN** the SDK is configured with an exception release `{ name: "example-web", version: "9f2c1ab" }`
- **WHEN** an exception is captured
- **THEN** the `$exception` event should have property "$app_namespace" equal to "example-web"
- **AND** it should have property "$app_version" equal to "9f2c1ab"
- **AND** it should omit "$app_build"

#### Scenario: Incomplete or mixed configuration is ignored (@client)
- **GIVEN** the SDK is configured with an exception release of `<configuration>`
- **AND** no release identity is present on the event, session, or registered properties
- **AND** the build injected the release id "rel-injected"
- **WHEN** an exception is captured
- **THEN** the `$exception` event should have property "$release_id" equal to "rel-injected"
- **AND** it should omit "$app_namespace", "$app_version", and "$app_build"
  Examples:
  | configuration                                   |
  | { name: "example-web" }                         |
  | { version: "9f2c1ab" }                          |
  | { id: "rel-abc123", name: "example-web" }       |
  | { id: "   " }                                   |
  | { name: "example-web", version: "  " }          |

#### Scenario: Explicitly supplied release identity wins (@client)
- **GIVEN** the SDK is configured with an exception release `{ name: "example-web", version: "9f2c1ab" }`
- **WHEN** an exception is captured with property "$release_id" equal to "rel-explicit"
- **THEN** the `$exception` event should have property "$release_id" equal to "rel-explicit"
- **AND** it should omit "$app_namespace" and "$app_version"

#### Scenario: Registered app identity wins over the configuration (@client)
- **GIVEN** the SDK is configured with an exception release `{ name: "example-web", version: "9f2c1ab" }`
- **AND** the registered/super properties carry "$app_namespace" equal to "registered-app" and "$app_version" equal to "1.2.3"
- **WHEN** an exception is captured
- **THEN** the `$exception` event should keep "$app_namespace" equal to "registered-app"
- **AND** it should keep "$app_version" equal to "1.2.3"

#### Scenario: Valid configuration suppresses the injected release id (@client)
- **GIVEN** the SDK is configured with an exception release `{ name: "example-web", version: "9f2c1ab" }`
- **AND** the build injected the release id "rel-injected"
- **WHEN** an exception is captured
- **THEN** the `$exception` event should omit "$release_id"
- **AND** it should have property "$app_namespace" equal to "example-web"

#### Scenario: The configuration stays off other events (@client)
- **GIVEN** the SDK is configured with an exception release `{ id: "rel-abc123" }`
- **WHEN** capture is called with event "Save"
- **THEN** the "Save" event should omit "$release_id"
