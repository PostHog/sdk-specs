## Why

Two SDKs let an app drop `$exception` events by exception type, and `capture-exception` says
nothing about it. The spec only notes, in prose, that "some SDKs may drop the event before capture
when local suppression/error-tracking rules say it should not be sent."

- **posthog-ios** `PostHogErrorTrackingConfig.ignoredExceptionTypes`
- **posthog-android** `PostHogErrorTrackingConfig.ignoredExceptionTypes`

posthog-kmp exposes the same option and forwards it to these two native implementations.

Until posthog-ios [#894](https://github.com/PostHog/posthog-ios/pull/894) the two disagreed on the
one part of this that is observable without configuring anything: posthog-ios defaulted to
`["RCTFatalException"]` while posthog-android defaulted to empty. posthog-ios now defaults to `[]`,
so the defaults agree and the shared contract is worth stating.

Read from the shipped sources:

| | posthog-ios | posthog-android |
|---|---|---|
| Default | `[]` (was `["RCTFatalException"]`) | `mutableListOf()` |
| Manual `captureException` | dropped (`captureInternal` chokepoint) | dropped (`isIgnoredThrowable`) |
| Autocapture / crash reports | dropped | dropped (same chokepoint) |
| Generic `capture("$exception", …)` | dropped | dropped (`hasIgnoredTypeInExceptionList`) |
| Chain | every `$exception_list` entry | bounded cause-chain walk |
| Matched on | `$exception_list[*].type`, exact, case-sensitive | `Class.isInstance` when the throwable is in hand; `module` + `type` by name when only the payload is |

## What Changes

- Add one requirement to `capture-exception`, **Ignored exception types**, stating: the option is
  optional; where it exists it defaults to empty; a non-empty list drops the matching `$exception`
  event on every path before it enters the capture pipeline; matching walks the whole exception
  chain and is case-sensitive; and the identifier matched on is platform-idiomatic (live error type
  including subtypes where the SDK has the error object, serialized `type` otherwise).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture-exception`: adds the **Ignored exception types** requirement.

## Impact

Not a breaking change: it records what posthog-ios and posthog-android already do after
posthog-ios #894, and SDKs without the option stay conformant because the requirement is
conditioned on exposing it. The SDKs that expose it still have the gaps listed below to close; none
of them is a reason to change the requirement.

- **posthog-ios** conforms as of #894 on iOS, macOS and tvOS. On watchOS and visionOS the matcher is
  compiled out with the crash reporter, so a non-empty list drops nothing on the manual and generic
  capture paths; that is an SDK gap to fix, not a reason for the spec to carve those platforms out.
- **posthog-android** already conforms. Its server flavor gates `captureException` but not
  `$exception` events handed to the generic `capture`, the same kind of SDK gap as the watchOS one above.
- **posthog-kmp** exposes `ErrorTrackingConfig(ignoredExceptionTypes)`, empty by default, and appends
  it to the native list instead of matching itself. On Android that list starts empty. On Apple it
  starts with whatever the pinned posthog-ios defaults to, and KMP pins posthog-ios exactly to a
  release before #894, so a default KMP Apple setup still drops `RCTFatalException` until that pin
  moves.
- **posthog-js, posthog-flutter, posthog-react-native** expose no such option. The React Native
  plugin consumes it on Android, adding `JavascriptException` to posthog-android's list, and
  deduplicates with `beforeSend` on iOS. Unaffected.
