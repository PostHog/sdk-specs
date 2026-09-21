## ADDED Requirements

### Requirement: Project remote-config HTTP request

When an SDK that implements project remote configuration fetches the JSON representation of project remote configuration, it SHALL send `GET {assetBase}/array/{projectKey}/config` with no request body. `{projectKey}` SHALL be the public project token configured at SDK initialization, not a personal API key or secret key. The endpoint SHALL NOT require a personal API key, secret key, or SDK-generated bearer Authorization header. Caller-configured headers for a reverse proxy remain permitted.

The request SHALL NOT require user identity, groups, or person properties. These belong to feature-flag evaluation, not this project-level configuration fetch. This contract does not mandate a request `Content-Type` header for the bodyless GET; SDKs can retain existing JSON or platform headers.

#### Scenario: Fetch project configuration without user credentials
- **GIVEN** an SDK that implements project remote configuration initialized with project token `phc_test`
- **WHEN** it fetches the JSON project configuration
- **THEN** it sends a GET request to `/array/phc_test/config` on the resolved asset base
- **AND** the request has no body and requires neither a personal API key nor a secret key
- **AND** the SDK does not add user identity or person/group properties to the request

### Requirement: Remote-config asset host selection

For the standard normalized PostHog Cloud ingestion bases, the SDK SHALL resolve the asset base as follows:

| Configured ingestion base | Asset base |
| --- | --- |
| `https://us.i.posthog.com` | `https://us-assets.i.posthog.com` |
| `https://eu.i.posthog.com` | `https://eu-assets.i.posthog.com` |

For a custom host, reverse proxy, or self-hosted deployment, the SDK SHALL preserve the configured base rather than substituting a PostHog Cloud asset host. An existing configured base-path prefix SHALL be preserved when appending `/array/{projectKey}/config`. Existing SDK host normalization can occur before these rules.

#### Scenario: US Cloud uses the US asset host
- **GIVEN** the configured host is `https://us.i.posthog.com`
- **WHEN** the SDK fetches JSON remote configuration for `phc_test`
- **THEN** the request URL is `https://us-assets.i.posthog.com/array/phc_test/config`

#### Scenario: EU Cloud uses the EU asset host
- **GIVEN** the configured host is `https://eu.i.posthog.com`
- **WHEN** the SDK fetches JSON remote configuration for `phc_test`
- **THEN** the request URL is `https://eu-assets.i.posthog.com/array/phc_test/config`

#### Scenario: Reverse proxy base path is preserved
- **GIVEN** the configured host is `https://analytics.example.com/posthog`
- **WHEN** the SDK fetches JSON remote configuration for `phc_test`
- **THEN** the request URL is `https://analytics.example.com/posthog/array/phc_test/config`

### Requirement: Remote-config JSON wire representation

The SDK SHALL parse a successful JSON response as a top-level project-configuration object, not an event-ingestion envelope or a map of evaluated flag values. It SHALL tolerate unknown fields and optional fields absent from the response. Malformed fields and fetch failures remain subject to this capability's existing error-handling rules.

Common optional wire fields include:

| Field | Representation | Meaning |
| --- | --- | --- |
| `hasFeatureFlags` | boolean | Whether the project has active flags; informs whether to preload flags |
| `sessionRecording` | boolean or object | Session replay configuration |
| `surveys` | boolean or array | Survey availability or definitions |
| `errorTracking` | boolean or object | Error tracking configuration |
| `capturePerformance` | boolean or object | Performance/network timing configuration |
| `supportedCompression` | array of strings | Advertised compression formats |

This is not an exhaustive schema and does not require every SDK to implement every product. Nested replay/survey/error-tracking settings retain their product-specific semantics. Conceptual acceptance settings such as `session_replay_enabled` and `feature_flags_available` SHALL NOT be treated as actual JSON wire field names.

#### Scenario: Parse real wire fields and tolerate extensions
- **GIVEN** the JSON endpoint returns HTTP 200 with `{"hasFeatureFlags":false,"sessionRecording":false,"surveys":false,"futureSetting":{"enabled":true}}`
- **WHEN** the SDK processes the response
- **THEN** it recognizes the supported project settings using their wire names
- **AND** the unknown `futureSetting` field does not prevent applying those settings
- **AND** absent optional fields do not make the response invalid

### Requirement: Project configuration delivery and scope

This HTTP contract SHALL apply to all client and server SDKs that implement project remote configuration. It SHALL NOT require SDKs without this capability to implement it. SDKs SHALL apply configuration only for features they support.

Browser SDKs SHALL remain permitted to consume project configuration embedded in a token-specific loader or delivered through `/array/{projectKey}/config.js` instead of issuing a redundant JSON GET. The script response is JavaScript, not the JSON representation specified above. These alternatives do not require non-browser SDKs to execute JavaScript.

#### Scenario: Browser already has project configuration
- **GIVEN** the browser SDK has valid preloaded project configuration from its token-specific loader
- **WHEN** it initializes its remote-config subsystem
- **THEN** it can apply that configuration without requesting `/array/{projectKey}/config`
