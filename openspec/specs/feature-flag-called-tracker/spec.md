# Feature Flag Called Tracker Specification

## Purpose

`feature-flag-called-tracker` is the internal deduplication component that suppresses duplicate `$feature_flag_called` events for the same flag evaluation outcome.

Its job is to prevent analytics noise when application code repeatedly reads the same flag without the underlying flag value changing.

## Applicability

`both` — audited client and server SDKs use an internal tracker/cache to dedupe `$feature_flag_called` events, though the dedupe key and eviction policy differ.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
shouldTrack(distinctId?, flagKey, value, groups?): boolean
markSeen(distinctId?, flagKey, value, groups?): void
reset(): void
```

In some SDKs, `shouldTrack` and `markSeen` are combined into one atomic "add if unseen" operation.

## Behavior

1. **Build a dedupe key from the flag access.** Common inputs are:
   - feature flag key
   - evaluated response/value (`true`, `false`, variant string, or `null`/`undefined`)
   - in many server/mobile SDKs, `distinct_id` as well
   - when provided to server-side evaluation, group context (`groups`, such as group type/key pairs) as well
   Group context SHOULD be normalized as a semantic mapping, for example sorted stringified `(group_type, group_key)` pairs, so incidental map/dictionary insertion order does not create a different dedupe key.
2. **Check whether this combination was already reported.**
3. **Suppress duplicate tracking events.** If the same combination has already been seen, do not emit another `$feature_flag_called` event.
4. **Allow new tracking when the response or evaluation context changes.** If a flag's value changes for the same key, or if a server-side call evaluates the same flag/value for a different `distinct_id` or group context, allow a new `$feature_flag_called` event.
5. **Reset on flag change and lifecycle boundaries.** When feature flag state changes, caches are reset, identity is reset, or the SDK is closed/shut down, clear the dedupe tracker so post-reset/reloaded SDK state can emit fresh tracking events and shutdown state cannot leak across SDK lifetimes. On client-side flag reloads, SDKs MAY retain the tracker if they can reliably compare the complete relevant flag state before and after reload (including flag keys, values, payloads, and other cached flag metadata used by accessors) and determine it is unchanged; otherwise, they SHOULD clear the tracker after reload.
6. **Expose tracking controls unevenly at the wrapper layer when applicable.** For example, Flutter delegates to the underlying native/browser trackers and only exposes a per-call suppression flag on `getFeatureFlagResult(sendEvent: ...)`, while `getFeatureFlag(...)`, `getFeatureFlagPayload(...)`, and `isFeatureEnabled(...)` always use the default tracking path.
7. **Cap memory usage where needed.** Larger-scale implementations evict old entries using bounded maps or LRU-style caches. When a bounded tracker reaches its capacity, it SHOULD evict the oldest or least-recently-used entries incrementally. Capacity pressure SHOULD NOT clear the entire tracker, because doing so can flood analytics with duplicate `$feature_flag_called` events. Full tracker clears are reserved for explicit lifecycle/context boundaries such as observed flag-state change/cache reset, identity reset, or SDK close/shutdown.

## State & lifecycle

### State read

- in-memory map/LRU cache of previously-reported flag/value/context combinations

### State written

- newly seen dedupe entries
- tracker reset/eviction state

### Lifecycle behavior

- The tracker starts empty when the SDK initializes.
- Each flag access that would emit `$feature_flag_called` consults the tracker first.
- Flag reloads reset the tracker when the SDK cannot reliably determine whether relevant flag state changed, or when it detects a change in flag keys, values, payloads, or other cached flag metadata used by accessors.
- Client SDKs MAY keep tracker state across a flag reload when they can reliably compare the complete relevant flag state and determine it is unchanged.
- Capacity-based eviction SHOULD remove only selected old/LRU entries instead of clearing the entire tracker.
- SDKs that support identity reset flows MUST clear the tracker because the relevant flag-evaluation context changed.
- SDK close/shutdown flows MUST clear the tracker so in-memory dedupe state does not outlive the SDK instance.
- Wrapper SDKs may not own a separate tracker at all. Flutter mostly inherits tracker lifecycle from the underlying mobile/browser SDKs it delegates to.

## Error handling

- Tracker operations should not throw in normal operation.
- Missing or uninitialized tracker state should be treated as "nothing seen yet".
- If value serialization/comparison is imperfect, the failure mode should be extra tracking or under-tracking, not application crashes.

## Concurrency & ordering guarantees

- Lookups and updates are synchronized or serialized by the SDK's runtime model.
- Atomic "check and add" behavior is preferred so concurrent accesses do not double-emit the same `$feature_flag_called` event.
- Reset operations take effect immediately for subsequent flag accesses.

## Interactions

- **`get-feature-flag` / `is-feature-enabled` / `get-feature-flag-result`** — all commonly use this tracker before capturing `$feature_flag_called`.
- **`get-feature-flag-payload`** — some SDKs route payload lookups through the same tracking/dedupe machinery, while others suppress tracking or expose only a compatibility wrapper.
- **feature-flag cache reloads** — reset the tracker when relevant flag state may have changed. SDKs MAY avoid clearing on reload when they can reliably compare the complete relevant cached flag state, including values and payloads, and determine it is unchanged.
- **identity resets / context changes** — clear the tracker because subsequent evaluations use a new user context.
- **server-side group context** — where groups are provided for feature-flag evaluation, the group type/key mapping is part of the dedupe context so the same user, flag, and value can be tracked separately for different group evaluations. Equivalent group mappings should dedupe even if represented in a different map/dictionary order.
- **SDK close / shutdown** — clears the tracker as part of teardown so dedupe state does not leak across SDK lifetimes.

## Requirements

### Requirement: Canonical feature-flag-called-tracker behavior

The SDK SHALL implement the canonical `feature-flag-called-tracker` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Tracker emits the first flag-called event for a value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property     | value   |
  | $feature_flag | beta-ui |
  | $feature_flag_response | true |

#### Scenario: Tracker suppresses duplicate events for the same flag value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** get feature flag "beta-ui" is called again
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

#### Scenario: Tracker emits again when the flag value changes (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** cached feature flag "beta-ui" changes to "false"
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"

#### Scenario: Tracker suppresses duplicates for the same server group context (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-123 |
  | team    | team-1      |
- **AND** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | team    | team-1      |
  | company | company-123 |
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "company-beta"

#### Scenario: Tracker emits again when server group context changes (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-123 |
- **AND** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-456 |
- **THEN** two "$feature_flag_called" events should be enqueued for flag "company-beta"

#### Scenario: Tracker clears on identity reset (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** reset is called
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"

#### Scenario: Tracker clears on SDK shutdown (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** shutdown is called
- **THEN** feature flag called tracker state should be empty

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
- **Session-attribution properties** — `$referring_domain` and the canonical campaign/click-id params the SDK already registers as super properties (e.g. `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, and click-id params such as `gclid`/`fbclid`). Web-analytics session-initial attribution (UTM values, channel type) is read from the **first event in a session**, and a minimized event can be that first event; stripping these would silently null out the whole session's attribution. Full `$referrer` remains excluded — only `$referring_domain` and the bare campaign-param keys survive minimization.

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

#### Scenario: Minimal event preserves session-attribution properties but not the full referrer (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the server reports the minimal-event gate as enabled
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the flag "beta-ui" reports `has_experiment` as false
- **AND** a super property "$referring_domain" with value "google.com" is registered
- **AND** a super property "utm_source" with value "google" is registered
- **AND** a super property "$referrer" with value "https://google.com/search?q=posthog" is registered
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event properties should include:
  | property           | value      |
  | $referring_domain  | google.com |
  | utm_source         | google     |
- **AND** the enqueued event properties should not include "$referrer"

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
