## Context

The existing start and stop specs use `void | Promise<void>` as the canonical return contract, including `Promise<void>` for React Native. [posthog-js#4884](https://github.com/PostHog/posthog-js/pull/4884) adds results because native bridges can resolve a start call even when the recorder refuses it while loading remote config.

## Goals / Non-Goals

**Goals:** Define React Native's boolean results and retry/cancellation behavior without overstating what a completed bridge call proves.

**Non-Goals:** Change Flutter, iOS, Android, browser, or Unity APIs. Add a native readiness event. Guarantee eventual recorder activation or server-side replay delivery.

## Decisions

1. Keep the canonical void return and name React Native as an explicit variant. Making boolean results canonical would require separate designs for each SDK's readiness and concurrency model. Flutter can propose the same variant separately.
2. Treat a start result as the result of one request, not a live recording-state subscription. Native refusal returns false without waiting for retries. A newer unfinished request wins. If native state confirmation rejects after a completed start, the current implementation warns and returns true. Preserve that exception rather than claiming guaranteed activation.
3. Treat a stop result as completion of the native stop call, not a transition from active to inactive. A successful call returns true even if recording was already off.
4. Describe the bounded timer retries already implemented in the PR. JS flags can arrive before native config, and native config readiness has no bridge notification. Retrying only on JS flags events leaves the recorder inactive until another event arrives. Unbounded timers would retain work indefinitely.

## Risks / Trade-offs

- A boolean cannot represent confirmed activation, unavailable confirmation, and cancellation separately. Document the distinctions and keep `isSessionReplayActive()` as the current-state query.
- Native config may arrive after the five timer retries. Preserve flags-driven and explicit retries without promising eventual recovery.
- Retrying a cancelled request could record an excluded flow. Retain serialized operations and queued/in-flight cancellation tests from the implementation PR.
- Existing statements in the public-signature sections will remain stale until archival. Update those sections as part of the approved apply/archive step, not by publishing this proposal as shipped truth.

## Migration Plan

Review this proposal alongside posthog-js#4884. After approval, apply and archive on this PR, reconcile the React Native public-signature prose, and run strict spec validation. Ship the SDK as a minor release. Keep the website follow-up in draft until the release version is known.

Before release, this proposal can be withdrawn without changing any canonical spec or other SDK. Do not remove a shipped return value as a patch rollback.

## Open Questions

Maintainers still need to approve the explicit variant. The exact React Native release version is not known yet. Flutter adoption is a separate proposal.
