## Why

Nearly every SDK has shipped a server-gated "minimal event" mode for `$feature_flag_called`
that the `feature-flag-called-tracker` spec says nothing about. The rollout originated in
posthog-python#748 and has since landed, describing itself as "part of a cross-SDK rollout,"
in:

- posthog-python#748 (reference implementation, merged 2026-07-18)
- posthog-js / posthog-node#4172 (shared `@posthog/core`, merged 2026-07-21)
- posthog-ios#724
- posthog-php#205
- posthog-ruby#220
- posthog-go#261
- posthog-dotnet#263
- posthog-flutter#482 (currently only in the `sdk_compliance_adapter` test harness, not the
  shipping `posthog_flutter` package — the Dart SDK delegates flag-called capture to the
  native iOS/Android/web SDKs it wraps)

posthog-android has not shipped this yet (only the precursor `$feature_flag_has_experiment`
property, #621); posthog-java has had no relevant activity in the lookback window.

Today `$feature_flag_called` events carry the full enriched properties dict (super properties,
context tags, custom event properties, system context) on every flag call. The new behavior:
when the server enables a per-team gate and the evaluated flag is not linked to an experiment,
the SDK now sends a trimmed allowlist instead, cutting event size/ingestion cost for the
majority of flags that aren't used in experiments. No spec currently documents the event's
property shape at all (canonical, minimal, or otherwise), so this is a pure gap, not a
divergence from an existing requirement.

## What Changes

- Add a new requirement to `feature-flag-called-tracker`: **Minimal event mode for
  non-experiment flags**, describing the two gate signals (`minimalFlagCalledEvents` in the
  `/flags` v2 response; `minimal_flag_called_events` in the local-evaluation definitions
  payload), the `has_experiment` condition (must be exactly `false`; missing/unknown/`true`
  all keep the full event), the allowlisted property categories, the fail-safe-to-full-event
  behavior, and gate persistence across cache/definitions round-trips.
- The exact property allowlist varies slightly by SDK (server SDKs add `$is_server` and
  `locally_evaluated`; each SDK keeps its own static platform/runtime identity fields such as
  `$os`/`$python_version` for Python or `$os_name`/`$app_version` for mobile). The requirement
  states the allowlist at the category level (identity, evaluation debug, group/session
  context, SDK identity, static platform identity) rather than one fixed literal list, since no
  single SDK's exact list is the canonical one — posthog-python's is used as the illustrative
  reference since it's the origin implementation other SDKs describe mirroring.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `feature-flag-called-tracker`: adds one new requirement. The existing dedup-tracker
  requirement and its scenarios are unchanged.

## Impact

- `openspec/specs/feature-flag-called-tracker/spec.md` — source of truth, updated via this
  change's delta.
- Implementations: posthog-python, posthog-js, posthog-node, posthog-ios, posthog-php,
  posthog-ruby, posthog-go, and posthog-dotnet already conform. posthog-flutter's real SDK does
  not yet implement this (only its compliance test adapter does — flag-called capture is
  delegated to the wrapped native/web SDK there). posthog-android and posthog-java do not yet
  implement this; not flagged as drift for those two since not-yet-shipped is expected during a
  staged rollout, not a spec/implementation mismatch.
- No acceptance-harness changes in this proposal; scenarios describe the contract precisely
  enough for a future harness port to implement the `minimalFlagCalledEvents` /
  `minimal_flag_called_events` mock-server controls.
- **Low-confidence detail, flagged for human review:** the exact allowlist literal (property
  names) is taken from posthog-python#748's changeset/source since it's the best-documented
  reference implementation; other SDKs were only checked via PR descriptions, not full diffs,
  so minor allowlist differences between SDKs may not all be captured. Worth a follow-up
  audit once all SDKs have shipped this to confirm true convergence before tightening the
  requirement from "categories" to a fixed literal list.
