## Context

Canonical `capture` requires remote requests to inherit effective GeoIP, recommends disabled-by-default enrichment, and preserves shipped enabled defaults. Node and Python disable it; Go's nil config resolves true; Ruby and Elixir remote requests currently default false. Canonical `get-feature-flag-result` permits legacy scalar false sentinels without treating them as successful disabled decisions. Current sdk-specs already encodes four failed readers as false or no value; the released Gherkin bundle and generator lag that text.

## Decisions

The omitted fixture consults truthful profile metadata `flags_geoip_default_disabled`; undeclared profiles retain strict boolean false. It never injects configuration. Both explicit directions remain wire assertions. Failed-reader acceptance is restricted to explicit `failed: true` records and false/null/undefined outcomes after served `/flags?v=4` verification. Healthy false and malformed records remain strict. No normative spec amendment is needed.

The capture overview table is editorially reconciled with its existing concurrency paragraph documenting Python `sync_mode` and core `sendImmediate`; queued delivery remains normally batched. Archive this documentation-only change with `--skip-specs`, because there is no requirement delta to sync.

## Validation and rollout

Harness tests cover native default branches, explicit overrides, missing/mistyped fields, failed marker gating, real outcome rejection, thrown/void rejection, and actual fixture traffic. Full Node capture v0/v1 profiles run against a real local dirty-source distribution built from this authoritative checkout. Current specs/harness must be reviewed and published with an immutable real specs commit before SDK CI pins advance; local development images are not releases.
