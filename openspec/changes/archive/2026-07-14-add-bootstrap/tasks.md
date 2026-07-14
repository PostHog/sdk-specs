## 1. Specification

- [x] 1.1 Audit `posthog-js` browser and core bootstrap behavior (config surface, identity, feature flags, `$feature_flag_called` enrichment, session id) as the canonical source.
- [x] 1.2 Confirm `posthog-android`, `posthog-ios`, and `posthog-flutter` have no bootstrap support, so the spec is their convergence target.
- [x] 1.3 Add the new `bootstrap` capability spec under `specs/bootstrap/spec.md`.
- [x] 1.4 Specify the config surface, treating `distinctId` / `isIdentifiedId` as semantic field names spelled per platform convention (browser `distinctID` and core `distinctId` both conformant).
- [x] 1.5 Specify identity bootstrap: non-overwrite of persisted identity, and identified vs. anonymous state.
- [x] 1.5a Specify that an identified bootstrap seeds only the distinct id (not the device/anonymous id), so `$device_id` is never the identified person's id; only an anonymous bootstrap seeds the anonymous id.
- [x] 1.6 Specify identity reconciliation as canonical — merge an anonymous local user via `identify()`, preserve-and-warn on a differing identified id — with the non-overwrite-only rule as the fallback for SDKs that cannot merge at init.
- [x] 1.7 Specify feature-flag bootstrap: served before the first `/flags` response, loaded values win, bootstrapped-only keys survive a partial load.
- [x] 1.7a Specify that bootstrap is first-session only: dropped on `reset()` (both the base layer and the `$used_bootstrap_value` signal) so it never re-applies to a new user.
- [x] 1.8 Specify the `$feature_flag_called` enrichment (`$feature_flag_bootstrapped_response`, `$feature_flag_bootstrapped_payload`, `$used_bootstrap_value`).
- [x] 1.9 Specify browser-only session bootstrap (`sessionID` UUIDv7 continuation) as allowed variation.

## 2. Cross-references

- [x] 2.1 Verify the `feature-flag-cache` and `remote-config` bootstrap references stay consistent with the new spec (no requirement changes needed).
- [x] 2.2 Note the interactions with `setup`, `get-feature-flag`, `get-feature-flag-payload`, `get-feature-flag-result`, `feature-flag-called-tracker`, `identify`, `reset`, and `session-manager`.

## 3. Acceptance coverage

- [x] 3.1 Add acceptance scenarios for bootstrapped identity precedence (fresh install vs. existing persisted identity).
- [x] 3.2 Add acceptance scenarios for serving bootstrapped flags before `/flags` and loaded values overriding them.
- [x] 3.3 Add acceptance scenarios for the `$used_bootstrap_value` transition before and after a `/flags` response.
- [x] 3.4 Add acceptance scenarios for identified-bootstrap device-id independence and for bootstrap not resurrecting after `reset()`.

## 4. Validation

- [x] 4.1 Run `openspec validate add-bootstrap --strict` and resolve any issues.
- [x] 4.2 Run `openspec validate --specs --strict` before archiving.
