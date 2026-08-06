## 1. Verification (grounding checks — every requirement traces to shipped source)

- [x] 1.1 Verify the endpoint, Bearer-only auth, envelope, and per-event wire shape against the
  reference `posthog-rs`: `src/client/v1_capture.rs` (`V1_CAPTURE_PATH`), `src/event_v1.rs`
  (`V1Event`, `V1BatchRequestRef`)
- [x] 1.2 Verify the options sentinel-lifting table and coercion (`$cookieless_mode`,
  `$ignore_sent_at`→`disable_skew_correction`, `$product_tour_id`, `$process_person_profile`, plus
  top-level `$session_id`/`$window_id`) in posthog-rs `src/constants.rs`
  (`OPTIONS_EXTRACTION_TABLE`) and `src/event_v1.rs`
- [x] 1.3 Verify the four result codes, partial-retry algorithm, retryable set (`429` terminal),
  and `Retry-After`-as-clamped-minimum (30s ceiling) in posthog-rs `src/client/retry.rs` and
  `src/client/v1_capture.rs` (`process_batch_response`, `after_response`, `backoff_duration`)
- [x] 1.4 Confirm the same contract in the three mirroring SDKs: posthog-go (`capture_v1.go`,
  `capture_v1_send.go`), posthog-node (`packages/node/src/capture-v1/{sender,transform,types,
  routing}.ts`), posthog-python (`posthog/capture_v1.py`), including the "mirrors posthog-rs" /
  "see rust/capture/src/v1/analytics/types.rs" comments
- [x] 1.5 Verify the two divergences: compression codec matrix (rs/go all four; python
  gzip/deflate/zstd; node gzip-only) and posthog-node `$ai_*` legacy-v0 routing
  (`packages/node/src/capture-v1/routing.ts`)
- [x] 1.6 Confirm the cross-SDK `capture_v1` compliance suite exists (posthog-rs `compliance/v1/`,
  posthog-go `sdk_compliance_adapter` capability `"capture_v1"`)

## 2. Spec delta

- [x] 2.1 Every requirement in `specs/capture-v1/spec.md` has ≥1 scenario and traces to verified
  source above
- [x] 2.2 Divergences are surfaced (not papered over) with a recommendation and a human-decision
  flag in design.md

## 3. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 3.1 Add a Purpose section to `openspec/specs/capture-v1/spec.md` (logs/traces-style):
  transport not public API, derived from posthog-rs + the backend type, mirrored by go/node/python
- [x] 3.2 Add the capture v1 transport to the Capabilities prose in `openspec/project.md`
- [x] 3.3 Add a Capture V1 row to the Capabilities table in `README.md`

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 4.2 Archive to create `specs/capture-v1/spec.md`

## 5. Downstream follow-up (separate work, not this change)

- [ ] 5.1 Resolve the two open questions (compression parity target; `$ai_*` carve-out normativity)
  with the client-libraries team on the PR
- [ ] 5.2 Add `capture-v1` to the cross-SDK conformance tracking (README conformance-matrix TODO)
  once the spec is canonical
- [ ] 5.3 Consider a `capture` spec cross-reference to `capture-v1` as a transport option (kept out
  of this change to leave the generic capture contract untouched)
