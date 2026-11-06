## Why

No spec says what `$locale` means. It is one of the oldest client auto-properties and the
`capture` spec names it nowhere — the only mention of a language anywhere in `openspec/specs/`
is the unrelated "the language's no-payload value" phrasing in the flag specs. So each client
SDK invented its own meaning, and the meanings disagreed:

- posthog-ios 3.x sent `Locale.current.languageCode` — a bare language subtag, `de` for a
  `de-CH` device.
- posthog-android 3.x sent `Locale.getDefault()`, which is the *app's* locale: a per-app
  language, a secondary device language, or whatever the app last passed to
  `Locale.setDefault()`. It also dropped the script (`zh-TW` for `zh-Hant-TW`) and sent the
  legacy codes `iw`, `in` and `ji`.
- posthog-react-native sends the platform's full `languageTag`.
- posthog_flutter's pure-Dart desktop client sends the language code only.
- posthog-kmp's JVM context sends `"${language}-${country}"` off `Locale.getDefault()`.

So `$locale = de` matched an iOS user and missed the Android one, and nothing reported the
language the app actually displays — the thing most people are reaching for when they break
down by `$locale`.

posthog-ios 4.0 ([posthog-ios#1009](https://github.com/PostHog/posthog-ios/pull/1009)) and
posthog-android 4.0 ([posthog-android#927](https://github.com/PostHog/posthog-android/pull/927),
closing [posthog-android#822](https://github.com/PostHog/posthog-android/issues/822)) settle it
together, as one cross-SDK change: `$locale` becomes the device's first preferred language as a
full language tag, a new `$app_language` carries the displayed language, and a new public
`setAppLanguage()` lets an app that translates some other way supply it. Both are breaking
changes to a property's meaning, which is exactly the kind of contract this repo exists to hold.

## What Changes

- `capture`: add one requirement defining `$locale` and `$app_language` for client SDKs that
  report a language — what each one means, the language-tag form, when each is omitted, the
  public override method, and the per-app-language divergence between iOS and Android that 4.0
  leaves open.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: `$locale` is the device language as a full language tag; `$app_language` is the
  displayed language; a public setter overrides the latter in memory.

## Impact

- posthog-ios 4.0 and posthog-android 4.0 meet the requirement; it is written from them.
- posthog-react-native already sends a full `languageTag` for `$locale` and has no
  `$app_language` or setter.
- posthog_flutter's desktop (Windows/Linux) client sends a bare language code for `$locale`.
- posthog-kmp's JVM context reads `Locale.getDefault()`, the app-influenced source the
  requirement rules out, and composes a tag by hand.

Those three have to change to meet it. The requirement does not oblige an SDK that reports no
language today (posthog-js browser) to start.
