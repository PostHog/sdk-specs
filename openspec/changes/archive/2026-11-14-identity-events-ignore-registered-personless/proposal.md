## Why

No spec says what a globally registered personless setting does to an identity event on a client
SDK. In the mobile majors it reached them, and PostHog's ingestion drops an identity event whose
person processing is off, so an app that registered `process_person_profile: false` once would
silently stop identifying its users after upgrading.

Five SDKs fixed this the same way, with the same event list, in the last two days:

- PostHog/posthog-ios#1067 and PostHog/posthog-android#979 (4.0)
- PostHog/posthog-flutter#730 (6.0, the Windows and Linux Dart core)
- PostHog/posthog-go#450 and PostHog/posthog-rs#363 (the server side of the same rule)

PostHog/posthog-python#1247 and PostHog/posthog-js#5712 carry the server rule for python and node
and are still open.

The server half of the rule is already written in the open PR #146 (**Distinct ids and identity
fallbacks on capture v1**), whose current text says the opposite for client SDKs: "global and
registered layers still reach these events like any other event". This change records the client
half against the specs as they stand on `main`.

## What Changes

- **Capture**: a new requirement, "Identity events ignore a registered personless setting". A
  client SDK drops a registered `$process_person_profile` property, and a registered
  `process_person_profile` event option, from `$identify`, `$create_alias`, `$merge_dangerously`,
  `$groupidentify`, `$set` and `$set_once`. It drops the registered value rather than sending an
  explicit `true`.
- A value passed on the call still applies in both directions, `before_send` still has the final
  say where it runs for that event, and a person-profiles mode of `never` still skips these calls.
- Every other event keeps the registered value, including a registered `false`.
- Four scenarios.
- This is a narrow exception to **Caller-supplied event properties take precedence**, which the new
  requirement names.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: record that a registered personless setting does not reach an identity event.

## Impact

Specifications only. No SDK changes in this PR. Conformant as merged: posthog-ios (4.0),
posthog-android (4.0), posthog-flutter (6.0). posthog-kmp inherits the native behavior on Android
and Apple and needs checking on its other targets. posthog-js browser was not audited for this
change and is listed as a follow-up. Server SDKs reach the same outcome from the call layer and are
out of this change's scope.
