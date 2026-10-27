## Why

Server SDKs attach `$feature/<key>` and `$active_feature_flags` to a captured event when the
caller passes a flags snapshot or enables `send_feature_flags`. The `capture` spec mentions the
stamping (Interactions, "Feature flags") but never says where those properties sit in the merge
order, and the server bullet of Behavior step 4 does not list them at all. The spec's one
precedence requirement, **Caller-supplied event properties take precedence**, is explicitly
client-only, and [sdk-specs#143](https://github.com/PostHog/sdk-specs/pull/143) keeps it that way.

Two server SDKs converged on the same order in the same week, which makes it a contract rather
than an implementation detail:

- posthog-python [#1121](https://github.com/PostHog/posthog-python/pull/1121) moves flag
  properties into the SDK-values layer on `v1`, so the call's `properties`, context tags and
  `super_properties` all win over them — matching 7.x.
- posthog-go [#392](https://github.com/PostHog/posthog-go/pull/392) documents the same order for
  v2: flag properties fill under the event's `Properties`, the request context and
  `DefaultEventProperties`.
- posthog-node merges `buildFlagEventProperties(...)` before the event's own `properties` in
  `packages/node/src/client.ts`, so the caller wins there too.

## What Changes

- Add a `capture` requirement stating that on server SDKs the feature flag properties are values
  the SDK adds: they fill only the keys left unset by the event's own properties and, where the
  SDK has them, the ambient request context and the SDK-level default/super properties.
- Name the flag properties in the server bullet of Behavior step 4 and in the Interactions entry,
  so the ordering is visible where the merge is described.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: place the server-side feature flag properties in the property merge order.

## Impact

posthog-python `v1`, posthog-go v2 and posthog-node already behave this way. posthog-python 7.x,
posthog-go 1.x's `Flags` snapshot path and posthog-node 5.x match as well. posthog-go 1.x's
`SendFeatureFlags` path overwrites a value set on the event or in the request context and is
non-conforming until v2; that is tracked in posthog-go, not here. The requirement is silent on
whether SDK-level default properties outrank the caller's event properties, because the fleet
still disagrees there — see the open question in `design.md`.
