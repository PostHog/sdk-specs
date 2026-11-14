## Context

`openspec/specs/capture/spec.md:391` ("Caller-supplied event properties take precedence") lets a
registered (super) property overwrite a value the SDK sets itself, and `:401` says a caller
`$process_person_profile` changes that event only. Nothing in `main` says what happens when the
overwritten value is person processing on an identity event, where PostHog's ingestion treats the
event as invalid: `$identify`, `$create_alias`, `$merge_dangerously` and `$groupidentify` are
dropped with the ingestion warning `invalid_event_when_process_person_profile_is_false`, and a
`$set` or `$set_once` is kept without its person update.

Sources read on 2026-11-14, all merged PR descriptions and their linked discussion:

| SDK | PR | Merged | Behavior after the PR |
|---|---|---|---|
| posthog-ios | #1067 | 2026-11-13 | Drops a registered `$process_person_profile` property and a `process_person_profile` option registered with `registerOptionsForWrapper` from the six identity events. Call value and `beforeSend` still apply. `personProfiles = never` still skips the calls. |
| posthog-android | #979 | 2026-11-13 | Same rule, same event list. |
| posthog-flutter | #730 | 2026-11-13 | Same rule in the Dart core, which covers Windows and Linux; iOS, macOS and Android come from the native SDKs. On desktop `beforeSend` does not see `$identify`, `$create_alias` or `$groupidentify`, so only the call value is promised there. |
| posthog-go | #450 | 2026-11-13 | Server form: identify-style events default to `process_person_profile: true` unless the call sets it; a generated distinct id stays personless. |
| posthog-rs | #363 | 2026-11-13 | Same server form. |
| posthog-python | #1247 | open | Same server form. |
| posthog-js (node) | #5712 | open | Same server form. |

Not audited: posthog-js browser, posthog-kmp on targets other than Android and Apple, posthog-unity,
posthog-godot.

## Goals / Non-Goals

**Goals:** One client-side answer to "what does a globally registered personless setting do to an
identity event", matching what the three mobile SDKs shipped.

**Non-Goals:**

- The server-side rule. posthog-go and posthog-rs reach the same outcome by defaulting the call's
  own `process_person_profile` to `true`, and the open PR #146 already specifies that under
  **Distinct ids and identity fallbacks on capture v1**. Writing it twice would invite a conflict.
- The generated-distinct-id exception, which is a server concern: a client SDK always has an
  ambient distinct id.
- Any change to what a *caller* passes on an identity call, which keeps working in both directions.
- Person profiles for a project that turned them off: `never` still skips these calls.

## Decisions

**Drop the registered value rather than send `true`.** All three mobile SDKs strip it. Capture
treats an absent `process_person_profile` and `true` the same way, so stripping keeps every other
identity payload byte-identical and avoids a new wire field on every identity event.

**State it as an exception to the precedence requirement rather than editing that requirement.**
The precedence rule holds for every other key and every other event, including a registered
personless `false` on an ordinary event. Naming the exception in a separate requirement keeps the
general rule readable, and keeps this delta off the lines PR #146 and PR #217 are editing.

**Scope the requirement to client SDKs.** The two merged server SDKs implement a different
mechanism (a call-layer default plus a generated-id exception) for the same outcome, and that
mechanism is already drafted elsewhere.

## Open questions

- PR #146's **Distinct ids and identity fallbacks on capture v1** currently ends with "On a client
  SDK, global and registered layers still reach these events like any other event". That sentence
  predates the three mobile PRs and contradicts this requirement. Whoever merges the two should
  drop or reword it. Flagged for human review rather than edited here, because #146 is open.
- Whether posthog-js browser should adopt the same rule. The capture v1 browser work is in flight,
  and the mobile PRs name the server SDKs, Flutter and KMP as the followers, not the browser.
