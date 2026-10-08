## Context

The snapshot contract (archived as `2026-08-10-add-evaluate-flags`) defines exposure-on-access: `isEnabled` and `getFlag` mark the key accessed and report `$feature_flag_called` through the dedupe tracker. Its design calls the supersession map "functional, not side-effect-preserving" and never considers an opt-out. The single-flag getters that the snapshot supersedes all have one.

Server SDK survey of default branches on 2026-10-08:

| SDK | Client-level default | Per-call option on single-flag getters | Event control on snapshot reads |
| --- | --- | --- | --- |
| posthog-node | `sendFeatureFlagEvent` client option | `sendFeatureFlagEvents` | None. Reads ignore the client option; draft PostHog/posthog-js#5252 makes them honor it. |
| JVM server (`posthog-server`) | `PostHogConfig.sendFeatureFlagEvent` | `sendFeatureFlagEvent: Boolean?` on `getFeatureFlagResult`; `null` uses the config | Honors the config default. No per-read option. |
| posthog-python | None | `send_feature_flag_events` | None |
| posthog-ruby | None | `send_feature_flag_events:` | None |
| posthog-php | None | `$sendFeatureFlagEvents` | None |
| posthog-go | None | `FeatureFlagPayload.SendFeatureFlagEvents` (`*bool`, nil means `true`) | None |
| posthog-dotnet | None | `FeatureFlagOptions.SendFeatureFlagEvents` | None |
| posthog-elixir | None | `send_event:` on `get_feature_flag_result` | None |

In posthog-node and the JVM server SDK, the single-flag getters resolve the event decision as per-call option, then client-level default, then `true`. When the decision is `false`, the getters skip the dedupe tracker altogether.

## Goals / Non-Goals

**Goals:**

- A migrated call sends the same `$feature_flag_called` events as the legacy call it replaces, using a one-line replacement for every legacy call shape.
- An explicit client-level opt-out applies to snapshot reads too.
- Callers keep a per-flag way to get exposures, at the call site where they decide it today.

**Non-Goals:**

- Changing what triggers an exposure: creating a snapshot stays silent, payload reads stay silent, and a read with no option anywhere still emits.
- Specifying client-level defaults for SDKs that do not have one, or the singular and plural naming of the legacy per-call option. The open PostHog/sdk-specs#109 records that naming rule.
- OpenFeature providers and other wrappers built on top of the SDK. No spec in this repository governs them.

## Decisions

### Put the option on each read

The enablement and value accessors take an optional per-read option. Its name and meaning match the per-call option of the server getters, `sendFeatureFlagEvents` in platform casing, so `getFeatureFlag(key, id, { sendFeatureFlagEvents: x })` becomes `flags.getFlag(key, { sendFeatureFlagEvents: x })`. The decision stays at the line of code that makes it today. The option uses the platform's idiomatic optional-argument form (an options object, a keyword or named argument, an overload, or a functional option).

The payload accessor, key enumeration and in-memory filters take no option, because they never report `$feature_flag_called`.

### Resolve per-read, then client default, then send

The per-read value wins. Without it, the SDK's client-level default applies where one exists. Without either, the read sends. This is the order the single-flag getters already use, so moving a call onto the snapshot does not change its events.

### Keep exposure, dedupe and access separate

A read that does not send emits no `$feature_flag_called`, and the SDK does not consult or update the dedupe tracker for it. The tracker records which exposures were reported. If a suppressed read marked it, a later read of the same key that is opted in, for example the experiment branch of the same request, would be deduplicated away and the experiment would lose its exposure. The single-flag getters already skip the tracker when their option is `false`.

The read still marks the key as accessed for `onlyAccessed()`. Access means the code branched on the flag, and `onlyAccessed()` scopes capture enrichment to those flags. Exposure is a separate analytics signal. A customer who turns exposure events off still wants the `$feature/<key>` properties on the events it captures.

The `flag_missing` event for a key absent from the snapshot is the same `$feature_flag_called` event, so it follows the same decision.

### Preserve exposure-event control in the supersession map

The earlier design accepted side-effect differences in the migration map: bulk maps that become tracked reads, and Go's event-emitting payload getter that becomes a silent snapshot read. Those differences stay. A per-call event setting is different. It is an explicit customer choice, and the getters now point every caller at the snapshot API. A migration that silently reverses that choice is a regression, so the map carries the option across.

### Alternatives considered

- **A per-snapshot option on `evaluateFlags()`.** Rejected. One incoming request typically reads experiment flags and operational flags (kill switches, configuration) from the same snapshot. A per-snapshot setting would force a second `evaluateFlags()` call, and so a second `/flags` request, to mix the two. That defeats the single-evaluation purpose of the API, for the same reason the runtime filter was put on the snapshot rather than on `evaluateFlags()`.
- **Only honor the client-level default.** This is what #5252 does on its own. It is necessary but not enough. A client with the default off has no way to opt specific reads back in, so its experiments lose exposures. A default-on client cannot silence a single read, such as a health check or a bulk scan. Six of the eight surveyed SDKs have no client-level default, so they would get no control at all.
- **Update the dedupe tracker on suppressed reads.** Rejected, because it swallows a later opted-in exposure for the same identity, key and value.
- **Skip access tracking on suppressed reads.** Rejected. `onlyAccessed()` would drop flags the code branched on, and capture enrichment would no longer match the decision.

## Risks / Trade-offs

- **Callers who relied on snapshot exposures while the client default was off lose them when the SDK starts honoring the default.** This affects posthog-node after #5252. The SDK's changelog says so, and those reads opt back in with the per-read option.
- **Legacy per-call option names differ in two SDKs.** The JVM server SDK uses `sendFeatureFlagEvent` and posthog-elixir uses `send_event`. The snapshot option uses the server name `sendFeatureFlagEvents`, so a migrated call in those SDKs also renames the argument.
- **The option adds a parameter to accessors that some SDKs expose as single-argument methods** (Go, .NET, PHP, the JVM server SDK). Each SDK adds it in a backward-compatible way for its platform.

## Migration Plan

This repository change is documentation-only. After archive:

- Every server SDK that implements `evaluateFlags` adds the per-read option to its enablement and value accessors.
- posthog-node lands #5252 or an equivalent so snapshot reads honor `sendFeatureFlagEvent`. The JVM server SDK already honors `PostHogConfig.sendFeatureFlagEvent`.
- An SDK whose snapshot reads ignored its client-level default until now says in its changelog that callers who relied on snapshot reads for exposures while that default was off must now opt those reads in with the per-read option.
- Wrappers that pass an explicit per-call value on every read override the client-level default. For example, the posthog-node OpenFeature provider defaults its own `sendFeatureFlagEvents` to `true` and passes it on every call. Such wrappers should leave the option unset unless their caller sets it.

## Open Questions

None.
