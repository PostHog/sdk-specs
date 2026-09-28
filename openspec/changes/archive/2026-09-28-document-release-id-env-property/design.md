## Context and sources

- [posthog-python#975](https://github.com/PostHog/posthog-python/pull/975) is the reference implementation: `_resolve_release_id()` reads `POSTHOG_RELEASE_ID` once per client, trims it, treats blank as unset, and the client calls `setdefault("$release_id", ...)` after the super-properties merge.
- [posthog-php#247](https://github.com/PostHog/posthog-php/pull/247) stamps the property in `Client::message()`, the shared path behind `capture()`, `captureException()`, `identify()`, `alias()`, and `groupIdentify()`. `raw()` bypasses that path and is untouched.
- [posthog-ruby#277](https://github.com/PostHog/posthog-ruby/pull/277) stamps it in `Client#enqueue`, the one shared path, and keeps it out of `$set` and `$group_set`.
- The existing `exception-event-metadata` requirement already assumes `$release_id` may be present and forbids exception builders from inventing their own; this change supplies the missing producer contract.

## Decisions

1. Require a single read at client construction rather than per event. All three SDKs do this, and it keeps the value stable for the client's lifetime.
2. Require trimming with blank-as-unset so `POSTHOG_RELEASE_ID=` never produces an empty `$release_id`.
3. Require the stamp on the shared event path rather than enumerating public methods, matching the PHP and Ruby rationale that a new event type cannot then miss it.
4. Make an explicit caller or super/context value win. All three SDKs implement the environment value as a default, not an override.
5. Keep the property out of person and group property payloads. Ruby asserts this explicitly; a release id is event context, not a person trait.
6. Leave the minimized `$feature_flag_called` case unspecified. Python excludes `$release_id` from its allowlist while PHP includes it, and the `feature-flag-called-tracker` allowlist requirement is deliberately stated at the category level. Picking a winner here would be a guess about intent rather than a record of settled behavior.

## Validation

`openspec validate --specs --strict` and delta/canonical parity. The scenarios are contracts, not a claim that cross-SDK conformance tests have been run against them.

## Risks

Scoping the requirement to "server SDKs that can read process environment" leaves the boundary for embedded and sandboxed runtimes soft. The alternative — naming the current three SDKs — would date immediately. The unresolved minimized-flag-event divergence is called out rather than settled.
