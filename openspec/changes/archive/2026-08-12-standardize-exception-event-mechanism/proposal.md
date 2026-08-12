## Why

PostHog SDKs serialize `$exception_list[].mechanism` inconsistently. Builders may omit known capture context, drop integration-supplied fields, invent defaults for unknown values, or use different semantics for handled and synthetic state. Consumers therefore need SDK-specific knowledge to interpret exception events.

A shared wire contract makes mechanism metadata portable across client and server SDKs while allowing platform-specific mechanism types and native diagnostics.

## What Changes

- Add an internal `exception-event-mechanism` capability covering all common fields in `$exception_list[].mechanism`.
- Define field types and omission semantics for `type`, `handled`, `source`, and `synthetic`.
- Require low-level builders to preserve caller- and integration-supplied common mechanism metadata.
- Define stable mechanism types without imposing a closed cross-platform taxonomy.
- Define source, handled state, and synthetic state independently at the capture boundary.
- Define the related `$exception_level` vocabulary and capture-boundary defaults.
- Add private client/server acceptance scenarios for manual and automatic exception paths.

## Capabilities

### New Capabilities

- `exception-event-mechanism`: standardizes mechanism metadata on SDK-generated `$exception` events for client and server SDKs.

### Modified Capabilities

None.

## Impact

Audit basis: the latest `origin/main` of sibling SDK repositories fetched on 2026-08-12.

- **posthog-js family:** preserve supplied type, handled, source, and synthetic fields in the shared builder; correct browser console handled state; distinguish terminating Node failures; normalize React Native console levels.
- **posthog-python:** preserve common mechanism fields while retaining richer platform extensions; add `$exception_level`; pass explicit boundary metadata from manual and automatic integrations.
- **posthog-go:** expand the typed mechanism model with type and source; keep unknown low-level fields optional; derive logger metadata in the slog adapter.
- **posthog-ruby:** preserve common mechanism fields while retaining richer cause metadata; add `$exception_level`; distinguish handled Rails reports from unhandled middleware and job failures.
- **posthog-php:** preserve primary mechanism overrides; add `$exception_level`; map PHP error, uncaught, and shutdown boundaries.
- **posthog-elixir:** retain Logger-derived mechanism context and add normalized `$exception_level`.
- **posthog-android and posthog-server:** retain mechanism type, handled, and synthetic metadata.
- **posthog-ios:** retain common mechanism fields while preserving richer crash-reporter extensions.
- **posthog-flutter:** retain mechanism type, handled, and synthetic metadata across manual and automatic integrations.
- **posthog-rs:** retain common mechanism fields while preserving richer cause metadata.
- **Spec artifacts:** add `openspec/specs/exception-event-mechanism/spec.md` and `acceptance/private/exception-event-mechanism.feature`; implementation changes remain in each SDK repository.
