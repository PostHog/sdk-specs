## Why

Client SDKs skip a `$set` whose `distinct_id`, `$set` and `$set_once` match the previous update, using a cached person-properties hash. An update PostHog doesn't apply to the person still recorded that hash, so the next valid update with the same properties was dropped as a duplicate:

1. `setPersonProperties({plan: "pro"})` sent with `process_person_profile: false` (as an option, a registered option, or the legacy `$process_person_profile` property). PostHog doesn't update the person, but the SDK records the hash.
2. The same call without the setting. The SDK matches the hash and drops it, so the person never gets `plan: "pro"`.

[posthog-ios#1050](https://github.com/PostHog/posthog-ios/pull/1050) fixed this on iOS and [posthog-android#965](https://github.com/PostHog/posthog-android/pull/965) on Android. No spec states the rule, and the two first landed with different answers for a definite `false`: iOS cleared the stored hash, Android kept it. Both now use the iOS rule.

The rule only reads whether the setting is missing or a Boolean `true`. Deciding that a value is surely personless would need the SDK to mirror how PostHog parses false spellings (`"false"`, `"off"`, `0`, …). That table lives on the server and can change, and an SDK that disagrees with it would keep a hash for an update PostHog applied, then drop the next valid one. Treating every other value as "may be personless" can't drift. The cost is at most one redundant `$set` after a personless update.

## What Changes

- Add a `set-person-properties` requirement, **The person-properties hash only tracks updates that surely process the person**: the SDK reads the person-processing setting as it is sent (a non-null `process_person_profile` option, else the legacy `$process_person_profile` property). Only a missing setting or a Boolean `true` checks and records the hash. Any other value never matches the hash, is always sent, and clears the stored hash.
- The requirement covers `$set` updates from `identify(...)` as well, since they share the cache.
- Narrative: step 5 of `set-person-properties` Behavior and the `identify` hash notes point at the requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `set-person-properties`: new requirement with three scenarios, plus a narrative note under Behavior step 5.
- `identify`: narrative pointer only, in the client-side flow and state notes. No requirement changes.

## Impact

- **posthog-ios**: [#1050](https://github.com/PostHog/posthog-ios/pull/1050), merged into `chore/v4-remove-deprecated` on 2026-11-10 as `0a5e7655228988894b522d1dc448cafaa595ffcc`.
- **posthog-android**: [#965](https://github.com/PostHog/posthog-android/pull/965), open against `chore/v4-remove-deprecated`, and [#967](https://github.com/PostHog/posthog-android/pull/967), open against `main`, which reads the update after `beforeSend` and records the hash only once it is queued.
- **Flutter on iOS and Android** inherits the behaviour from the native SDKs.
- **Flutter on Windows and Linux** doesn't: the Dart core keeps its own hash (`posthog_flutter/lib/src/core/posthog_core.dart`, `_cachedPersonProperties`). [posthog-flutter#637](https://github.com/PostHog/posthog-flutter/pull/637) applies the rule there in `88594d6`, reading the setting from the event as queued.
- **React Native** doesn't: `setPersonProperties` and the `$set` hash live in the JS core (`packages/core/src/posthog-core.ts`, `_cachedPersonProperties`). Only replay, crash and push events go through the native SDKs.
- **Not audited here**: other SDKs that keep a person-properties hash. See the PR description.
- `acceptance/public/set-person-properties.feature` is unchanged: the shared harness has no step for capture options on `set person properties`.
