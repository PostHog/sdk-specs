## Why

PostHog SDKs disagree on whether `$exception` events include `$exception_level` and `mechanism.handled`, and several capture paths send values that do not describe how the exception was captured. The ingestion pipeline can only assign an initial issue severity safely when SDKs provide explicit, trustworthy signals.

## What Changes

- Amend the `capture-exception` capability with a normative contract for `$exception_level` and `$exception_list[].mechanism.handled`.
- Require SDK-owned capture paths to set `handled` explicitly when the capture boundary knows whether application code handled the exception.
- Define level semantics for manual capture, uncaught exceptions, crashes or panics, and logger- or console-derived captures.
- Allow `$exception_level` and `handled` to remain absent when a low-level or third-party producer cannot determine them confidently; SDKs MUST NOT invent fallback values for unknown signals.
- Add cross-SDK acceptance scenarios for handled manual capture, unhandled capture, fatal capture, logger-level capture, and unknown-signal omission.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture-exception`: standardizes the severity and handled-state metadata carried by SDK-generated `$exception` events.

## Impact

Audit basis: the latest `origin/main` of sibling SDK repositories fetched on 2026-08-12.

- **Already aligned for primary capture paths:** posthog-android, posthog-ios, posthog-flutter, posthog-react-native, and posthog-rs.
- **posthog-js browser:** mark console captures handled and keep uncaught browser errors unhandled.
- **posthog-node:** emit `fatal` when the uncaught-exception path will terminate the process; preserve `error` for non-fatal unhandled boundaries.
- **posthog-python:** add `$exception_level` on the main capture path and pass explicit handled state from manual, context, `sys.excepthook`, thread, Django, and Celery capture boundaries.
- **posthog-go:** add typed level and mechanism data; set manual defaults in `NewDefaultException`; derive level and handled state in the slog adapter; permit low-level manually built payloads to omit unknown signals.
- **posthog-ruby:** add `$exception_level`; distinguish handled Rails reports from unhandled middleware and job failures.
- **posthog-php:** add `$exception_level`; map manual capture, PHP error severities, uncaught exceptions, and shutdown failures without changing its existing explicit handled metadata.
- **posthog-elixir:** copy the Logger level into `$exception_level` and retain explicit handled state derived from crash metadata.
- **Backend coordination:** PostHog/Cymbal infers initial issue severity only from recognized explicit signals and leaves severity unset for incomplete or unknown metadata (PostHog/posthog#81913).
- **Spec artifacts:** update the `capture-exception` delta and `acceptance/public/capture-exception.feature`; implementation changes remain in each SDK repository.
