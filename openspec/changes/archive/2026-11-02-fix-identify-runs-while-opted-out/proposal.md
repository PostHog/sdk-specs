## Why

`identify` lists "the user is opted out" as a guard that short-circuits the whole call (Behavior, client-side flow, step 1), and `opt-in` says opt-out short-circuits `identify`. posthog-js and posthog-android don't do this. Their `identify` keeps running while opted out: it updates local identity and reloads feature flags, and only the event it captures is dropped.

- posthog-js `identify()` (`packages/browser/src/posthog-core.ts:3327`) returns early only for an uninitialized SDK, an invalid distinct id, and `_requirePersonProcessing`. It has no consent check. The only opt-out gate is in `capture()` (`posthog-core.ts:1795`), which drops the event when `!this.is_capturing()`. `identify` caches the person-properties hash only when `capture()` accepted the `$identify` / `$set` event (`posthog-core.ts:3411-3424`), and reloads feature flags when the distinct id changes (`posthog-core.ts:3456-3461`).
- posthog-js decided that flag loading does not depend on opt-out: "Feature flag loading is no longer gated by capture opt-out" (PostHog/posthog-js#3596, [comment](https://github.com/PostHog/posthog-js/issues/3596#issuecomment-4797090791)).
- posthog-android `identify()` (`posthog/src/main/java/com/posthog/PostHog.kt:1592`) guards only on `isEnabled()` (setup called), person processing, and a blank distinct id (`PostHog.kt:1597-1609`). The opt-out check is in `capture()` (`PostHog.kt:972`). On a new distinct id it persists the identity and reloads flags (`PostHog.kt:1670`).

`bootstrap` already states the same rule for identified-bootstrap reconciliation: "opt-out suppresses event emission, not the local identity state".

posthog-js references are at `origin/main` 8c8327543. posthog-android references are at `origin/main` 8309f837.

## What Changes

- **Requirement** (`Canonical identify behavior`): client SDKs must not short-circuit `identify` on opt-out. While opted out, `identify` updates local identity state and person properties for flags, and reloads flags when the distinct id changes. It does not capture `$identify` or `$set`, and does not update the person-properties dedup hash for an event it did not capture. New `@client` scenario: identify while opted out changes the distinct id, sends a flags request for the new distinct id, and enqueues no event.
- **Behavior prose** (`identify`, client-side flow step 1 and step 3, Error handling): opt-out is removed from the guards and the drop list, and the opted-out behavior is described. Applied at archive, outside the requirement delta.
- **Behavior prose** (`opt-in`, `optOut` step 3 and Interactions): opt-out blocks event capture. `identify` still updates local identity and reloads flags. What these sections say about `capture`, `group`, and `alias` is unchanged. Applied at archive, outside the requirement delta.
- **Acceptance** (`acceptance/public/identify.feature`): the new `@client` scenario, using existing step text.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `identify`: the `Canonical identify behavior` requirement gains one normative sentence and one `@client` scenario. The existing scenarios are unchanged.
- `opt-in`: prose only (no requirement change).

## Impact

- **posthog-js**: conforms. Reference test: `packages/browser/src/__tests__/browser-next-differential/scenarios.ts:126` (`defaultOptOutScenario`, run by `browser-next-differential.test.ts:42`) checks that `identify` while opted out sets the distinct id and identified state and delivers no event. That harness disables feature flags (`legacy-browser-adapter.ts:54`), and no posthog-js test calls `identify()` after opt-out and asserts the flags request. The flags-reload part of this change has no covering reference test.
- **posthog-android**: conforms for identity and flags reload. In the same-id anonymous-to-identified transition, it updates the dedup hash after `capture()` whether or not the event was captured (`PostHog.kt:1693`), which differs from the dedup-hash rule here.
- **posthog-ios**: a matching change is in progress on branch `fix/identify-flags-while-opted-out`.
- Other client SDKs were not checked in this change.
- **Server SDKs**: not applicable (no opt-out state).
