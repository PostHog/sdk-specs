# Session Replay Ingestion Controls Specification

## Purpose

`session-replay-ingestion-controls` is the client-side decision logic that determines whether session replay capture is active for the current session, based on the remote `sessionRecording` configuration delivered alongside feature flags. It governs the **automatic** record / don't-record decision — distinct from the manual `start-session-recording` / `stop-session-recording` APIs.

It exists because session replay must respect a set of server-driven "ingestion controls" — a replay enablement flag, an optional linked feature flag, sampling, event triggers, URL triggers, a URL blocklist, and a minimum duration — and because SDKs differ in how those controls are **combined**. Web (`posthog-js`) supports a restrictive (AND) and a permissive (OR) combination; mobile SDKs (`posthog-ios`, `posthog-android`) implement only the restrictive (AND) combination.

Scope note: this spec covers the **V1** trigger configuration — the flat `sessionRecording` fields below (`version: 1`). V2 "trigger groups" (`version: 2`, a `triggerGroups` array with per-group sampling and minimum duration, event property filters, and union across groups) is a web-only extension carried in the **same** remote config and specified separately. The flat V1 fields are what mobile SDKs consume and remain part of the wire config alongside `version`/`triggerGroups`, so V1 is current shipping behavior rather than removed legacy.

## Applicability

`client` — browser and UI/mobile SDKs that own session replay capture. Server SDKs do not observe a session timeline or record replay payloads. Hybrid SDKs that embed a native replay SDK (`posthog-react-native`, `posthog-flutter`) are in scope; because their capture pipeline and replay subsystem can live on different layers, see "Hybrid (multi-layer) SDK ingestion controls".

## Public signature(s)

No public API. The controls arrive in the remote `sessionRecording` config (resolved together with feature flags) and gate replay automatically. The relevant inputs:

```ts
// remote sessionRecording config (resolved with feature flags).
// Master enablement is the presence of this config: the server returns a
// falsy/absent `sessionRecording` (e.g. `false`) to disable replay entirely.
sessionRecording: {
  linkedFlag?: string | { flag: string; variant: string } | null
  sampleRate?: string | null                            // decimal 0.0–1.0, delivered as a string; parse before use
  minimumDurationMilliseconds?: number | null
  eventTriggers?: string[]
  urlTriggers?: { url: string; matching: 'regex' }[]    // URL-capable SDKs only
  urlBlocklist?: { url: string; matching: 'regex' }[]   // URL-capable SDKs only
  triggerMatchType?: 'all' | 'any'  // SDKs with a configurable match type (web); absent ⇒ 'all'
  version?: 1 | 2                   // 2 selects trigger groups (web-only V2, specified separately)
}
```

Local replay configuration (e.g. browser `session_recording`, native `sessionReplayConfig`) supplies the local master switch and a sample-rate fallback. These controls have no caller-facing method; their observable effect is whether replay is active, which the `is-session-replay-active` API reports.

## Behavior

1. **Resolve replay enablement.** Replay is gated first on the local replay configuration **and** the remote `sessionRecording` config both being active. If either disables replay, no recording occurs and no further controls are evaluated.
2. **Evaluate the linked feature flag.** When `linkedFlag` is set, resolve it against the loaded feature flags: a boolean flag must be `true`; a `{ flag, variant }` must resolve to the configured variant; a string flag pointing at a multivariate flag is satisfied for any present variant; a missing or quota-limited flag is not satisfied. Where the SDK tracks feature-flag usage, evaluating the linked flag reports it as called.
3. **Make the sampling decision.** When `sampleRate` is set, compute a deterministic decision keyed on the current session id, persist it for the session, and re-decide when the session id rotates or the rate changes. The remote rate is delivered as a string (a decimal between `"0.0"` and `"1.0"`) and is parsed to a number before comparison. `0.0` never samples in; `1.0` (or an absent rate) always samples in.
4. **Track event triggers.** When `eventTriggers` is set, watch events captured on the client (emitted through the capture API or by autocapture); the first such event whose name matches any configured trigger activates replay for the current session. Matching is by event name as the event passes through the capture pipeline — triggers are not evaluated server-side. Activation persists for that session and is re-armed on a new session.
5. **Track URL triggers and blocklist (URL-capable SDKs).** When `urlTriggers` is set, a current URL matching any trigger activates replay for the session. When `urlBlocklist` is set, replay pauses while the current URL matches and resumes when it no longer matches.
6. **Apply the minimum-duration gate.** When `minimumDurationMilliseconds` is set, buffer captured replay data and withhold a session's replay data until its captured activity reaches the minimum; sessions that never reach it are not emitted.
7. **Combine the controls.** Decide whether replay is active by combining the configured controls; controls that are not configured are ignored.
   - **Restrictive (AND)** — record only when every configured control is satisfied. This is the canonical default, the behavior when `triggerMatchType` is absent or `all`, and the only mode on mobile SDKs.
   - **Permissive (OR)** — on SDKs that expose `triggerMatchType: 'any'`, record when any configured control is satisfied: a matching trigger records even at a `0.0` sample rate, and a sampled-in session records before any trigger fires.
8. **Re-evaluate on change.** Re-run the decision when the session id rotates, the remote config updates, or feature flags change, starting or stopping replay so the live state matches the controls.
9. **Do not emit analytics events directly.** This logic controls replay capture state only; any replay snapshots or `$snapshot` traffic come from the replay subsystem once recording is active.

## State & lifecycle

### State read

- local and remote replay enablement
- `linkedFlag` config and the resolved feature flags
- `sampleRate` (remote or local fallback) and the persisted sampling decision for the session
- `eventTriggers` and the persisted trigger-activated session id
- `urlTriggers` / `urlBlocklist` and the current URL (URL-capable SDKs)
- `minimumDurationMilliseconds` and the buffered duration of captured activity
- `triggerMatchType` where the SDK supports it
- the current session id

### State written

- the persisted per-session sampling decision
- the persisted trigger-activated session id (event / URL)
- replay-active / paused / buffering runtime state
- session-scoped debug properties where the SDK records them

### Lifecycle behavior

- **Setup:** controls are resolved from cached remote config when the replay integration installs; the SDK subscribes to remote-config updates, event captures, and session-id changes.
- **Capture:** each captured event is checked against event triggers; each navigation is checked against URL triggers and the URL blocklist (URL-capable SDKs).
- **Session rotation:** triggers are re-armed for the new session, sampling is re-decided, and recording is stopped or started to match.
- **Remote-config update:** controls are re-resolved; recording stops when the session becomes ineligible.
- **Teardown:** stopping replay clears runtime state; persisted per-session decisions remain until the session rotates or storage is reset.

## Error handling

- The gating decision never throws into the host app.
- Malformed or out-of-range config values are ignored with a logged warning (for example, a sample rate outside `0.0`–`1.0` or a negative minimum duration) and treated as unconfigured.
- A missing or quota-limited linked flag is treated as not satisfied (fail closed).
- Before a configured trigger activates, SDKs either buffer captured activity (web) or stay stopped (mobile); neither emits replay until the session is eligible.

## Concurrency & ordering guarantees

- The sampling decision is deterministic and stable for a given session id, so repeated evaluations within a session agree and a rotated session is re-decided.
- Trigger activation persists for the session and is re-armed on rotation; a control that is not configured never blocks recording.
- Event-capture and session-change listeners may fire from any thread; replay-state writes are serialized onto the replay integration's thread where the platform requires it (mobile posts to the main thread).

## Interactions

- **remote config** — delivers the `sessionRecording` controls, resolved together with feature flags.
- **feature flags** — supply the linked-flag value; evaluating the linked flag reports the flag as called where usage is tracked.
- **session manager** — supplies the session id that keys sampling and trigger activation; rotation re-arms triggers and re-decides sampling.
- **before-send hook** — runs inside the capture pipeline before an event reaches event-trigger matching, so an event it drops cannot activate a trigger; see the before-send hook spec.
- **`start-session-recording` / `stop-session-recording`** — the manual control surface. The browser start API can override specific local start gates for the next attempt; mobile manual start still respects event triggers.
- **`is-session-replay-active`** — reflects whether these controls currently allow recording.
- **session-replay-privacy** — masking/redaction applies once these controls allow capture.
- **hybrid / embedded native SDK** — in `posthog-react-native` and `posthog-flutter` the capture pipeline and the replay subsystem may live on different layers, so the ingestion-control decision must be coordinated across layers (see "Hybrid (multi-layer) SDK ingestion controls").

## Requirements

### Requirement: Replay enablement gate

The SDK SHALL capture session replay only when replay is enabled **both** locally (the SDK's replay configuration) **and** remotely (the `sessionRecording` remote config resolves to active). If either source disables replay, the SDK SHALL NOT record, regardless of any other ingestion control. This gate is a precondition for every other requirement in this capability.

This requirement applies to all replay-capable SDKs.

#### Scenario: Remote config disables replay
- **GIVEN** session replay is configured locally
- **AND** the remote config reports session recording as disabled
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: Local config disables replay even when remote is active
- **GIVEN** session replay is disabled in local config
- **AND** the remote config reports session recording as active
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: Both local and remote enable replay with no other controls
- **GIVEN** session replay is configured locally
- **AND** the remote config reports session recording as active with no linked flag, sampling, or triggers
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

### Requirement: Linked feature flag gating

When the remote `sessionRecording` config specifies a `linkedFlag`, the SDK SHALL evaluate it against the loaded feature flags to decide whether the linked-flag control is satisfied:

- A boolean linked flag is satisfied when the flag's value is `true`; an absent, quota-limited, or `false` flag is not satisfied.
- A `{ flag, variant }` linked flag is satisfied only when the flag's resolved variant equals the configured variant.
- A string linked flag pointing at a multivariate flag is satisfied for any present variant value.

Where the SDK tracks feature-flag usage, evaluating the linked flag SHALL report it as called. When the linked flag is the only configured control, recording SHALL be active if and only if the control is satisfied. How an unsatisfied linked flag interacts with other configured controls is governed by the combination requirements (AND vs OR).

This requirement applies to all replay-capable SDKs.

#### Scenario: Boolean linked flag enabled activates recording
- **GIVEN** session replay is enabled
- **AND** the remote config links recording to boolean flag "replay-flag"
- **AND** feature flag "replay-flag" is enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: Linked flag absent or disabled prevents recording
- **GIVEN** session replay is enabled
- **AND** the remote config links recording to boolean flag "replay-flag"
- **AND** feature flag "replay-flag" is not enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: Linked flag variant must match
- **GIVEN** session replay is enabled
- **AND** the remote config links recording to flag "replay-flag" variant "test"
- **AND** feature flag "replay-flag" resolves to variant "test" for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: Linked flag variant mismatch prevents recording
- **GIVEN** session replay is enabled
- **AND** the remote config links recording to flag "replay-flag" variant "test"
- **AND** feature flag "replay-flag" resolves to variant "control" for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

### Requirement: Sampling gating

The SDK SHALL make a **deterministic** sampling decision keyed on the current session id whenever the remote `sessionRecording` config specifies a `sampleRate` between 0.0 and 1.0 (delivered as a string and parsed to a number), so the same session id always yields the same decision. The SDK SHALL persist the decision for the lifetime of the session and SHALL re-decide when the session id rotates or when the sample rate changes. A sample rate of 0.0 SHALL never sample a session in; a sample rate of 1.0 (or an absent rate) SHALL always sample in. When sampling is the only configured control, a sampled-out session SHALL NOT record.

This requirement applies to all replay-capable SDKs.

#### Scenario: Full sample rate records the session
- **GIVEN** session replay is enabled
- **AND** the remote config sets the recording sample rate to 1.0
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: Zero sample rate does not record the session
- **GIVEN** session replay is enabled
- **AND** the remote config sets the recording sample rate to 0.0
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: Sampling decision is stable within a session
- **GIVEN** session replay is enabled
- **AND** the remote config sets the recording sample rate to 0.5
- **AND** the SDK has made a sampling decision for the current session id
- **WHEN** the SDK re-resolves whether to record the same session id
- **THEN** the sampling decision should be unchanged from the first decision

#### Scenario: New session id re-decides sampling
- **GIVEN** session replay is enabled
- **AND** the remote config sets the recording sample rate to 0.5
- **AND** the SDK has made a sampling decision for the current session id
- **WHEN** the session id rotates and the SDK resolves recording for the new session id
- **THEN** a fresh sampling decision should be made for the new session id

### Requirement: Event-trigger gating

The SDK SHALL activate replay for the current session the first time the client captures an analytics event whose name matches any configured trigger, when the remote `sessionRecording` config specifies `eventTriggers` (a list of event names). Event triggers SHALL be matched against events captured on the client — those emitted through the SDK's capture API or by autocapture — by event name, as each event passes through the SDK's capture pipeline; they are not evaluated server-side. Because matching happens within the capture pipeline, it observes the event **after** the before-send hook stage (see the before-send hook spec): an event that before-send drops SHALL NOT activate a trigger. Activation SHALL persist for the remainder of that session and SHALL NOT carry over to a new session — a new session requires a fresh matching event. While event triggers are configured and the current session has not been activated (and no other control would independently activate it), the SDK SHALL NOT be actively recording.

SDKs MAY buffer pre-activation activity and flush it retroactively when a trigger fires (web), or begin capture only at activation (mobile); both are allowed variations.

This requirement applies to all replay-capable SDKs.

#### Scenario: Matching event activates recording
- **GIVEN** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **AND** session recording is not active because the trigger has not fired
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should be active

#### Scenario: Non-matching events do not activate recording
- **GIVEN** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **WHEN** the client captures an event named "some_other_event"
- **THEN** session recording should not be active

#### Scenario: Activation persists for the rest of the session
- **GIVEN** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **AND** an event named "$pageview" has activated recording for the current session
- **WHEN** the SDK re-resolves whether to record the same session
- **THEN** session recording should remain active

#### Scenario: New session requires a fresh matching event
- **GIVEN** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **AND** an event named "$pageview" has activated recording for the current session
- **WHEN** the session id rotates to a new session
- **THEN** session recording should not be active until the client captures "$pageview" again

#### Scenario: An event dropped by before-send does not activate the trigger
- **GIVEN** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **AND** a before-send hook drops events named "$pageview"
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should not be active

### Requirement: URL-trigger gating

When the remote `sessionRecording` config specifies `urlTriggers` (regex patterns), the SDK SHALL activate replay for the current session when the current URL matches any configured trigger. Activation SHALL persist for the remainder of that session.

This requirement applies only to SDKs with a URL / navigation concept (for example the browser SDK). SDKs without URLs — including the mobile SDKs (`posthog-ios`, `posthog-android`) — are exempt and SHALL NOT be required to implement URL triggers.

#### Scenario: Matching URL activates recording
- **GIVEN** a URL-capable SDK with session replay enabled
- **AND** the remote config configures a URL trigger matching "/checkout"
- **AND** session recording is not active
- **WHEN** the current URL changes to one matching "/checkout"
- **THEN** session recording should be active

#### Scenario: Non-matching URL does not activate recording
- **GIVEN** a URL-capable SDK with session replay enabled
- **AND** the remote config configures a URL trigger matching "/checkout"
- **WHEN** the current URL is one that does not match "/checkout"
- **THEN** session recording should not be active

### Requirement: URL blocklist pause and resume

The SDK SHALL pause replay capture while the current URL matches any pattern in the remote `sessionRecording` config's `urlBlocklist` (regex patterns), and SHALL resume capture when the URL no longer matches. The blocklist pause SHALL take effect independently of how the session was activated.

This requirement applies only to SDKs with a URL / navigation concept. SDKs without URLs — including the mobile SDKs — are exempt.

#### Scenario: Navigating to a blocklisted URL pauses recording
- **GIVEN** a URL-capable SDK with session replay enabled and active
- **AND** the remote config configures a URL blocklist matching "/account"
- **WHEN** the current URL changes to one matching "/account"
- **THEN** session recording should be paused

#### Scenario: Navigating away from a blocklisted URL resumes recording
- **GIVEN** a URL-capable SDK with session replay enabled and active
- **AND** the remote config configures a URL blocklist matching "/account"
- **AND** recording is paused because the current URL matches "/account"
- **WHEN** the current URL changes to one that does not match "/account"
- **THEN** session recording should resume

### Requirement: Minimum-duration buffering gate

When the remote `sessionRecording` config specifies `minimumDurationMilliseconds`, the SDK SHALL buffer captured replay data and SHALL NOT emit a session's replay data until the session's captured activity has reached the configured minimum duration. A session whose captured activity never reaches the minimum SHALL NOT have its replay data emitted. The minimum-duration gate governs when buffered data is emitted; it does not by itself decide whether the other controls activate recording.

This requirement applies to all replay-capable SDKs.

#### Scenario: Replay data is withheld below the minimum duration
- **GIVEN** session replay is enabled and otherwise eligible
- **AND** the remote config sets the minimum duration to 5000 milliseconds
- **WHEN** the session has captured less than 5000 milliseconds of activity
- **THEN** the session's replay data should not be emitted

#### Scenario: Replay data is emitted once the minimum duration is reached
- **GIVEN** session replay is enabled and otherwise eligible
- **AND** the remote config sets the minimum duration to 5000 milliseconds
- **WHEN** the session's captured activity reaches or exceeds 5000 milliseconds
- **THEN** the buffered replay data should be emitted

### Requirement: Restrictive (AND) combination of ingestion controls

When more than one ingestion control is configured, the SDK SHALL record the session only when **all** configured controls are simultaneously satisfied: the linked flag (if configured) is satisfied **and** the session is sampled in (if sampling is configured) **and** every configured trigger (event and, where supported, URL) has activated. Controls that are not configured SHALL be ignored. Until all configured controls are satisfied, the SDK SHALL NOT emit replay for the session (it MAY buffer where supported). The minimum-duration gate is **not** one of these activation controls — it governs when already-activated replay data is emitted (see "Minimum-duration buffering gate") and is never part of the AND/OR combination.

This is the canonical default combination. Every replay-capable SDK SHALL implement it. On SDKs that expose a configurable trigger match type it is the behavior when the match type is absent or set to `all`; on mobile SDKs it is the only supported combination.

#### Scenario: Event trigger with zero sampling does not record even when the event fires
- **GIVEN** session replay is enabled
- **AND** the SDK applies the restrictive (AND) combination
- **AND** the remote config configures event trigger "$pageview" and a sample rate of 0.0
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should not be active because sampling did not pass

#### Scenario: All configured controls satisfied records the session
- **GIVEN** session replay is enabled
- **AND** the SDK applies the restrictive (AND) combination
- **AND** the remote config configures event trigger "$pageview" and a sample rate of 1.0
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should be active

#### Scenario: Unsatisfied linked flag blocks recording even when sampled in
- **GIVEN** session replay is enabled
- **AND** the SDK applies the restrictive (AND) combination
- **AND** the remote config links recording to boolean flag "replay-flag" and sets a sample rate of 1.0
- **AND** feature flag "replay-flag" is not enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

### Requirement: Permissive (OR) combination of ingestion controls

When an SDK exposes a configurable trigger match type and it is set to `any`, the SDK SHALL record the session when **any** configured control is satisfied: the session is sampled in, **or** any configured trigger (event or URL) has activated, **or** the linked flag is satisfied. As a result a matching event SHALL start recording even at a 0.0 sample rate, and a sampled-in session SHALL record even before any trigger has fired.

This requirement applies only to SDKs that expose a configurable trigger match type (for example the browser SDK). SDKs without a configurable trigger match type — including the mobile SDKs (`posthog-ios`, `posthog-android`) — SHALL always apply the restrictive (AND) combination and are NOT required to satisfy this requirement.

#### Scenario: Matching event records at zero sampling
- **GIVEN** an SDK with a configurable trigger match type and session replay enabled
- **AND** the remote config sets the trigger match type to "any"
- **AND** the remote config configures event trigger "$pageview" and a sample rate of 0.0
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should be active

#### Scenario: Sampled-in session records before any trigger fires
- **GIVEN** an SDK with a configurable trigger match type and session replay enabled
- **AND** the remote config sets the trigger match type to "any"
- **AND** the remote config configures event trigger "$pageview" and a sample rate of 1.0
- **WHEN** the SDK resolves whether to record the current session before "$pageview" is captured
- **THEN** session recording should be active

#### Scenario: No control satisfied does not record
- **GIVEN** an SDK with a configurable trigger match type and session replay enabled
- **AND** the remote config sets the trigger match type to "any"
- **AND** the remote config configures event trigger "$pageview" and a sample rate of 0.0
- **WHEN** the SDK resolves whether to record the current session before "$pageview" is captured
- **THEN** session recording should not be active

### Requirement: Hybrid (multi-layer) SDK ingestion controls

The SDK SHALL treat the ingestion-control decision as one logical decision across layers when it is composed of a managed layer (e.g. Dart, JavaScript) over an embedded native SDK that owns replay capture (e.g. `posthog-ios` / `posthog-android`). In such SDKs the analytics capture pipeline and the replay subsystem can live on different layers, so the controls SHALL be coordinated rather than evaluated independently per layer:

- **Event triggers SHALL evaluate against the same client-captured events regardless of layer.** Where capture and replay live on different layers — for example `posthog-react-native`, which captures analytics in JavaScript while replay runs natively — the SDK SHALL forward each client-captured event name to the layer that performs event-trigger matching, so triggers match the events the application actually captures. Where the managed layer already routes capture through the embedded native SDK's own capture pipeline — for example `posthog-flutter` — this happens through that pipeline and no additional forwarding is required.
- **The layers SHALL share a single session id.** The sampling decision and trigger-activation persistence are both keyed on the session id, so the managed and native layers SHALL agree on the current session id; otherwise their sampling decisions and "activation persists for the session" guarantees diverge.
- **Replay capture MAY be native, managed, or split across layers.** Which layer renders snapshots is an allowed variation; the gating decision (enablement, linked flag, sampling, triggers, minimum duration) SHALL remain one logical decision regardless.

This requirement applies only to hybrid SDKs that span a managed layer and an embedded native replay SDK. Single-layer SDKs (browser, native iOS/Android) are unaffected.

#### Scenario: Managed-layer event activates replay in the native layer
- **GIVEN** a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
- **AND** session replay is enabled
- **AND** the remote config configures event trigger "$pageview"
- **AND** session recording is not active because the trigger has not fired
- **WHEN** the client captures an event named "$pageview" on the managed layer
- **THEN** the event name should be forwarded to the layer that matches event triggers
- **AND** session recording should be active

#### Scenario: Layers share one session id for a consistent decision
- **GIVEN** a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
- **AND** session replay is enabled
- **AND** the remote config sets the recording sample rate to 0.0
- **WHEN** the managed and native layers resolve whether to record the current session
- **THEN** both layers should use the same session id
- **AND** both layers should reach the same sampling decision

