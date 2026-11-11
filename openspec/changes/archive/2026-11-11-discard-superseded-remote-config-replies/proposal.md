## Why

`remote-config` says a successful reply is cached, applied to local features, and announced to listeners, and that cached state may be cleared on reset or teardown. It does not say what happens when the reply arrives *after* the lifecycle that asked for it has ended.

[posthog-android#953](https://github.com/PostHog/posthog-android/pull/953) found the gap: a `/config` or `/flags` reply landing after `close()` still ran every integration's remote-config hook on the closed client. The native crash integration re-installed itself, its tombstone scanner ran, capture dropped the event because the client was closed, and the watermark still advanced — a real crash record acknowledged and never sent. [posthog-android#961](https://github.com/PostHog/posthog-android/pull/961) covers the next step: `close()` then `setup()` on the same instance, where the previous setup's reply re-arms the old configuration's integrations because the instance is enabled again. The static `PostHog` API does exactly that close-then-setup, so it is reachable from ordinary app code.

Neither case is an SDK-local accident: any SDK that applies remote config asynchronously and lets an instance be shut down can land a reply on a dead or replaced lifecycle.

## What Changes

- Require that a remote-config reply is applied and announced only while the setup that issued it is still the live one.
- Require that a reply landing after shutdown is discarded without applying state or notifying integrations and listeners.
- Require that a reply issued by a previous setup is discarded after a later setup on the same instance, matched by issuing-setup identity rather than by the instance being enabled again.
- Keep discarding silent: it is not an error, and it must not block the live setup's own reply.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `remote-config`: add a requirement covering replies that outlive their setup.

## Impact

Only `openspec/specs/remote-config/spec.md` changes. No public API, wire format, endpoint, or configuration change. An SDK that cannot be set up again after shutdown satisfies the second half trivially. SDKs without this capability are unaffected.
