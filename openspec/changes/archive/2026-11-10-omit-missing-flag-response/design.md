## Context

`$feature_flag_called` carries `$feature_flag_response`, the legacy rendering of the value a read
returned. The spec pins that rendering for a config version 2 record ("Config version 2 attribution
on `$feature_flag_called`") and shows it as `true` in the canonical scenarios, but it has never said
what the property holds when there is no record for the key at all.

## Goals / Non-goals

- Goal: one meaning for the empty string on this event, so "empty variant" and "no such flag" are
  distinguishable downstream.
- Non-goal: picking a single winner between an absent property and an explicit `null`. They read the
  same downstream and each SDK's serializer already decides this (see `capture`, "Capture drops
  null-valued object properties", which iOS 4.0 now follows for every property).
- Non-goal: anything about the value the read *returns*. `is-feature-enabled` and `get-feature-flag`
  already specify defaults for a missing flag; this is only about the event property.

## Decisions

- **Absent or `null`, never `""`.** Five SDKs independently landed on absent or `null`; only Android
  sent `""`, and it changed. The empty string is reserved for a flag whose value is an empty variant
  key.
- **`false` is recorded as tolerated variation, not endorsed.** The shared harness accepts `absent`,
  `null` or `false` for a missing-flag exposure (`flag_snapshot_exposure_missing_*`), and an SDK
  whose enabled check resolves a missing flag to `false` by construction (`is-feature-enabled`,
  "Allowed variation for the no-default call") reports that resolved value. Ruling `false` out would
  be a new cross-SDK break, which is not what the SDK change that prompted this did.
- **No acceptance scenarios.** "Absent or `null`" needs a step the harness does not have.
