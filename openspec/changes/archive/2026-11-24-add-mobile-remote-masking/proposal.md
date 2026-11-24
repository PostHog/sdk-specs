## Why

Project owners want one place to force masking for mobile session replay. Today a mobile SDK reads
`maskAllTextInputs`, `maskAllTexts` and `maskAllImages` from local code only, so a project owner who
needs stricter masking has to ship an app release. Browser replay already takes masking from the
project settings through remote config. The spec records that split: requirement 5 says mobile
applies masking "from the local replay capture path", and the remote-config lifecycle line says the
remote-config update is browser only.

## What Changes

- **New requirement: Mobile SDKs read dedicated mobile masking keys.** Mobile reads
  `sessionRecording.masking.mobile.maskAllText` and `sessionRecording.masking.mobile.maskAllImages`.
  The web keys in the same `masking` object (`maskAllInputs`, `maskTextSelector`, `blockSelector`,
  `maskAllElementAttributes`) are ignored on mobile. `maskAllText` maps to the local text flag
  (`maskAllTextInputs`, or `maskAllTexts` in posthog-flutter). `maskAllImages` maps to
  `maskAllImages`. Other mobile mask flags stay local.
- **New requirement: The stricter side wins, per flag.** `resolved = local OR (server == true)`.
  A missing key, `false`, `null`, a non-boolean value, or a missing `masking` or `mobile` object keeps
  the local value. The server never unmasks. This diverges from the browser (`client ?? server`) by
  decision.
- **New requirement: Resolved masking follows the cached and live remote config.** The SDK applies
  the cached config at install and every later remote config update. Capture reads the resolved value
  per frame. Frames buffered before the first live config are dropped when a flag goes from unmasked
  to masked.
- **New requirement: Log once when the server turns on a mask the local value had off.** A debug log
  replaces the browser's warning.
- **New requirement: Wrapper SDKs get the resolved flags from native.** React Native and KMP keep
  passing their flags to native. posthog-flutter reads the resolved flags from the native replay
  state. posthog-ios and posthog-android expose the resolved values to wrappers.
- **New requirement: Always-mask rules are unchanged.** Passwords, `ph-no-capture` and explicit mask
  markers stay masked whatever the resolved flags say.
- **New requirement: Browser masking precedence is unchanged.** Records the browser behavior as the
  baseline the mobile requirements diverge from.
- **Hand edit at archive** (the delta cannot reach these): Behavior item 5 and the "Remote-config
  update" lifecycle line in `specs/session-replay-privacy/spec.md`, and the "State read" bullet
  about remote replay config. See `tasks.md` 2.2.

Reviewed and not modified: requirements 1 to 4 and 6 to 11 of Behavior, and every existing
`### Requirement:`. Behavior item 1 says mobile masks "unless the local replay configuration
disables those categories". It stays true for the local value but no longer states the whole rule.
The new requirement takes precedence, and task 2.2 adds a pointer.

Out of scope: the PostHog project settings UI and server payload (two mobile toggles that write the
mobile keys, off by default), SDK docs, and any change to a public masking flag.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: seven added requirements. Two hand edits to Behavior item 5 and the
  lifecycle section at archive.

## Impact

- **posthog-ios, posthog-android.** Read `masking.mobile` from the cached and live remote config,
  resolve per flag, drop buffered frames when stricter, log once, and expose the resolved flags to
  wrappers. No public masking flag changes.
- **posthog-js react-native.** The JS layer and both plugins keep passing the flags as today. The
  native SDKs resolve. A native version floor applies.
- **posthog-flutter.** `getSessionReplayState` also returns the resolved flags so Dart-rendered
  content follows them.
- **posthog-kmp.** Passes flags to native as today. Picks the behavior up through the native
  version pin.
- **posthog-js browser.** No change.
- **Behavior on upgrade.** No project has the keys until a project owner turns a toggle on, so no app
  changes behavior on SDK upgrade.
- **Risk: rebase conflicts.** Open sdk-specs PRs #237, #195 and #182 also edit
  `openspec/specs/session-replay-privacy/spec.md`. This change may need a rebase against them. They
  do not change what this change specifies.
