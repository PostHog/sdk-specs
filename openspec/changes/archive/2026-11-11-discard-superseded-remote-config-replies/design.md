## Context

Remote config is fetched asynchronously and then pushed into integrations, so the reply outlives the call that started it. The spec already deduplicates concurrent loads and allows clearing cached config on teardown, but says nothing about a reply that returns to a lifecycle that no longer exists. The failure is not a stale *value* — it is a dead or replaced object graph being re-armed by a callback it no longer owns.

## Goals / Non-Goals

**Goals:** State that a reply belongs to the setup that issued it, and that a reply outliving that setup is dropped silently.

**Non-Goals:** Requiring SDKs to support setup after shutdown, specifying cancellation of the in-flight request, changing reset semantics, or prescribing how identity is tracked.

## Decisions

- Match on issuing-setup identity, not on the instance's enabled flag. The Android bug is precisely that the enabled flag is true again after a second setup, so a liveness check alone passes while the reply still belongs to the dead setup.
- Cover both the configuration and the loader that produced the reply. A host may reuse the same configuration object across shutdown and setup, in which case configuration identity matches and only the loader distinguishes the two lifecycles.
- Drop silently rather than report an error. The reply is correct; it is simply no longer wanted, and routing it to error handling would make an ordinary shutdown race look like a failure.
- Say nothing about cancelling the in-flight request. Whether the request is aborted or allowed to complete and then ignored is an implementation choice with the same observable outcome.
- Reset is left alone. Reset keeps the same live setup and re-identifies the user, so discarding there is a different question; [posthog-ios#1048](https://github.com/PostHog/posthog-ios/pull/1048) handles the flag-load half of it and is not generalized here.

## Risks / Trade-offs

- The evidence is from one SDK. The rule is stated in terms the capability already uses (setup, shutdown, listeners) so that an SDK with no reusable instance satisfies it without new code, but a reviewer should confirm no SDK deliberately applies a late reply.
- An SDK that caches the reply to persistent storage before deciding to apply it may still write a value the live setup did not ask for. This change does not address that; the harm in the reported case was the notification, not the cache.

## Migration Plan

Sync and archive this change in the same PR. posthog-android already ships both halves; other SDKs can adopt the guard when they next touch their remote-config path.

## Open Questions

Whether a reply should also be prevented from writing the cache when its setup has ended. Left open because no SDK has reported harm from the cache write alone.
