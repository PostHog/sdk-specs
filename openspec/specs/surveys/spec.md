# Surveys Specification

## Purpose

`surveys` is the client-side subsystem that loads survey definitions, decides which surveys are eligible for the current user/device/context, renders survey UI, records local presentation state, and emits standardized survey interaction events.

It exists so SDKs can show in-product survey prompts without every application rebuilding targeting, seen-state, branching, response formatting, and event emission on top of generic `capture(...)` calls.

## Applicability

`client` — surveys are implemented in browser/mobile/UI SDKs where the SDK can render or delegate UI and observe user interaction. Server SDKs may evaluate feature flags or send survey-like events manually, but they do not own an ambient survey display lifecycle.

## Public signature(s)

No single canonical public API. Typical surfaces are a mix of public methods, providers, integrations, and delegates:

```ts
// browser-style public API
onSurveysLoaded(callback: (surveys, context) => void): () => void
getSurveys(callback, forceReload?): void
getActiveMatchingSurveys(callback, forceReload?): void
renderSurvey(surveyIdOrSurvey, selector, properties?): void
displaySurvey(surveyId, options): void
cancelPendingSurvey(surveyId): void

// mobile/wrapper-style lifecycle
installSurveyIntegration(client): void
onSurveysLoaded(surveys): void
getActiveMatchingSurveys(): Survey[]
renderSurvey(displaySurvey, onShown, onResponse, onClosed): void

// React/React Native wrapper-style API
<PostHogSurveyProvider client? ...>{children}</PostHogSurveyProvider>
<SurveyModal ... />
```

## Behavior

1. **Initialize only when surveys are enabled.** The subsystem is installed or loaded during SDK setup when surveys are enabled by local config and/or remote config. If disabled, it returns empty results or no-ops rather than rendering UI.
2. **Load survey definitions.** Implementations fetch or receive survey definitions from the PostHog surveys/remote-config path, cache them in memory and sometimes persistence, and dedupe in-flight loads where applicable.
3. **Wait for dependent state.** Survey eligibility commonly depends on feature flags, remote config, SDK readiness, consent state, and platform lifecycle callbacks. Wrappers should wait for those prerequisites before selecting a survey.
4. **Track local seen/in-progress state.** SDKs remember which surveys have been seen, dismissed, responded to, or are currently in progress so that the same prompt is not repeatedly shown unless the survey explicitly allows repeated activation.
5. **Filter active matching surveys.** Eligibility checks include active/running status, device type, wait-period rules, linked/targeting/internal feature flags, optional event/action activation conditions, and platform-specific display constraints.
6. **Handle event activation.** For surveys activated by a captured event or DOM/native action, the survey subsystem maps event/action conditions to survey ids and marks matching surveys as activated when an observed event satisfies the configured filters.
7. **Render through a platform UI layer.** Browser implementations render Preact/shadow-DOM survey UI or inline/popover widgets. Mobile SDKs convert raw survey definitions into display models and delegate rendering to native or React Native UI components.
8. **Allow only one active prompt unless explicitly designed otherwise.** Implementations keep active/focus state so multiple eligible popovers are queued or skipped while another survey is displayed.
9. **Apply branching and response-key compatibility.** Survey response handling computes the next question from branching rules and writes both current question-id response keys and legacy index-based keys when required for backward compatibility.
10. **Emit standardized events through the normal capture pipeline.** Survey UI emits fixed events such as `survey shown`, `survey sent`, `survey dismissed`, and, where supported, `survey abandoned`. These events include survey id/name/iteration metadata, response properties, `$survey_questions`, and `$set` interaction markers.
11. **Reset survey local state on SDK reset when supported.** Client resets may clear seen/in-progress survey storage so future users on the same device do not inherit the previous user's survey state.

## State & lifecycle

### State read

- survey definitions from remote config or the surveys API
- feature-flag values used by survey targeting
- device/platform type
- seen-survey and in-progress-survey storage
- event/action activation state
- current active survey and current question index
- collected responses for the active survey
- SDK readiness, consent, and lifecycle state

### State written

- cached survey list
- seen-survey keys and last-seen timestamps
- in-progress response state
- active survey/focus state
- event-activated survey ids
- emitted survey interaction events
- optional UI delegate/provider state

### Lifecycle behavior

- **Setup:** installed as an extension/integration/provider only when the SDK and config enable surveys.
- **Remote-config update:** updates cached survey definitions and may rebuild event-to-survey activation maps.
- **App/page lifecycle:** foreground/layout/page-unload hooks can trigger survey display checks or abandoned-event emission.
- **User interaction:** shown/response/close callbacks update active state, seen state, responses, and emitted events.
- **Reset/teardown:** reset clears local survey history in SDKs that own survey storage; integration uninstall/provider unmount should remove listeners or stop rendering active UI.

## Error handling

- Disabled surveys return empty lists or no-op display attempts.
- Missing survey extension/UI support logs warnings or errors and reports load failure context to callbacks where the public API supports it.
- Failed network or remote-config survey loads return empty surveys plus error context, or keep using previously cached values if the platform exposes them.
- Missing clients/providers prevent event capture and should avoid crashing the application UI.
- Invalid survey ids, unsupported survey types, or missing render targets log and return without emitting interaction events.

## Concurrency & ordering guarantees

- Concurrent survey loads should be deduped or serialized where supported so callbacks observe one consistent result set.
- Survey caches and active-survey state should be lock-protected or serialized on platforms with multithreaded lifecycle callbacks.
- A survey should be marked active before its shown/response/closed callbacks can mutate response state.
- `survey shown` should precede `survey sent` / `survey dismissed` for a displayed prompt; a survey should be marked seen when it is submitted or dismissed.
- Only completed submissions should clear in-progress state and emit completed-response properties; abandonment should be emitted at most once per in-progress survey.

## Interactions

- **`capture`** — all survey interaction telemetry is emitted through the normal capture pipeline.
- **feature flags / remote config** — survey definitions and eligibility are commonly delivered with remote config and gated by linked/internal feature flags.
- **persistent storage** — stores survey definitions, seen keys, last-seen dates, and in-progress response state.
- **reset** — clears survey seen/in-progress state in SDKs that own that state.
- **consent gating** — browser surveys avoid loading in cookieless mode without consent.
- **session replay** — browser survey events can include a session replay URL on sent/dismissed/abandoned events.
- **wrapper UI layers** — React Native and mobile SDKs expose provider/delegate components that translate internal survey state into framework-native UI.

## Requirements

### Requirement: Canonical surveys behavior

The SDK SHALL implement the canonical `surveys` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Survey definitions are loaded and cached
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** the mock server will return surveys:
  | id       | name       | active |
  | survey-1 | NPS Survey | true   |
- **WHEN** surveys are loaded
- **THEN** cached surveys should include survey "survey-1"

#### Scenario: Eligible survey is shown once per presentation rules
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
- **WHEN** survey "survey-1" is dismissed
- **AND** survey eligibility is evaluated again
- **THEN** survey display callback should not be invoked again for survey "survey-1"

#### Scenario: Survey response captures a survey sent event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" is visible
- **WHEN** the user submits survey "survey-1" with response "Great"
- **THEN** one event named "survey sent" should be enqueued
- **AND** the enqueued event properties should include:
  | property   | value    |
  | $survey_id | survey-1 |
  | $survey_response | Great |

#### Scenario: Surveys respect opt-out state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** analytics capture is opted out
- **WHEN** surveys are loaded
- **THEN** no survey response or display event should be enqueued
