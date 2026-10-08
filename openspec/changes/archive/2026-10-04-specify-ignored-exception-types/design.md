## Overview

This change does not add a capability. It records an existing, previously unspecified error-tracking
option on `capture-exception`, now that posthog-ios and posthog-android agree on its default.
posthog-kmp exposes the same option by forwarding it to those two.

## Key Decisions

- **Make the option optional, and condition the requirement on exposing it.** Only posthog-ios and
  posthog-android implement it, and posthog-kmp forwards to them. Requiring it everywhere would invent work no one asked for; saying nothing leaves
  the next SDK to pick its own default, which is how the posthog-ios default drifted in the first
  place.
- **Specify the empty default as a SHALL.** It is the only part observable without configuration,
  and it is what the posthog-ios change fixed. A non-empty default silently drops a user's events.
- **Specify the chokepoint, not the call site.** Both SDKs apply the list to manual capture,
  autocapture, and the generic `capture("$exception", …)` path that wrapper SDKs use. An SDK that
  filtered only `captureException` would leak the events a React Native or Flutter bridge sends.
- **Leave the matched identifier platform-idiomatic.** posthog-android matches `Class.isInstance`,
  so a subclass of an ignored type is dropped; posthog-ios matches the serialized `type` string
  exactly. Both are right for their platform — an `NSException`'s `name` is not a class hierarchy.
  posthog-android also matches by name on the generic-capture path, rejoining `module` and `type`
  into the qualified class name. The spec pins the chain, the case sensitivity and exact equality
  on a form the SDK documents, which are observable, and lets the identifier follow the platform;
  a scenario covers the qualified-name form.
- **Keep it in `capture-exception` rather than a new capability.** The spec's "Error handling"
  section already gestures at local suppression; this gives that sentence a contract. Autocapture
  shares the same filter and the same chokepoint, so splitting it would duplicate the requirement.

## Alternatives Considered

- **Specify exact-string matching everywhere.** Rejected. It would make posthog-android stop
  dropping subclasses of an ignored type, a behavior change with no reported demand.
- **Specify `isInstance`-style matching everywhere.** Rejected. posthog-ios matches `NSException`
  names, which are free-text-bearing strings with no type hierarchy to consult.
- **Say nothing until a third SDK adds the option.** Rejected. The defaults agree now; writing it
  down is what stops the next implementation from repeating the posthog-ios default.

## Open Questions

- Whether a future SDK should be *required* to expose the option. Out of scope here; the
  requirement is deliberately conditioned on the option existing.
