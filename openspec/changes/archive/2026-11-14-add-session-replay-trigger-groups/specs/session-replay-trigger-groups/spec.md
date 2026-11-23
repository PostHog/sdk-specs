## ADDED Requirements

### Requirement: Select trigger groups over the V1 fields

The SDK SHALL evaluate replay ingestion with trigger groups when the remote `sessionRecording`
config carries `version: 2` **and** a `triggerGroups` array with at least one entry. In every other
case — `version` absent or `1`, `triggerGroups` absent, or `triggerGroups` an empty array — the SDK
SHALL evaluate the flat V1 fields as `session-replay-ingestion-controls` specifies. The selection
SHALL be re-made each time the remote config is resolved, so a config that gains or loses groups
switches the SDK between the two models. The server sends both shapes in one config: a team with
groups receives `version: 2`, `triggerGroups`, and the V1 fields side by side, so an SDK that does
not implement this capability keeps working on the V1 fields.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:1247-1268`:
`isV2 = config?.version === 2 && config?.triggerGroups && config.triggerGroups.length > 0`, then
`V2TriggerGroupStrategy` or `V1RecordingStrategy`). The strategy warns and returns when it is
given no groups (`recording-strategies.ts:370-374`). Every posthog-js file cited in this capability
is byte-identical at the current `origin/main` `f216d94acb`. Server: PostHog/posthog
`origin/master` `0280b22a` `posthog/models/remote_config.py:231-243` returns `version: 2`,
`triggerGroups`, and the V1 fields together, and falls back to a V1-only config when no readable
group remains (`:234-235`, "posthog-js uses the V1 fields when triggerGroups is empty").

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:8762-9583`
(`describe('V2 Trigger Groups Integration')`) exercises the V2 path end to end. The fallback
(`version: 2` with an empty or missing `triggerGroups`): No posthog-js test on `origin/main`
covers this; decision-based (source only: `lazy-loaded-session-recorder.ts:1247-1268` and the server
comment at `remote_config.py:231-235`).

#### Scenario: Version 2 with groups ignores the V1 sample rate
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and a V1 `sampleRate` of 0.0
- **AND** the remote config configures one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: Version 2 with an empty group list uses the V1 fields
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and an empty `triggerGroups` array
- **AND** the remote config sets the V1 `sampleRate` to 0.0
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

### Requirement: Ignore the V1 gating fields under trigger groups

While trigger groups are selected, the SDK SHALL NOT apply the remote `linkedFlag`, `sampleRate`,
`eventTriggers`, `urlTriggers`, `triggerMatchType`, or `minimumDurationMilliseconds` fields. The
groups alone decide whether the session records, which events, URLs, and flags activate it, how it
is sampled, and which minimum duration applies. The replay enablement gate and the `urlBlocklist`
(see "URL blocklist stays global") are not V1 gating fields and stay in force.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:370-386`: the V2
strategy configures only the URL blocklist from the remote config, "V2 needs URL blocklist (but
not URL triggers)"; `triggerMatching.ts:799-861`: `triggerGroupsMatchSessionRecordingStatus`
reads the blocklist, the group matchers, and the per-group sampling results, never the V1
`isSampled`, linked-flag, event-trigger, or URL-trigger status; `recording-strategies.ts:404-422`:
the minimum comes from the groups).

Covering test: No posthog-js test on `origin/main` covers this; decision-based (no V2 test sets a
V1 field alongside groups).

#### Scenario: A V1 linked flag does not block a group
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and links recording to boolean flag "replay-flag"
- **AND** feature flag "replay-flag" is not enabled for the user
- **AND** the remote config configures one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: A V1 event trigger does not activate recording under groups
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures V1 event trigger "$pageview"
- **AND** the remote config configures one trigger group with event condition "checkout_started" and a sample rate of 1.0
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should not be active

### Requirement: Local sample rate under trigger groups

A web SDK SHALL NOT apply a local sample rate while trigger groups are selected; the per-group
rates alone sample the session. A mobile SDK that exposes a local `sessionReplayConfig.sampleRate`
SHALL apply it as a cap after the group decision: a session SHALL record only when the trigger
groups permit it (see "Union across groups") **and** the local rate samples the session id in, with
the same session-id-keyed decision the V1 sampling requirement of `session-replay-ingestion-controls`
uses. The local rate SHALL never record a session the groups refused. When no local rate is set,
the group decision alone applies. The local rate is an app-level knob, not the V1 remote
`sampleRate`, which "Ignore the V1 gating fields under trigger groups" still forbids.

This requirement applies to all replay-capable SDKs. The cap applies only to mobile SDKs with a
local sample-rate option, and to hybrid SDKs over them (see "Hybrid SDKs").

Reference (web half): posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/session-recording.ts:267-275` resolves
`localSampleRate ?? remoteSampleRate` into the persisted config; `lazy-loaded-session-recorder.ts:626-629`
exposes only that remote-config value as `_sampleRate`; the V2 status function
`triggerMatching.ts:799-861` and the V2 strategy `recording-strategies.ts:519-588` never read it).
These lines are unchanged at `origin/main` `b4bbe65d55`.

Mobile half: decision-based, with no posthog-js reference (web has no local rate under V2). It
records cross-SDK decision D1. posthog-ios `feat/replay-v2-trigger-groups` `b3db5efb8a`
`PostHog/Replay/PostHogReplayIntegration.swift:486-495` (`shouldRecordSession`: refuse when the
groups do not permit the session, then sample the session id with the local rate) and
posthog-android `feat/replay-v2-trigger-groups` `f1fb970362`
`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfig.kt:1459-1472`
(`makeSamplingDecision`: the group decision first, then `localSampleRate`, with the remote rate
dropped under groups) implement it.

Covering test: No posthog-js test on `origin/main` covers the web half; decision-based (source
only). The mobile half has no posthog-js analog; decision-based (D1).

#### Scenario: A web SDK ignores the local sample rate under groups
- **GIVEN** posthog-js is initialized with a local `session_recording.sampleRate` of 0.0
- **AND** the remote config sets `version` to 2 and configures one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: A mobile local sample rate caps the group decision
- **GIVEN** a mobile SDK initialized with a local replay sample rate of 0.0
- **AND** the remote config sets `version` to 2 and configures one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: A mobile local sample rate never records a session the groups refused
- **GIVEN** a mobile SDK initialized with a local replay sample rate of 1.0
- **AND** the remote config sets `version` to 2 and configures one trigger group with a sample rate of 0.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

### Requirement: Trigger group shape

The SDK SHALL read each entry of `triggerGroups` as an object with `id` (string), an optional
`name` (string), `sampleRate` (decimal between 0 and 1; see "Coerce a group sample rate" for other
wire forms), an optional `minDurationMs` (milliseconds), and `conditions`. A missing or `null`
`name` SHALL be read as the empty string; the name is a display field only, so matching never
depends on it, and a debug entry for an unnamed group carries the empty string where the name goes.
`conditions` SHALL be read as an optional `matchType`: only the literal `any` SHALL select OR, and
a missing `matchType`, or any other value, SHALL be read as `all`. `conditions` also carries an
optional `events` list of `{ name, properties? }` objects, an optional `urls`
list of `{ url, matching: 'regex' }` objects, an optional `flag` (a flag key string or
`{ flag, variant }`), and optional group-level `properties` (property filters, see "Property
filter semantics"). A missing `events`, `urls`, or `flag` SHALL be read as that leg being
unconfigured. The server normalizes bare event-name strings to `{ name }` and flag objects to the
SDK form before sending, so the SDK does not need to accept bare strings in `events`; an SDK MAY
accept them as a tolerance.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser-common/src/types/remote-config.ts:19-50`: `SessionRecordingEventTrigger`,
`SessionRecordingTriggerPropertyFilter`, `SessionRecordingTriggerGroup`). Server: PostHog/posthog
`origin/master` `0280b22a` `posthog/models/remote_config.py:203-222` normalizes `events` entries
to `{ "name": e }` and a stored flag object to the SDK flag form, and drops a group whose
`conditions` is not an object or whose `events` is neither null nor a list. The validator at
`posthog/api/team/session_recording_settings.py:136` requires only `id`, `sampleRate`, and
`conditions` on a group (its docstring at `:95` marks `name` optional, and `:99` documents
`matchType` without requiring it). posthog-js combines a group's legs with
`group.conditions.matchType === 'any' ? new OrTriggerMatching(matchers) : new AndTriggerMatching(matchers)`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:607-610`, unchanged at
`eb2f69258`), so a missing value means AND. For a missing `name`, posthog-js renders the pending
debug entry from `matcher.group.name` (`recording-strategies.ts:656`), which prints `undefined`;
reading it as the empty string is a debug-only difference that every mobile port already makes.

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:66`
("should create matcher with event triggers and ANY match type"), `:81` ("should create matcher
with URL triggers and ALL match type"), `:97` ("should create matcher with feature flag"), `:135`
("should create matcher with minDurationMs").

#### Scenario: A full group is read with every leg
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2
- **AND** the remote config configures a trigger group with id "g1", name "Checkout errors", sample rate 1.0, minimum duration 2000 milliseconds, match type "all", event condition "$exception", URL condition matching "/checkout", and boolean flag condition "replay-flag"
- **WHEN** the SDK reads the remote config
- **THEN** the SDK should track one trigger group whose event, URL, and flag legs are configured
- **AND** the group's minimum duration should be 2000 milliseconds

#### Scenario: A group without a name is read and evaluated
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with id "g1", no name, no conditions, and a sample rate of 1.0
- **WHEN** the SDK resolves whether to record the current session
- **THEN** the SDK should track one trigger group whose name is the empty string
- **AND** session recording should be active

#### Scenario: An omitted match type requires every configured leg
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with no match type, event condition "$exception", boolean flag condition "replay-flag", and a sample rate of 1.0
- **AND** feature flag "replay-flag" is not enabled for the user
- **WHEN** the client captures an event named "$exception"
- **THEN** session recording should not be active
- **WHEN** feature flag "replay-flag" becomes enabled for the user
- **THEN** session recording should be active

#### Scenario: A missing leg is read as unconfigured
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2
- **AND** the remote config configures a trigger group with match type "all", event condition "$exception", and no `urls` or `flag`
- **WHEN** the client captures an event named "$exception"
- **THEN** session recording should be active

### Requirement: A group with no conditions activates at once

A trigger group whose `conditions` configure no events, no URLs, and no flag SHALL count as
activated for every session as soon as the config is read, before any event is captured. Such a
group records every session its sample rate samples in.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:582-589`: "Empty conditions
= trigger immediately on session start", `AlwaysActivatedTriggerMatching`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:8974`
("triggers immediately when trigger group has empty conditions").

#### Scenario: A group with no conditions records at once
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session before any event is captured
- **THEN** session recording should be active

### Requirement: Combine a group's legs by its match type

Within one group the SDK SHALL combine the configured legs (event, URL or screen, flag) by the
group's `matchType`: with `all` the group activates only when every configured leg is satisfied;
with `any` it activates when at least one configured leg is satisfied. A leg that is not configured
SHALL be ignored by the combination and SHALL neither satisfy nor block the group. While a group
with `all` has at least one configured leg satisfied and another pending, the group is pending, not
activated.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:607-612`: `OrTriggerMatching`
for `any`, `AndTriggerMatching` otherwise; `:130-152`: `orTriggerStatus` and `andTriggerStatus`,
where `trigger_disabled` — an unconfigured leg — is dropped before combining).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:66`
("should create matcher with event triggers and ANY match type"), `:81` ("should create matcher
with URL triggers and ALL match type");
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9183` ("matchType
all requires ALL conditions to match before triggering").

#### Scenario: A group with match type `all` needs every configured leg
- **GIVEN** a URL-capable SDK with session replay enabled
- **AND** the remote config sets `version` to 2
- **AND** the remote config configures a trigger group with match type "all", event condition "error", URL condition matching "/checkout", and a sample rate of 1.0
- **WHEN** the client captures an event named "error" while the current URL does not match "/checkout"
- **THEN** session recording should not be active
- **WHEN** the current URL changes to one matching "/checkout"
- **THEN** session recording should be active

#### Scenario: A group with match type `any` needs one leg
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2
- **AND** the remote config configures a trigger group with match type "any", event condition "error", boolean flag condition "replay-flag", and a sample rate of 1.0
- **AND** feature flag "replay-flag" is not enabled for the user
- **WHEN** the client captures an event named "error"
- **THEN** session recording should be active

### Requirement: Event leg

A client-captured event SHALL satisfy a group's event leg when its name equals the `name` of a
configured `events` entry **and** that entry's `properties` filters pass against the event (see
"Property filter semantics"). An entry with no `properties`, or an empty list, SHALL match on name
alone. When a group lists the same event name more than once, the entries SHALL be a disjunction:
the leg is satisfied when any one of them matches. Events are observed as they pass through the
capture pipeline, after the before-send hook, exactly as the V1 event trigger in
`session-replay-ingestion-controls` observes them.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:474-509`: per-group
`checkEventTriggerConditions`, then "Treat same-name entries as a disjunction", "An entry with no
properties is treated as an unconditional match", `matchTriggerPropertyFilters(t.properties,
event.properties, personProperties)`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9315`
("blocks event trigger activation when per-event property filters fail"), `:9354` ("treats
multiple same-name event entries as a disjunction of property filters"), `:9402` ("does not
activate when all same-name event clauses fail");
`packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:356-410` (`describe('Event
trigger property evaluation')`).

#### Scenario: An event leg activates its group
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "checkout_started" and a sample rate of 1.0
- **AND** session recording is not active because no group has activated
- **WHEN** the client captures an event named "checkout_started"
- **THEN** session recording should be active

#### Scenario: An event leg with failing property filters does not activate
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "purchase" filtered on event property "amount" greater than 100, and a sample rate of 1.0
- **WHEN** the client captures an event named "purchase" with property "amount" set to 50
- **THEN** session recording should not be active
- **WHEN** the client captures an event named "purchase" with property "amount" set to 200
- **THEN** session recording should be active

#### Scenario: Same-name event entries are a disjunction
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with two event conditions named "purchase": one filtered on event property "amount" greater than 100 and one filtered on person property "plan" equal to "vip"
- **AND** the current person has property "plan" set to "vip"
- **WHEN** the client captures an event named "purchase" with property "amount" set to 50
- **THEN** session recording should be active

### Requirement: URL leg (URL-capable SDKs)

The current URL SHALL satisfy a group's URL leg when it matches any of the group's `urls` regex
patterns. The leg is evaluated when the config is read and on each navigation, and its activation
persists for the session like the event leg's.

This requirement applies only to SDKs with a URL / navigation concept (for example the browser SDK).
SDKs without URLs match the same patterns against screen names instead; see "Screen leg (mobile)".

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:436-453`: per-group
`checkUrlTriggerConditions` with the group-level property check; `triggerMatching.ts:364`:
`URLTriggerMatching.checkUrlTriggerConditions`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9183`
("matchType all requires ALL conditions to match before triggering" — the URL leg is the second
condition).

#### Scenario: A matching URL activates a group
- **GIVEN** a URL-capable SDK with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with URL condition matching "/checkout" and a sample rate of 1.0
- **AND** session recording is not active
- **WHEN** the current URL changes to one matching "/checkout"
- **THEN** session recording should be active

### Requirement: Screen leg (mobile)

A mobile SDK SHALL evaluate a group's `urls` patterns against the `$screen_name` property of
captured `$screen` events: the leg is satisfied when a captured `$screen` event's `$screen_name`
matches any of the group's regex patterns. A `$screen` event without a `$screen_name` SHALL NOT
satisfy the leg. The screen leg is the mobile reading of the URL leg; a group's `urls` therefore
have one meaning on every platform (where the user is), and the UI does not need a mobile-specific
condition kind.

This requirement applies only to SDKs without a URL concept that capture `$screen` events
(`posthog-ios`, `posthog-android`, and hybrid SDKs over them).

Reference: no posthog-js analog (web has URLs). posthog-ios `feat/replay-v2-trigger-groups`
`23ffc5a905` `PostHog/Replay/PostHogTriggerGroupsEvaluator.swift:89-97` matches
`eventProperties["$screen_name"]` of a `$screen` event against `conditions.urls`. Lines `:95-96`
also gate the screen leg with the group-level filters against the event's properties, which
diverges from the URL leg in posthog-js and changes to match "Group-level property filters".

Covering test: No posthog-js test on `origin/main` covers this; decision-based (mobile adaptation
with no js analog; contract C8/C9 context, iOS `:89-97`).

#### Scenario: A screen leg activates on `$screen_name`
- **GIVEN** a mobile SDK with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with URL condition matching "Checkout" and a sample rate of 1.0
- **AND** session recording is not active
- **WHEN** the client captures a "$screen" event with "$screen_name" set to "CheckoutScreen"
- **THEN** session recording should be active

#### Scenario: A screen event without a screen name does not activate the leg
- **GIVEN** a mobile SDK with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with URL condition matching "Checkout" and a sample rate of 1.0
- **WHEN** the client captures a "$screen" event with no "$screen_name" property
- **THEN** session recording should not be active

### Requirement: Flag leg

A group's `flag` leg SHALL be satisfied by the same rules as the V1 linked flag in
`session-replay-ingestion-controls`: a boolean flag key is satisfied when the flag is `true`; a
`{ flag, variant }` object is satisfied only when the flag resolves to that variant; a flag key
string pointing at a multivariate flag is satisfied for any present variant; a missing or
quota-limited flag is not satisfied. Where the SDK tracks feature-flag usage, evaluating the leg
SHALL report the flag as called. The leg is re-evaluated when feature flags change.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:580` constructs a
`LinkedFlagMatching` per group and `:605` feeds it `linkedFlag: group.conditions.flag`, so the
group reuses the V1 matcher unchanged).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:97`
("should create matcher with feature flag" — boolean form). The `{ flag, variant }` form inside a
group: No posthog-js test on `origin/main` covers this; decision-based (the source reuses
`LinkedFlagMatching`, whose variant handling the V1 requirement already covers).

#### Scenario: A boolean flag leg activates a group
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with boolean flag condition "replay-flag" and a sample rate of 1.0
- **AND** feature flag "replay-flag" is enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: A flag leg with a variant must match the variant
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with flag condition "replay-flag" variant "test" and a sample rate of 1.0
- **AND** feature flag "replay-flag" resolves to variant "control" for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

### Requirement: Group-level property filters

When a group configures `conditions.properties`, the SDK SHALL evaluate those filters before an
event leg or URL/screen leg activates the group, and SHALL NOT activate the group through that leg
while they fail. The filters SHALL NOT gate a flag leg or a group with no event, URL, or flag
conditions (see "A group with no conditions activates at once"). For an event-leg
activation the filters SHALL be evaluated against the captured event's properties (and the stored
person properties). For a URL-leg or screen-leg activation the filters SHALL be evaluated with no
event properties: `type: person` filters read the stored person properties and work as usual, a
positive filter on an event property never matches, and a negative filter (`is_not`,
`not_icontains`, `not_regex`) on an event property matches because the property is absent. Group-
level filters and an event entry's own `properties` are both required for an event-leg activation.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:669-679`:
`_checkGroupLevelProperties(matcher, eventProperties)` with the stored person properties;
`:479-482`: event leg passes `event.properties`; `:442-445`: URL leg passes `undefined`; the
flag callback at `:689-696` does not check them; `triggerMatching.ts:582-589` builds an
`AlwaysActivatedTriggerMatching` for a group with no events, URLs, or flag, and the class at
`:200-207` returns activated with no filter). The `_checkGroupLevelProperties` calls are at `:443`
and `:480` at `480395c443` (`:447` and `:484` at `eb2f69258`). No posthog-js test on `origin/main`
covers a flag-only or conditionless group with `properties`; source only.

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9451`
("blocks trigger activation when group-level property filters fail"), `:9490` ("checks both
group-level and per-event properties (both must pass)"). The URL leg with no event properties: No
posthog-js test on `origin/main` covers this; decision-based (contract C9; `recording-strategies.ts:443`
passes `undefined`).

#### Scenario: A group-level filter gates an event activation
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$exception", group-level filter on person property "plan" equal to "vip", and a sample rate of 1.0
- **AND** the current person has property "plan" set to "free"
- **WHEN** the client captures an event named "$exception"
- **THEN** session recording should not be active
- **WHEN** the current person's property "plan" changes to "vip" and the client captures an event named "$exception"
- **THEN** session recording should be active

#### Scenario: A group-level person filter gates a URL or screen activation
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with a URL condition matching "Checkout", group-level filter on person property "plan" equal to "vip", and a sample rate of 1.0
- **AND** the current person has property "plan" set to "free"
- **WHEN** the current URL or screen name changes to one matching "Checkout"
- **THEN** session recording should not be active

#### Scenario: A positive event filter never matches a URL or screen activation
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with a URL condition matching "Checkout", group-level filter on event property "amount" greater than 100, and a sample rate of 1.0
- **WHEN** the current URL or screen name changes to one matching "Checkout"
- **THEN** session recording should not be active

#### Scenario: Group-level filters do not gate a flag leg
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group whose only condition is boolean flag "replay-flag", with group-level filter on person property "plan" equal to "vip" and a sample rate of 1.0
- **AND** the current person has property "plan" set to "free"
- **AND** feature flag "replay-flag" is enabled for the user
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: Group-level filters do not gate a group with no conditions
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with no events, URLs, or flag, a group-level filter on person property "plan" equal to "vip", and a sample rate of 1.0
- **AND** the current person has property "plan" set to "free"
- **WHEN** the SDK resolves whether to record the current session before any event is captured
- **THEN** session recording should be active

#### Scenario: A negative event filter matches a URL or screen activation
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with a URL condition matching "Checkout", group-level filter on event property "country" not equal to "EU", and a sample rate of 1.0
- **WHEN** the current URL or screen name changes to one matching "Checkout"
- **THEN** session recording should be active

### Requirement: Property filter semantics

A property filter list SHALL match only when every filter matches (implicit AND); an absent or
empty list SHALL match. Each filter SHALL be read as `key`, `type` (`event` or `person`), an
optional `operator`, and `value`. A `type: person` filter SHALL read the SDK's stored person
properties (the properties set through identify / person-property APIs); any other type SHALL read
the event's properties. `operator` SHALL default to `exact`. The supported operators SHALL be
`exact`, `is_not`, `icontains`, `not_icontains`, `regex`, `not_regex`, `gt`, and `lt`; an unknown
operator SHALL NOT match. The SDK SHALL check the property's absence before anything else: when
the property is missing or `null`, the filter SHALL match if its operator is one of the negative
operators `is_not`, `not_icontains`, or `not_regex`, and SHALL NOT match otherwise, whatever the
filter's `value`. Only for a present property SHALL an unknown operator, or a filter whose `value`
is missing or `null`, fail to match. Values SHALL be normalized to string arrays: a
scalar becomes a one-element array and each element is converted to a string. For the positive
operators `exact`, `icontains`, `regex`, `gt`, and `lt`, the filter SHALL match when any property
element matches any filter value. For the negative operators `is_not`, `not_icontains`, and
`not_regex`, the filter SHALL match only when every property element fails to match every filter
value, so one match rejects. `exact` and `is_not` SHALL compare the strings for equality, `icontains`
and `not_icontains` SHALL compare them case-insensitively, and `regex` and `not_regex` SHALL test the
property string against the filter value as a pattern. `gt` and `lt` SHALL parse both the property
value and the filter value with JavaScript `parseFloat` semantics and compare the numbers; a
property value that does not parse SHALL NOT match, and a filter value that does not parse never
matches either.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser-common/src/utils/property-utils.ts:30`: `NEGATIVE_OPERATORS`; `:36-72`:
`matchTriggerPropertyFilters` — `every`, `type === 'person' ? personProperties :
eventProperties`, default `exact`; `:53-55` returns `NEGATIVE_OPERATORS.has(operator)` for a
missing or null property before the operator lookup and the filter-value check; then unknown
operator returns false, missing filter value returns false, `.map(String)` string-array
normalization at `:57-70`, then `propertyComparisons[operator](targetValues, actualValues)`). These
lines are unchanged at `origin/main` `b4bbe65d55`. The comparators are
`packages/core/src/surveys/property-matching.ts:29-46` at `480395c443`: `exact` / `regex` /
`icontains` use `values.some(... targets.some(...))`; `is_not` / `not_regex` / `not_icontains` use
`values.every(... targets.every(...))`; `icontains` and `not_icontains` lower-case both sides;
`gt` / `lt` apply `parseFloat` with an `!isNaN` guard on the property value. The matcher is called
from `recording-strategies.ts:498` (per-event filters) and `:678` (group-level filters); the
behavior is unchanged at `eb2f69258`. No posthog-js test on `origin/main` covers a negative
operator over a list, a `gt` or `lt` string-versus-number case, or a non-numeric `gt` value; source
only. Person properties come from
`$stored_person_properties` (`recording-strategies.ts:493`, `:677`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:152-353`
(`describe('matchTriggerPropertyFilters')`: exact, person, icontains, gt, regex, AND of filters,
OR within a value array, missing property, `is_not` / `not_icontains` / `not_regex` on a missing or
null property, default operator, array properties).

#### Scenario: Filters are ANDed and read the right property source
- **GIVEN** a trigger group with filters on event property "amount" greater than 100 and person property "plan" equal to "vip"
- **AND** the current person has property "plan" set to "vip"
- **WHEN** the filters are evaluated against an event with property "amount" set to 200
- **THEN** the filters should match
- **WHEN** the filters are evaluated against an event with property "amount" set to 50
- **THEN** the filters should not match

#### Scenario: A missing property matches only a negative operator
- **GIVEN** a trigger group with a filter on event property "country" not equal to "EU"
- **AND** a second trigger group with a filter on event property "country" equal to "US"
- **WHEN** the filters are evaluated against an event with no "country" property
- **THEN** the first group's filter should match
- **AND** the second group's filter should not match

#### Scenario: Absence is checked before the filter value
- **GIVEN** a trigger group with a filter on event property "country" with operator `is_not` and no value
- **WHEN** the filter is evaluated against an event with no "country" property
- **THEN** the filter should match
- **WHEN** the filter is evaluated against an event with property "country" set to "US"
- **THEN** the filter should not match

#### Scenario: A positive operator matches any element of a list
- **GIVEN** a trigger group with a filter on event property "tags" equal to the list "beta", "vip"
- **WHEN** the filters are evaluated against an event with property "tags" set to the list "vip", "eu"
- **THEN** the filter should match

#### Scenario: A negative operator rejects when any value matches
- **GIVEN** a trigger group with a filter on event property "country" with operator `is_not` and the list "EU", "US"
- **WHEN** the filters are evaluated against an event with property "country" set to "EU"
- **THEN** the filter should not match
- **WHEN** the filters are evaluated against an event with property "country" set to "UK"
- **THEN** the filter should match

#### Scenario: not_icontains is case-insensitive over an array property
- **GIVEN** a trigger group with a filter on event property "tags" with operator `not_icontains` and value "beta"
- **WHEN** the filters are evaluated against an event with property "tags" set to the list "vip", "Beta-2"
- **THEN** the filter should not match
- **WHEN** the filters are evaluated against an event with property "tags" set to the list "vip", "eu"
- **THEN** the filter should match

#### Scenario: gt and lt compare numbers
- **GIVEN** a trigger group with a filter on event property "amount" greater than "100"
- **WHEN** the filters are evaluated against an event with property "amount" set to "9"
- **THEN** the filter should not match
- **WHEN** the filters are evaluated against an event with property "amount" set to 200
- **THEN** the filter should match
- **GIVEN** a trigger group with a filter on event property "amount" less than "100"
- **WHEN** the filters are evaluated against an event with property "amount" set to 9
- **THEN** the filter should match

#### Scenario: A property value that does not parse as a number never matches gt
- **GIVEN** a trigger group with a filter on event property "amount" greater than "100"
- **WHEN** the filters are evaluated against an event with property "amount" set to "abc"
- **THEN** the filter should not match

### Requirement: Group activation lasts for the session

The SDK SHALL store each group's event, URL, and screen leg matches per group and per session id,
so a leg that matched once stays satisfied for the rest of that session without a second matching
event, URL, or screen, and so one group's activation never counts for another group. The SDK SHALL
NOT store a flag leg match: the flag leg SHALL be evaluated from the current flag value, so a group
whose activation depends on the flag returns to pending when the flag stops matching, and a flag
that matches again re-satisfies it. A group's activation is the combination, per its match type, of
its stored legs and the current flag leg. When the session id changes, the SDK
SHALL re-arm every group: the new session needs its own matching event, URL, screen, or flag. Where
the SDK persists state across page loads or process restarts, the persisted activation SHALL be
keyed on the session id so it is honored only for the session it belongs to.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:667-676`: `activateTrigger`
persists the session id under a per-group URL or event key, "prevents cross-group contamination
and survives page reloads"; `recording-strategies.ts:600-612`: the per-group keys are cleared with
the conditional-recording persistence). The flag leg is not stored:
`triggerMatching.ts:466-467` sets `this.linkedFlagSeen = linkedFlagMatches` on every flag
response, `:427-428` reads it for the status, and `activateTrigger` at `:664-676` persists only the
URL and event keys.

Covering test: No posthog-js test on `origin/main` covers this; decision-based (the V1 rotation
tests do not cover groups; the per-group persistence key is source only). No posthog-js test on
`origin/main` covers a flag leg that stops matching; source only.

#### Scenario: Activation is re-armed on a new session
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "checkout_started" and a sample rate of 1.0
- **AND** an event named "checkout_started" has activated the group for the current session
- **WHEN** the session id rotates to a new session
- **THEN** session recording should not be active until the client captures "checkout_started" again

#### Scenario: A flag leg follows the current flag value
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group whose only condition is boolean flag "replay-flag", with a sample rate of 1.0
- **AND** feature flag "replay-flag" is enabled for the user
- **AND** session recording is active
- **WHEN** feature flags reload and "replay-flag" is no longer enabled
- **THEN** the group should not be activated

#### Scenario: One group's activation does not activate another
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with event condition "checkout_started" and a trigger group "B" with event condition "$exception", both with a sample rate of 1.0
- **WHEN** the client captures an event named "checkout_started"
- **THEN** group "A" should be activated
- **AND** group "B" should not be activated

### Requirement: Per-group sampling

The SDK SHALL make one sampling decision per group per session, deterministic in the session id and
the group id: the group samples the session in when
`simpleHash(sessionId + groupId) % 100 < clamp(sampleRate * 100, 0, 100)`, where `simpleHash` is
the 32-bit string hash `hash = (hash << 5) - hash + charCode; hash |= 0` over each UTF-16 code unit
of the concatenated string, returned through `Math.abs`, and `clamp` bounds the percentage to
0–100. SDKs on other platforms SHALL reproduce this arithmetic so a session falls in the same bucket
for a given group on every platform. The decision SHALL be stored for the session and re-made when
the session id changes or the group's `sampleRate` changes; a stored decision without a session id
or rate, or with a different session id or rate, SHALL NOT be reused. A rate of 0 never samples in;
a rate of 1 always samples in.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:519-588`:
`makeSamplingDecisions`; `:564`: `sampleOnProperty(sessionId + groupId, sampleRate)`; `:539-563`:
re-decide on session change, rate change, or a legacy stored value; `:576-583`: the stored
`{ sessionId, sampleRate, sampled }`. `packages/browser/src/extensions/sampling.ts:12-19`:
`simpleHash` with `Math.abs`; `:24-26`: `simpleHash(prop) % 100 < clampToRange(percent * 100, 0,
100)`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9137`
("respects sampleRate < 1.0 and samples out when triggered" — rate 0 samples out), `:9017` ("does
not reuse a sampled-in trigger group decision when sampleRate is lowered to 0"), `:9066` ("does
not reuse a trigger group decision with $name" — missing and non-numeric stored rates), `:9106`
("does not reuse a legacy sampled-out trigger group decision when sampleRate is raised to 1"). The
hash input and `Math.abs`: No posthog-js test on `origin/main` covers this; decision-based
(contract C5 pins the web arithmetic for every SDK).

#### Scenario: A sampled-out group does not record
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "test_event" and a sample rate of 0.0
- **WHEN** the client captures an event named "test_event"
- **THEN** session recording should not be active

#### Scenario: The sampling decision is stable within a session and re-made on rotation
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with a sample rate of 0.5 and no conditions
- **AND** the SDK has made the group's sampling decision for the current session id
- **WHEN** the SDK re-resolves whether to record the same session id
- **THEN** the group's sampling decision should be unchanged
- **WHEN** the session id rotates and the SDK resolves recording for the new session id
- **THEN** a fresh sampling decision should be made for the group

#### Scenario: A changed rate re-decides sampling
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with a sample rate of 1.0 and no conditions
- **AND** the group has sampled the current session in
- **WHEN** the remote config changes the group's sample rate to 0.0 and the SDK re-resolves the same session
- **THEN** the group should sample the session out

#### Scenario: The sampling bucket is the web hash of session id and group id
- **GIVEN** a session id and a group id
- **WHEN** the SDK computes the group's sampling bucket
- **THEN** the bucket should equal `simpleHash(sessionId + groupId) % 100` as posthog-js computes it, where `simpleHash` already returns `Math.abs` of the 32-bit hash
- **AND** the session should be sampled in if and only if the bucket is below `sampleRate * 100` clamped to 0–100

### Requirement: Coerce a group sample rate

A group's `sampleRate` SHALL be read as a number between 0 and 1. When the wire value is a string,
the SDK SHALL ignore surrounding whitespace and parse it as a decimal; a blank string SHALL be read
as 0. A value that is not a number after parsing (an unparseable string, `NaN`) SHALL sample the
session in, as if the rate were 1. A JSON `null` SHALL be read as 0 and sample out. A number
outside 0–1 SHALL be clamped into that range. These coercions follow the arithmetic the web SDK
applies when it multiplies the raw value by 100 and clamps the result.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/sampling.ts:25`: `clampToRange(percent * 100, 0, 100)` — a
numeric string is coerced by `* 100` with padding ignored, `'' * 100` and `null * 100` are `0`,
and an unparseable string yields `NaN`; `packages/core/src/utils/number-utils.ts:12-31`:
`clampToRange` returns `max` for a non-number and clamps the rest;
`packages/core/src/utils/type-utils.ts:64-67`: `isNumber` rejects `NaN`). posthog-ios
`feat/replay-v2-trigger-groups` `23ffc5a905` `PostHog/Replay/PostHogTriggerGroups.swift:99-106`
coerces strings this way; it reads `null` as no rate (samples in) today and changes to 0.

Covering test: posthog-js `packages/core/src/utils/number-utils.spec.ts:8-29` ("returns max when
value is not a number" for `null` and `'not-a-number'`). String and `null` rates inside a group:
No posthog-js test on `origin/main` covers this; decision-based (contract C4 pins the web
coercion for every SDK).

#### Scenario: A blank-string group rate samples out and an unparseable one samples in
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with no conditions and the sample rate `<rate>`
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be `<state>`

  | rate              | state      |
  | `""`              | not active |
  | `" 1.0 "`         | active     |
  | `"not-a-number"`  | active     |
  | `null`            | not active |

### Requirement: Union across groups

The SDK SHALL record the session when at least one activated group has sampled it in, regardless of
any other group's state. While no activated group has sampled it in and at least one group is still
pending (configured legs not yet satisfied), the SDK SHALL NOT emit replay: posthog-js buffers and
mobile SDKs stay stopped, as the V1 event trigger allows. When every group is either not
activated with nothing pending, or activated but sampled out, the SDK SHALL NOT record. A group that
is sampled out never blocks another group that is sampled in.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:799-861`:
`triggerGroupsMatchSessionRecordingStatus` — `anyGroupSampled` → `sampled`, else `anyGroupPending`
→ `buffering`, else `disabled`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/triggerGroups.test.ts:463-538`
(`describe('triggerGroupsMatchSessionRecordingStatus - Union Behavior')`, "should return
$expectedStatus when $name"), `:540-567` (`describe('... - Edge Cases')`);
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:8915` ("tracks
multiple trigger groups with union behavior").

#### Scenario: One activated group sampled in records
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with event condition "$exception" and a sample rate of 0.0, and a trigger group "B" with event condition "$pageview" and a sample rate of 1.0
- **WHEN** the client captures an event named "$exception"
- **THEN** session recording should not be active
- **WHEN** the client captures an event named "$pageview"
- **THEN** session recording should be active

#### Scenario: Every activated group sampled out does not record
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures two trigger groups with no conditions, each with a sample rate of 0.0
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: A pending group withholds replay
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$exception" and a sample rate of 1.0
- **WHEN** the SDK resolves whether to record the current session before "$exception" is captured
- **THEN** no replay data should be emitted
- **AND** the SDK may buffer captured activity until the group activates

### Requirement: Effective minimum duration

The SDK SHALL compute the effective minimum duration as the lowest `minDurationMs` among the groups
that are activated for the current session, whether or not those groups sampled the session in.
Pending groups and groups without a `minDurationMs` SHALL NOT contribute. When no activated group
has a `minDurationMs`, no minimum applies. The minimum is a release gate on buffered or held replay
data, exactly as the V1 "Minimum-duration buffering gate" is: it never decides whether the session
records.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:404-422`:
`getMinimumDuration` — "Only consider activated groups", lowest numeric `minDurationMs`, `null`
when none; `lazy-loaded-session-recorder.ts:631-633`: `_minimumDuration` reads it from the
strategy).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9237`
("respects minDurationMs and delays full recording until duration passes" — one group). The
lowest of several groups, and a sampled-out activated group counting: No posthog-js test on
`origin/main` covers this; decision-based (source only, `recording-strategies.ts:404-422` reads
the activation status, not the sampling result).

#### Scenario: The lowest minimum among activated groups applies
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with no conditions, a sample rate of 1.0, and a minimum duration of 5000 milliseconds, and a trigger group "B" with no conditions, a sample rate of 0.0, and a minimum duration of 2000 milliseconds
- **WHEN** the session's captured activity reaches 2000 milliseconds
- **THEN** the buffered replay data should be emitted

#### Scenario: A pending group's minimum does not apply
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with no conditions, a sample rate of 1.0, and no minimum duration, and a trigger group "B" with event condition "$exception" and a minimum duration of 5000 milliseconds
- **WHEN** the SDK would emit replay data before "$exception" is captured
- **THEN** the replay data should be emitted without waiting for 5000 milliseconds

### Requirement: Re-check the minimum on every flush

Each time the SDK would emit replay data, it SHALL re-read the effective minimum duration (see
"Effective minimum duration") rather than reuse a value fixed when the session started. When the
effective minimum drops — because a group with a lower `minDurationMs` activates, or a config
reload lowers or removes the minimum — and the session's captured activity already meets the new
minimum, the SDK SHALL release the held data on that flush. When the effective minimum is reached by
elapsed activity, the SDK SHALL release the held data as the V1 gate does.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:631-633`:
`_minimumDuration` is a getter over the strategy; `:2405`: `_flushBuffer` evaluates
`_isBelowMinimumDuration()` on every flush; `:2499-2530`: the check reads the current minimum and
the session or buffer duration each time).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9237`
("respects minDurationMs and delays full recording until duration passes" — held below, released
once reached). Release after a later group lowers the minimum: No posthog-js test on
`origin/main` covers this; decision-based (contract C7).

#### Scenario: Held data ships when a second group lowers the minimum
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with no conditions, a sample rate of 1.0, and a minimum duration of 10000 milliseconds, and a trigger group "B" with event condition "$exception", a sample rate of 1.0, and a minimum duration of 1000 milliseconds
- **AND** the session has captured 3000 milliseconds of activity and its replay data is held below the minimum
- **WHEN** the client captures an event named "$exception"
- **THEN** the held replay data should be emitted on the next flush

#### Scenario: Held data ships once the minimum is reached
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with no conditions, a sample rate of 1.0, and a minimum duration of 5000 milliseconds
- **WHEN** the session has captured less than 5000 milliseconds of activity
- **THEN** the session's replay data should not be emitted
- **WHEN** the session's captured activity reaches or exceeds 5000 milliseconds
- **THEN** the buffered replay data should be emitted

### Requirement: URL blocklist stays global (URL-capable SDKs)

While trigger groups are selected, the SDK SHALL keep applying the remote `urlBlocklist` from
`session-replay-ingestion-controls`: recording pauses while the current URL matches any blocklist
pattern and resumes when it no longer matches, regardless of which group activated the session.
The blocklist is not part of any group and is the only V1 URL field the SDK reads under trigger
groups.

This requirement applies only to SDKs with a URL / navigation concept. SDKs without URLs are exempt.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:384-385`: "V2 needs URL
blocklist (but not URL triggers)"; `:433-434`: "Check URL blocklist (global, not per-group)";
`triggerMatching.ts:815-817`: `urlBlocked` → `paused` before any group is evaluated).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:8875`
("respects URL blocklist even when trigger group matches").

#### Scenario: The URL blocklist pauses recording under trigger groups
- **GIVEN** a URL-capable SDK with session replay enabled
- **AND** the remote config sets `version` to 2, configures a trigger group with event condition "$pageview" and a sample rate of 1.0, and a URL blocklist matching "/account"
- **AND** the client has captured an event named "$pageview" and session recording is active
- **WHEN** the current URL changes to one matching "/account"
- **THEN** session recording should be paused
- **WHEN** the current URL changes to one that does not match "/account"
- **THEN** session recording should resume

### Requirement: Event-leg activation releases the interaction hold

A matching event leg SHALL count as the "event trigger" that releases the hold and ships the held
data, on SDKs that implement the "Interaction hold for unconfirmed-activity recording epochs" of
`session-replay-ingestion-controls`. An event matches the leg when its name equals one of the
group's event conditions and its group-level and per-event property filters pass. That match SHALL
release the hold even when the group stays pending on another leg, for example an `all` group still
waiting on its URL or flag leg. A URL-leg or flag-leg match SHALL NOT release the hold, because
neither proves a human is present. Releasing the hold does not by itself make the group eligible:
group eligibility, sampling, the effective minimum duration, and the URL blocklist remain separate
emission gates. The release SHALL happen even when the matching event arrives after the SDK stopped
evaluating event legs for performance (see "Stop group evaluation after the first flush").

This requirement applies to SDKs that implement the interaction hold (currently posthog-js).
Other SDKs are exempt.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:1044-1050`:
`_onTriggerActivated` — "V2 event-trigger matches release the interaction hold here ... URL and
linked-flag activations never release"; `if (triggerType === 'event') { this._releaseHoldAndFlush() }`).
The event path reaches it from `recording-strategies.ts:504-506`
(`matcher.activateTrigger(triggerType, sessionId)`, `this.updateActiveTriggers(sessionId)`,
`this._onTriggerActivated(triggerType)`) with no combined-status check, so an event that matches
the leg releases the hold whether or not the group's combined status is activated (`:508-510` at
`eb2f69258`). No posthog-js test on `origin/main` covers a matching event leg on a group that stays
pending on another leg; source only.

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:2262`
("an event trigger match releases the hold and ships under the rotated session id"), `:2292` ("an
event trigger whose property filters do not match retains the hold"), `:2312` ("a URL trigger
activation does not release the hold"), `:2329` ("releases a hold that begins after the
initial-flush unhook optimization").

#### Scenario: An event-leg activation releases the hold
- **GIVEN** posthog-js with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$exception" and a sample rate of 1.0
- **AND** the session id rotated because of an inactivity timeout and the rotated epoch's replay data is held with no confirmed user interaction
- **WHEN** the client captures an event named "$exception"
- **THEN** the held replay data should be released under the rotated session id
- **AND** session recording should be active

#### Scenario: A URL-leg activation does not release the hold
- **GIVEN** posthog-js with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with URL condition matching "/checkout" and a sample rate of 1.0
- **AND** the session id rotated because of an inactivity timeout and the rotated epoch's replay data is held with no confirmed user interaction
- **WHEN** the current URL changes to one matching "/checkout"
- **THEN** the held replay data should remain withheld

#### Scenario: A matching event leg releases the hold while the group stays pending
- **GIVEN** posthog-js with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with match type "all", event condition "$pageview", URL condition matching "/checkout", and a sample rate of 1.0
- **AND** the session id rotated because of an inactivity timeout and the rotated epoch's replay data is held with no confirmed user interaction
- **AND** the current URL does not match "/checkout"
- **WHEN** the client captures an event named "$pageview"
- **THEN** the hold should be released
- **AND** the group should remain pending
- **AND** no replay data should be emitted
- **WHEN** the current URL changes to one matching "/checkout"
- **THEN** session recording should be active

### Requirement: Trigger-group debug properties

An SDK that implements trigger groups SHALL attach the trigger-group keys defined in
`session-replay-debug-properties` while trigger groups are selected:
`$sdk_debug_replay_remote_trigger_matching_config` with the value `v2_trigger_groups`,
`$sdk_debug_replay_trigger_groups_count` with the number of configured groups, and
`$sdk_debug_replay_matched_recording_trigger_groups` with one `{ id, name, matched: true,
sampled }` entry per activated group, where `sampled` is that group's sampling decision; groups
that are not activated SHALL NOT appear. The SDK SHALL refresh the matched-groups value when a
group activates and when sampling decisions are made. For each pending group,
`$sdk_debug_replay_pending_trigger_conditions` SHALL carry one entry per unsatisfied leg in the
form `trigger group "<name>": <condition>`, where `<condition>` is the leg's own description, as
posthog-js writes it; a bare `trigger_groups` value does not satisfy this requirement. The
attach, tiering, and throttling rules for these keys stay in `session-replay-debug-properties`.

This requirement applies to all SDKs that implement trigger groups.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:379-382`: registers
`v2_trigger_groups` and the group count for the session; `:614-637`: `updateActiveTriggers`
builds `{ id, name, matched: true, sampled }` for activated groups; `:649-658`:
`getPendingTriggerConditions` maps each pending condition to `trigger group "${name}":
${condition}`). posthog-ios `feat/replay-v2-trigger-groups` `23ffc5a905`
`PostHog/Replay/PostHogReplayIntegration.swift:2120-2122` appends a single `trigger_groups`
value today and changes to the posthog-js form.

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:8829`
("registers session properties when trigger group matches and is sampled"), `:9137` ("respects
sampleRate < 1.0 and samples out when triggered" — `sampled: false`), `:9183` ("matchType all
requires ALL conditions to match before triggering"), `:8763` ("describes pending conditions
within trigger groups" — the pending text).

#### Scenario: A matched and sampled group is reported
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with id "g1", name "Errors", event condition "$exception", and a sample rate of 1.0
- **WHEN** the client captures an event named "$exception"
- **AND** the wall clock advances by at least 30 seconds after the SDK accepts it, so the debug throttle window of `session-replay-debug-properties` has passed
- **AND** the client captures another eligible SDK event
- **THEN** the later event's properties include `$sdk_debug_replay_remote_trigger_matching_config` set to "v2_trigger_groups"
- **AND** `$sdk_debug_replay_trigger_groups_count` set to 1
- **AND** `$sdk_debug_replay_matched_recording_trigger_groups` containing one entry with id "g1", name "Errors", matched true, and sampled true

#### Scenario: A pending group is described in the posthog-js form
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group named "Errors" with event condition "$exception" and a sample rate of 1.0
- **WHEN** the client captures an eligible SDK event before "$exception" is captured
- **THEN** the event's `$sdk_debug_replay_pending_trigger_conditions` includes an entry that starts with `trigger group "Errors": `
- **AND** it does not include a bare `trigger_groups` entry

### Requirement: Stop group evaluation after the first flush (MAY)

An SDK SHALL NOT stop evaluating event legs before a session's replay data has been emitted for
the first time; after that, it MAY stop evaluating them for the rest of that session. An SDK that
does so accepts that a pending group's event leg cannot activate the session later in that session
(for example after a reload lowers an active group's rate to 0, or an active group's flag stops
matching) until the session id rotates. An SDK that does this SHALL still honor the interaction
hold release (see "Event-leg activation releases the interaction hold") for a hold that begins
after it stopped evaluating, and SHALL resume evaluation for a new session.

This requirement applies to all replay-capable SDKs as an allowed optimization.

Reference: posthog-js `origin/main` `480395c443`
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:464-471`: "Stop
checking triggers after initial buffer flush"; `:596-598`: `onFlushComplete` sets
`_hasCompletedInitialFlush`). At `480395c443` `:465-470` removes
`_removeEventTriggerCaptureHook` once `_hasCompletedInitialFlush` is set (`:469-474` at
`eb2f69258`); nothing resets the flag, and the strategy is rebuilt only in `start()`
(`lazy-loaded-session-recorder.ts:1251`; `:1253` at `eb2f69258`).

Covering test: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:9532`
("stops checking triggers after initial buffer flush (performance optimization)"), `:2329`
("releases a hold that begins after the initial-flush unhook optimization").

#### Scenario: Event legs may stop being evaluated after the first emission
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with event condition "trigger_event" and a trigger group "B" with event condition "another_event", both with a sample rate of 1.0
- **AND** the client has captured "trigger_event" and the session's replay data has been emitted
- **WHEN** the client captures an event named "another_event"
- **THEN** session recording should remain active
- **AND** the SDK may leave group "B" unevaluated for the rest of the session

#### Scenario: A stopped evaluation does not activate a pending group later
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group "A" with boolean flag condition "replay-flag" and a trigger group "B" with event condition "error", both with a sample rate of 1.0
- **AND** feature flag "replay-flag" is enabled and the session's replay data has been emitted
- **WHEN** feature flags reload and "replay-flag" is no longer enabled
- **AND** the client captures an event named "error"
- **THEN** session recording may remain inactive

### Requirement: `$snapshot` is not a trigger

A mobile SDK SHALL NOT let a `$snapshot` event satisfy any group's event leg or screen leg, even
when a group lists `$snapshot` by name. `$snapshot` events are the replay payload itself; letting
them activate a group would make recording self-sustaining. posthog-js does not skip `$snapshot`
— its event hook fires for every capture and matches by name only — but the PostHog UI cannot
select `$snapshot` as a trigger event, so the divergence has no observable effect on a configured
project.

This requirement applies to mobile SDKs (`posthog-ios`, `posthog-android`) and hybrid SDKs over
them. posthog-js is exempt.

Reference: posthog-js `origin/main` `480395c443` has no skip:
`packages/browser/src/posthog-core.ts:2106` emits `eventCaptured` for every captured event and
`packages/browser/src/extensions/replay/external/triggerMatching.ts:550` matches by name alone.
posthog-ios `feat/replay-v2-trigger-groups` `23ffc5a905`
`PostHog/Replay/PostHogTriggerGroupsEvaluator.swift:68` returns before evaluation when the event
is `$snapshot`.

Covering test: No posthog-js test on `origin/main` covers this; decision-based (contract C8;
mobile-only, benign divergence from posthog-js).

#### Scenario: A `$snapshot` event does not activate a group on mobile
- **GIVEN** a mobile SDK with session replay enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$snapshot" and a sample rate of 1.0
- **WHEN** the SDK emits a "$snapshot" event
- **THEN** session recording should not be active

### Requirement: Explicit stop and start

After the application calls `stopSessionRecording()`, the SDK SHALL NOT restart recording
automatically — not on a remote-config reload, not when a group's event, URL, screen, or flag leg
matches, and not when the session id rotates — until the application calls
`startSessionRecording()`. `startSessionRecording()` SHALL clear the explicit stop even when a gate
(enablement, a group that is still pending, a sampled-out session) then refuses to record; the next
time the gates allow recording, it starts without another explicit call. The explicit stop is an
application-level override above every control in this capability and in
`session-replay-ingestion-controls`; it is not V2-specific, and SDKs SHALL apply it the same way
under the V1 fields. On a mobile client SDK, a `stopSessionRecording()` or
`startSessionRecording()` call made while the SDK is opted out SHALL NOT set or clear the explicit
stop: it follows `opt-in` ("Opt-in restarts the session replay the app wanted at opt-out"). The
browser SDK is unchanged, because `opt-in` already keeps a browser stop in effect through opt-out
and opt-in, also when the application calls it while opted out.

This requirement applies to all replay-capable SDKs.

Reference: posthog-js `origin/main` `480395c443` (`packages/browser/src/posthog-core.ts:4526-4528`:
`stopSessionRecording` sets `disable_session_recording: true`; `:4509`: `startSessionRecording`
sets it back to `false` after applying any overrides;
`packages/browser/src/extensions/replay/session-recording.ts:139-142`: `_isRecordingEnabled` reads
`disable_session_recording` on every evaluation, so a reload, a trigger, or a rotation cannot
restart a stopped recorder). Opt-out exception: `openspec/specs/opt-in/spec.md` ("Opt-in restarts
the session replay the app wanted at opt-out", scenario "Stopping a recording while opted out does
not block the restart").

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core.set_config.test.ts:433-439`
("should update disable_session_recording config") asserts only the flag. Surviving a reload, a
trigger match, and a rotation: No posthog-js test on `origin/main` covers this; decision-based
(contract C6; the posthog-js test asserts only the config flag).

#### Scenario: A trigger match does not restart a stopped recording
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$exception" and a sample rate of 1.0
- **AND** the application has called `stopSessionRecording()`
- **WHEN** the client captures an event named "$exception"
- **THEN** session recording should not be active
- **WHEN** the remote config is reloaded and the session id rotates
- **THEN** session recording should still not be active

#### Scenario: An explicit start clears the stop even when a gate refuses
- **GIVEN** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$exception" and a sample rate of 1.0
- **AND** the application has called `stopSessionRecording()`
- **WHEN** the application calls `startSessionRecording()` before "$exception" is captured
- **THEN** session recording should not be active because the group is pending
- **WHEN** the client captures an event named "$exception"
- **THEN** session recording should be active

### Requirement: Hybrid SDKs

The layer that owns the analytics capture pipeline SHALL evaluate trigger groups in a hybrid SDK
composed of a managed layer (JavaScript, Dart) over an embedded native replay SDK, because it is
the layer that observes the captured events and their properties. The embedded native SDK SHALL apply
none of the V1 gating fields for that host (see "Ignore the V1 gating fields under trigger
groups"), SHALL keep the replay enablement gate and the URL blocklist, SHALL apply the minimum
duration and the local sample rate the managed layer hands it, and SHALL NOT evaluate the groups a
second time. The managed layer SHALL hand the effective minimum duration (see "Effective
minimum duration") to the native layer, which applies it as its minimum-duration release gate, so
the one logical decision of the hybrid requirement in `session-replay-ingestion-controls` covers
the group union and the effective minimum. While trigger groups are selected, the managed layer SHALL hand the native layer only the app's local sample rate, never the remote V1 `sampleRate`,
and the native layer SHALL apply that local rate as the cap of "Local sample rate under trigger
groups", after the group decision. With no local rate, the native layer SHALL apply no sample rate.
Where the managed layer already routes capture through
the native SDK's own pipeline (for example `posthog-flutter`), the native SDK owns the capture
pipeline and evaluates the groups itself, and no hand-off is needed.

This requirement applies only to hybrid SDKs that span a managed layer and an embedded native
replay SDK. Single-layer SDKs are unaffected.

Reference: no merged reference on posthog-js `origin/main`; this requirement comes from the
cross-SDK contract decisions C2 (under React Native, native applies none of the V1 gating fields) and C3 (the
managed layer hands the effective group minimum to native, which already holds and releases). The
web arithmetic the managed layer reproduces is `recording-strategies.ts:404-422` and
`lazy-loaded-session-recorder.ts:2499-2530` at `480395c443`. The sample-rate hand-off records
cross-SDK decision 4 of 2026-11-14 (React Native under V2 sends only the local rate to native) and decision D1 (the local rate
caps the group decision). The unmerged React Native branch `feat/rn-replay-v2-trigger-groups`
`058369cbb` agrees: `packages/react-native/src/posthog-rn.ts:3327-3333` drops the remote
`sampleRate` when trigger groups are cached ("Under v2, per-group sampling replaces the remote
rate; forwarding it would gate recording twice"), and `:3347` and `:3393` pass
`localSampleRateValid ?? remoteSampleRateValid` to native as `sdkReplayConfig.sampleRate`.

Covering test: No posthog-js test on `origin/main` covers this; decision-based (contract C2 and
C3, cross-SDK decision 4, decision D1; no merged reference implementation).

#### Scenario: The managed layer owns trigger groups in a hybrid SDK
- **GIVEN** a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
- **AND** session replay is enabled
- **AND** the remote config sets `version` to 2 and configures a trigger group with event condition "$exception", a sample rate of 1.0, and a minimum duration of 2000 milliseconds
- **AND** session recording is not active because no group has activated
- **WHEN** the client captures an event named "$exception" on the managed layer
- **THEN** the managed layer should evaluate the group and start native recording
- **AND** the native layer should apply a minimum duration of 2000 milliseconds
- **AND** the native layer should not evaluate the trigger groups itself

#### Scenario: The managed layer hands native only the local sample rate
- **GIVEN** a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
- **AND** session replay is enabled with a local replay sample rate of 0.0
- **AND** the remote config sets `version` to 2, a V1 `sampleRate` of 1.0, and one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** the managed layer should hand the native layer a sample rate of 0.0
- **AND** session recording should not be active

#### Scenario: The managed layer never hands native the remote V1 sample rate
- **GIVEN** a hybrid SDK whose managed layer captures analytics and whose native layer owns replay
- **AND** session replay is enabled with no local replay sample rate
- **AND** the remote config sets `version` to 2, a V1 `sampleRate` of 0.0, and one trigger group with a sample rate of 1.0 and no conditions
- **WHEN** the SDK resolves whether to record the current session
- **THEN** the managed layer should hand the native layer no sample rate
- **AND** session recording should be active
