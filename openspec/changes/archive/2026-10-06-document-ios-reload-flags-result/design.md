## Context

The canonical reload signature passes `error?: Error`, but no SDK passes an error to the reload caller in practice: posthog-js core's `cb(err)` is not filled for network or HTTP failures, React Native resolves `undefined`, and Android and Flutter callbacks take no arguments. The browser's `onFeatureFlags` `errorsLoading` boolean is the only failure signal SDKs actually expose.

## Goals / Non-Goals

**Goals:** Record the iOS 4.0 signature and define what a completion-reported failure must mean, so SDKs that add one stay consistent.

**Non-goals:** Requiring every SDK to report failure, changing the canonical signature, or defining how quota-limited or partial (`errorsWhileComputingFlags`) responses are classified.

## Decisions

- Make failure reporting optional (MAY), with accuracy required when present (MUST). This matches the existing "depending on SDK" wording and binds no SDK that doesn't expose it.
- On failure the completion carries the last known flags, matching the existing scenario that a failed reload keeps cached flags and the browser's `onFeatureFlags` behavior.
- Leave quota-limited and partial responses unspecified; iOS and posthog-js both treat them as non-failures today because they return HTTP 200.

## Risks / Trade-offs

- The canonical `error?: Error` and the iOS `errorsLoading` shape differ → document the iOS variant explicitly; reconciling the canonical signature is a separate cross-SDK decision.
