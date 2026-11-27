## Why

`before-send-hook` states under **Concurrency & ordering guarantees** that hooks "run synchronously with event preparation for a single event" and that "the hook chain is isolated to that event; it does not batch or reorder events". That is true of every audited SDK except posthog-flutter, whose Dart-layer `beforeSend` may return a `Future`. The spec never said what an SDK owes callers when its hook can complete asynchronously, so the gap was invisible until it produced wrong data.

In posthog-flutter 5.x, `capture()`, `screen()` and `captureException()` awaited the hook before handing the call to posthog-js or the native SDK. A `reset()`, `identify()`, `register()`, `group()`, `optIn()` or `optOut()` made right after an un-awaited capture therefore reached the SDK first, and the event went out under the *next* user's identity, registered properties, groups and consent. PostHog/posthog-flutter#672 fixed this by handing calls to the underlying SDK in the order the app made them, and its own follow-up notes that the spec is the thing out of date.

## What Changes

- Add a `before-send-hook` requirement covering SDKs whose hook may complete asynchronously: calls are handed to the underlying SDK in the order the app made them, a call made from inside a running hook does not wait on it, and a hook that exceeds a bounded wait stops holding later calls back without its event being dropped.
- Record that a synchronous hook chain satisfies the requirement with no queueing, and record posthog-flutter's platform coverage (web, iOS, Android, macOS; not the Dart-only Windows and Linux path) as the current divergence.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `before-send-hook`: specify ordering when a hook can complete asynchronously, and narrow the synchronous-execution prose to the SDKs it describes.

## Impact

- **posthog-flutter**: conforms on web, iOS, Android and macOS in 5.x (PostHog/posthog-flutter#672). Windows and Linux do not order calls; PostHog/posthog-flutter#686 proposes making `beforeSend` synchronous in 6, which removes the ordering problem on every platform.
- **posthog-js, posthog-ios, posthog-android, posthog-react-native, posthog-kmp, server SDKs**: synchronous hooks, already conformant, no work.
- No wire format or public API changes.
