## ADDED Requirements

### Requirement: Minimal event mode for non-experiment flags

The SDK SHALL support a server-controlled "minimal event" mode that reduces `$feature_flag_called` event properties to a fixed allowlist instead of the full enriched properties dict, when both of the following hold:

- **The server has enabled the gate for the team.** Reported as `minimalFlagCalledEvents: true` on the remote `/flags` (v2) response, or `minimal_flag_called_events: true` on the local-evaluation flag-definitions payload used by SDKs that support local evaluation. Absent, falsy, or unrecognized-shape responses mean the gate is off.
- **The evaluated flag's server-reported experiment linkage is exactly `false`.** Flags report `has_experiment` as part of their evaluation metadata. If `has_experiment` is `true` (flag linked to an experiment), or unknown/missing (legacy response shape, stale cache, older server), the SDK MUST NOT minimize — it sends the full event. Only an explicit `false` triggers minimization.

When gated on, the event's properties SHALL be reduced to an allowlist covering, at minimum, these categories:

- **Flag identity and outcome** — the flag key, its resolved value, and the experiment-linkage flag itself (e.g. `$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`).
- **Evaluation debug scalars** the server/SDK already attaches (e.g. `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`).
- **Group and person-processing context** needed for correct downstream handling (e.g. `$groups`, `$process_person_profile`).
- **Session/SDK linkage** (e.g. `$session_id`, `$lib`, `$lib_version`) and, on server SDKs, the server marker (e.g. `$is_server`).
- **Static, low-cardinality platform/runtime identity properties** the SDK already attaches to every event, kept for platform/runtime breakdowns on flag-call debugging (e.g. `$os`/`$python_version` on posthog-python; the equivalent OS/runtime identity fields on other SDKs).

Everything else — including super properties, custom event properties passed by the caller, and other enriched context tags — SHALL be stripped from a minimized event.

> Note (non-normative): the exact property allowlist is stated here at the category level, not as one fixed literal list, because SDKs differ in exactly which static platform fields they attach. posthog-python's allowlist (`$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`, `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`, `$groups`, `$process_person_profile`, `$session_id`, `$lib`, `$lib_version`, `$is_server`, `$geoip_disable`, `$os`, `$os_version`, `$os_distro`, `$python_runtime`, `$python_version`) is the reference implementation other SDKs describe mirroring.

If the gate is absent, the `has_experiment` signal is missing/unknown, or the flag is linked to an experiment, the SDK SHALL send the full, unminimized event unchanged — minimization fails safe to "send everything" rather than risk silently dropping properties a consumer depends on.

The gate SHALL persist alongside cached flag/local-evaluation definition state (including through external/shared `flag_definition_cache`-style provider round-trips) so it survives polls, `304 Not Modified` responses, and cache reloads without requiring a fresh network round trip to re-learn it.

#### Scenario: Full event when the server does not report the gate (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" has no reported `has_experiment` and the server reports no minimal-event gate
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should include the full enriched property set, unminimized

#### Scenario: Full event when the flag's experiment linkage is unknown (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" has no reported `has_experiment` value
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should include the full enriched property set, unminimized

#### Scenario: Full event when the flag is linked to an experiment (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key           | value |
  | experiment-ui | true  |
- **AND** the flag "experiment-ui" reports `has_experiment` as true
- **WHEN** get feature flag "experiment-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should include the full enriched property set, unminimized

#### Scenario: Minimal event when gated on and the flag has no experiment (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" reports `has_experiment` as false
- **AND** a super property "team" with value "growth" is registered
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event properties should include:
  | property     | value   |
  | $feature_flag | beta-ui |
  | $feature_flag_response | true |
  | $feature_flag_has_experiment | false |
- **AND** the enqueued event properties should not include "team"

#### Scenario: Gate persists across a local-evaluation definitions refresh (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and a personal API key for local evaluation
- **AND** the local-evaluation definitions payload reports `minimal_flag_called_events` as true
- **AND** local feature flag definitions include a flag "beta-ui" with `has_experiment` false returning true
- **WHEN** the local-evaluation definitions are refreshed via a `304 Not Modified` response
- **AND** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should be minimized per the allowlist
