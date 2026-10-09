## Why

Three SDKs independently moved build-invariant context properties off every event and onto
`Application Installed` / `Application Updated` in the same week, under the same rationale: the
value can only change when the app binary is rebuilt, which is exactly when those events fire, so
repeating it on every event buys nothing and costs storage on every ingested event.

| SDK | Property | Before | After |
|---|---|---|---|
| posthog-ios (#923) | `$app_build_xcode`, `$app_build_sdk` | new | Installed / Updated only |
| posthog-flutter (#640, #651) | `$flutter_version` | every event (5.52.0) | Installed / Updated only; not sent on web |
| posthog-react-native (posthog-js #5206, #5254) | `$react_native_version` | every event | Installed / Updated only |

The `application-lifecycle` spec says what the current app version and build look like on lifecycle
events, but says nothing about where this other class of property belongs. Nothing stops the next
SDK adding a wrapper-runtime or toolchain property to its common event context, which is what the
three SDKs above just undid. The convergence is worth freezing before it drifts apart again.

## What Changes

- A new requirement in `application-lifecycle`: a property whose value can only change when the app
  binary is rebuilt SHALL ride `Application Installed` and `Application Updated` and SHALL NOT be
  added to the SDK's common event context.
- Each such property is omitted when the platform reports no value.
- `$lib`, `$lib_version`, `$app_version` and `$app_build` are carved out explicitly. They stay on
  every event; ingestion, person properties and existing insights depend on them.
- Where there are no lifecycle events — a web runtime, or `captureApplicationLifecycleEvents`
  disabled — the property is simply not sent, rather than falling back to every event.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `application-lifecycle`: adds the **Build-invariant context properties** requirement, and a note in
  the install/update step of the Behavior section.

## Impact

- **posthog-ios**, **posthog-flutter**, **posthog-react-native**: already conform.
- **posthog-android**, **posthog-unity**, **posthog-kmp**: conform today, because they send no
  wrapper-runtime or toolchain property at all. The requirement constrains what they may add later.
- Event consumers: breaking down arbitrary events by `$flutter_version` or `$react_native_version`
  no longer works; those breakdowns move to the install/update events. That break already shipped in
  the SDKs; this records the rule behind it.
- No API or service change.
