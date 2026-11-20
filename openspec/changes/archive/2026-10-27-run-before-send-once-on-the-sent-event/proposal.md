## Why

The `before-send-hook` spec says the hook runs after event assembly and that downstream queueing observes the hook's changes, but it never says how many times the hook runs, nor which assembly steps must already be done when it runs. Two SDKs changed that behavior this week after finding they diverged from the rest of the fleet:

- `posthog-android` ran the hook chain twice for every event captured through the stateful client: once when the event was built and again when the event was rebuilt for the stateless capture path. Hooks with side effects ran twice, random or uuid-keyed sampling hooks kept roughly half of their configured rate, and hook edits to `distinctId`, `timestamp` and `uuid` were discarded by the second build. It now runs the chain once and queues the event the hook returned.
- `posthog-rust` merged group assignments into `$groups` after the hook, so a hook could not see or change groups, and it trimmed minimized `$feature_flag_called` events after the hook, so properties a hook added to those events were silently dropped. Both steps now happen before the hook, matching `posthog-python`.

Both changes converge on the same contract: the hook runs once, and it sees the event that will actually be sent. `posthog-ios` and `posthog-python` already behave this way. Writing it down keeps the next SDK from rebuilding the event around the hook.

## What Changes

- Add a `before-send-hook` requirement that the hook chain runs exactly once per captured event.
- Require that the event handed to the hook is the event that would be sent if the hook returned it unchanged: group assignments already merged into `$groups`, and a minimized `$feature_flag_called` event already trimmed.
- Require that the SDK enqueues the hook's returned event rather than rebuilding it, so hook edits to the event name, properties, `distinctId`, `timestamp` and `uuid` survive to delivery.
- Preserve the already-documented wrapper-layer divergence (Flutter's Dart-layer hooks run before native enrichment and skip `$feature_flag_called`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `before-send-hook`: specify a single invocation per event, on the event as it will be sent.

## Impact

SDKs that assemble an event, run the hook, and then rebuild the event for a shared capture path become non-conformant; `posthog-android` already fixed this. SDKs that merge groups or trim minimized `$feature_flag_called` events after the hook become non-conformant; `posthog-rust` already fixed this. No wire format or public API changes.
