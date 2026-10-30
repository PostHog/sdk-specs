## Context

The hook is the last application-controlled interception point before delivery. Its usefulness depends on two properties the spec left implicit: it runs a predictable number of times, and what it inspects is what ships.

## Decisions

**Exactly once, not at-least-once.** Hooks are not required to be idempotent. Sampling hooks that draw randomly, or that hash `uuid`, produce a different answer on each pass, so a second invocation silently changes the effective sampling rate. "At most once" would allow skipping the hook for some events, which would break privacy filters. So: exactly once per captured event that reaches the hook at all.

**The hook sees the sent event.** Two concrete assembly steps were ordered inconsistently across SDKs:

- *Group merging.* A hook that cannot see `$groups` cannot redact or correct group identity.
- *Minimized `$feature_flag_called` trimming.* When minimal flag-called events are enabled, trimming after the hook deletes properties the hook added, and shows the hook a shape that is never sent. `posthog-python` and `posthog-ios` already trim first.

The requirement is stated as a general rule ("the event the SDK would send if the hook returned it unchanged") with these two steps called out, rather than as a full ordered list of assembly steps, because the rest of the assembly order is not yet audited across the fleet.

**No rebuild after the hook.** This is the corollary that makes mutation meaningful, and is the part `posthog-android` violated. The spec already said downstream queueing observes modified values; this states the implementation constraint that follows.

## Open questions

- Consent gating, sanitizers and the dynamic-context build are ordered differently across SDKs. This change does not fix their position relative to the hook.
- Flutter's Dart-layer hook still runs before native enrichment. That divergence is documented, not resolved here.
