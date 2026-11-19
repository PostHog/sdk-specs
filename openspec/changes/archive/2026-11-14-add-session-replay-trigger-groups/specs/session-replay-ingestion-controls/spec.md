## MODIFIED Requirements

### Requirement: Minimum-duration buffering gate

When the remote `sessionRecording` config uses the V1 trigger configuration and specifies `minimumDurationMilliseconds`, the SDK SHALL buffer captured replay data and SHALL NOT emit a session's replay data until the session's captured activity has reached the configured minimum duration. A session whose captured activity never reaches the minimum SHALL NOT have its replay data emitted. The minimum-duration gate governs when buffered data is emitted; it does not by itself decide whether the other controls activate recording.

When the remote config selects trigger groups (`session-replay-trigger-groups`), `minimumDurationMilliseconds` SHALL NOT apply. The minimum is then the effective group minimum that spec defines — the lowest `minDurationMs` among the activated groups — and it keeps the same role: a release gate on already-activated replay data, never part of the record / don't-record combination.

This requirement applies to all replay-capable SDKs.

#### Scenario: Replay data is withheld below the minimum duration
- **GIVEN** session replay is enabled and otherwise eligible
- **AND** the remote config sets the minimum duration to 5000 milliseconds
- **WHEN** the session has captured less than 5000 milliseconds of activity
- **THEN** the session's replay data should not be emitted

#### Scenario: The V1 minimum does not apply under trigger groups
- **GIVEN** session replay is enabled
- **AND** the remote config selects trigger groups with one group that has no conditions and no `minDurationMs`
- **AND** the remote config also carries a V1 `minimumDurationMilliseconds` of 5000
- **WHEN** the session has captured less than 5000 milliseconds of activity
- **THEN** the session's replay data should be emitted

#### Scenario: Replay data is emitted once the minimum duration is reached
- **GIVEN** session replay is enabled and otherwise eligible
- **AND** the remote config sets the minimum duration to 5000 milliseconds
- **WHEN** the session's captured activity reaches or exceeds 5000 milliseconds
- **THEN** the buffered replay data should be emitted

### Requirement: Hybrid (multi-layer) SDK ingestion controls

The SDK SHALL treat the ingestion-control decision as one logical decision across layers when it is composed of a managed layer (e.g. Dart, JavaScript) over an embedded native SDK that owns replay capture (e.g. `posthog-ios` / `posthog-android`). In such SDKs the analytics capture pipeline and the replay subsystem can live on different layers, so the controls SHALL be coordinated rather than evaluated independently per layer:

- **Event triggers SHALL evaluate against the same client-captured events regardless of layer.** Where capture and replay live on different layers — for example `posthog-react-native`, which captures analytics in JavaScript while replay runs natively — the SDK SHALL forward each client-captured event name to the layer that performs event-trigger matching, so triggers match the events the application actually captures. Where the managed layer already routes capture through the embedded native SDK's own capture pipeline — for example `posthog-flutter` — this happens through that pipeline and no additional forwarding is required.
- **The layers SHALL share a single session id.** The sampling decision and trigger-activation persistence are both keyed on the session id, so the managed and native layers SHALL agree on the current session id; otherwise their sampling decisions and "activation persists for the session" guarantees diverge.
- **Trigger groups SHALL be evaluated by the managed layer that owns event capture.** When the remote config selects trigger groups (`session-replay-trigger-groups`), the layer that captures analytics events — for example the JavaScript layer of `posthog-react-native` — SHALL evaluate the groups, and the embedded native SDK SHALL apply none of the V1 gating fields for that host ("Ignore the V1 gating fields under trigger groups" in `session-replay-trigger-groups`); it SHALL keep the replay enablement gate and the URL blocklist, and SHALL apply the minimum duration and the local sample rate the managed layer hands it. The single logical decision then includes the union across groups and the effective group minimum; the managed layer SHALL hand that minimum to the native layer, which holds and releases replay data by it as the minimum-duration gate describes. The managed layer SHALL hand the native layer only the app's local sample rate, never the remote V1 `sampleRate`, and the native layer SHALL apply it as the cap after the group decision ("Local sample rate under trigger groups" in `session-replay-trigger-groups`). This rule is a cross-SDK decision for hybrid SDKs; no single-layer reference exhibits it.
- **Replay capture MAY be native, managed, or split across layers.** Which layer renders snapshots is an allowed variation; the gating decision (enablement, linked flag, sampling, triggers, minimum duration, trigger groups and their effective minimum) SHALL remain one logical decision regardless.

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

#### Scenario: Managed layer owns trigger groups in a hybrid SDK
- **GIVEN** a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
- **AND** session replay is enabled
- **AND** the remote config selects trigger groups with one group whose event leg is "$pageview" and whose `minDurationMs` is 2000
- **WHEN** the client captures an event named "$pageview" on the managed layer
- **THEN** the managed layer should activate the group and start recording in the native layer
- **AND** the native layer should apply no V1 linked flag, remote sample rate, or trigger gate for that host
- **AND** the native layer should hold the session's replay data until 2000 milliseconds of activity, the minimum the managed layer handed it

### Requirement: Interaction hold for unconfirmed-activity recording epochs

When a new recording epoch begins — whether from a session id rotating because of an inactivity/idle timeout, or from a fresh (non-rotation) session start — without confirmed user activity for that epoch, the SDK SHALL withhold emitting the epoch's buffered replay data until the earliest of: the first genuine user interaction is captured, an event/URL trigger independently activates recording, or an explicit recording override (for example a `startSessionRecording(...)`-style call, which is explicit intent to record) is invoked. Buffered data held under this rule that is never released SHALL NOT be emitted. A clean page/app unload SHALL release and ship a held fresh-start epoch's buffered data, preserving pre-hold behavior for passive visits (e.g. reading, watching); a held rotation-born epoch's data SHALL NOT be released on unload and is discarded instead — an idle tab that rotates and is never interacted with again must not ship a recording.

When adding the next replay event would make a held epoch's buffered data exceed the emission size cap (the buffer size at which the SDK would otherwise flush a non-held buffer as a single emission), the SDK SHALL stop collecting further replay data for that epoch until the hold is released but SHALL NOT discard what it has already buffered — the cap bounds the memory either way, and discarding would lose the epoch start, which the hold exists to preserve. On release the retained data SHALL be emitted, and the SDK SHALL take a fresh full snapshot so playback is continuous across the gap between the cap and the release point. Reaching the cap SHALL NOT by itself make a held fresh-start epoch ineligible for the clean-unload release. A held epoch at the cap that is never released SHALL still emit nothing.

A trigger group (`session-replay-trigger-groups`) with a matching event leg counts as an event trigger for this release, even while the group stays pending on another leg; a URL-leg or flag-leg match does not, because those legs fire without a human present. Releasing the hold does not by itself make the group eligible: group eligibility, sampling, the effective minimum duration, and the URL blocklist remain separate emission gates. Reference: posthog-js `origin/main` `480395c443`, `packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:1044-1050` (`_onTriggerActivated` releases the hold only for `triggerType === 'event'`; reached from `recording-strategies.ts:504-506` with no combined-status check, `:508-510` at `eb2f69258`; no posthog-js test on `origin/main` covers an event leg on a group that stays pending on another leg, source only). Covering tests: `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:2262` ("an event trigger match releases the hold and ships under the rotated session id"), `:2292` ("an event trigger whose property filters do not match retains the hold"), `:2312` ("a URL trigger activation does not release the hold"), `:2329` ("releases a hold that begins after the initial-flush unhook optimization").

This requirement applies to SDKs whose sessions can start or rotate without a confirmed-interaction signal (currently posthog-js / web). SDKs without this concept, or whose sessions never start/rotate this way, are exempt.

#### Scenario: Idle-timeout rotation withholds recording until interaction
- **GIVEN** session replay is enabled and active
- **AND** the current session is idle with no confirmed user interaction
- **WHEN** the session id rotates because of an inactivity timeout
- **THEN** the rotated session's replay data should be withheld
- **WHEN** the client captures a genuine user interaction event
- **THEN** the withheld replay data should be released and recording should be active

#### Scenario: A fresh session start without confirmed activity is held until interaction
- **GIVEN** session replay is enabled
- **AND** the SDK starts a brand-new session that is not the result of an idle-timeout rotation
- **AND** no user activity has been confirmed for the new session yet
- **WHEN** the SDK resolves whether to record the session
- **THEN** the session's replay data should be withheld
- **WHEN** the client captures a genuine user interaction event
- **THEN** the withheld replay data should be released and recording should be active

#### Scenario: A clean unload ships a held fresh-start epoch but not a held rotation-born epoch
- **GIVEN** session replay is enabled
- **AND** a fresh session start is held with no confirmed user activity
- **WHEN** the page or app unloads cleanly
- **THEN** the held fresh-start epoch's buffered replay data should be released and shipped
- **GIVEN** a rotated session is held with no confirmed user activity
- **WHEN** the page or app unloads cleanly
- **THEN** the held rotation-born epoch's buffered replay data should be discarded, not shipped

#### Scenario: A held epoch at the size cap keeps its data and ships it on release
- **GIVEN** session replay is enabled
- **AND** a recording epoch is held with no confirmed user activity
- **WHEN** adding the next replay event would make the held epoch's buffered data exceed the emission size cap
- **THEN** no replay data should be emitted
- **AND** further replay data for the epoch should not be collected
- **AND** the data buffered before the cap should be retained
- **WHEN** the client captures a genuine user interaction event
- **THEN** the retained buffered data should be emitted
- **AND** a fresh full snapshot should be taken so playback continues across the gap

#### Scenario: A clean unload ships a fresh-start hold that reached the size cap
- **GIVEN** session replay is enabled
- **AND** a fresh session start is held with no confirmed user activity
- **AND** the held epoch has stopped collecting because the next replay event would have made its buffered data exceed the emission size cap
- **WHEN** the page or app unloads cleanly
- **THEN** the retained buffered data should be released and shipped
- **AND** a fresh full snapshot should be taken so playback continues across the gap

#### Scenario: An event-leg trigger-group activation releases the hold but a URL-leg activation does not
- **GIVEN** session replay is enabled and the remote config selects trigger groups
- **AND** a rotated session is held with no confirmed user activity
- **WHEN** a group whose URL leg matches the current URL activates
- **THEN** the held replay data should remain withheld
- **WHEN** the client captures an event that matches a group's event leg
- **THEN** the withheld replay data should be released

#### Scenario: A matching event leg releases the hold while its group stays pending
- **GIVEN** session replay is enabled and the remote config selects trigger groups
- **AND** a group with match type "all" has event condition "$pageview" and a URL condition matching "/checkout"
- **AND** a rotated session is held with no confirmed user activity and the current URL does not match "/checkout"
- **WHEN** the client captures an event named "$pageview"
- **THEN** the hold should be released
- **AND** the group should remain pending
- **AND** no replay data should be emitted
