## Context

Unlike a greenfield spec, capture v1 already ships in four SDKs, so every requirement traces to
verifiable source. Priority order:

1. **The reference SDK — `posthog-rs`** (`src/client/v1_capture.rs`, `src/event_v1.rs`,
   `src/client/retry.rs`, send loops in `src/client/{async_client.rs,blocking.rs}`, tests
   `tests/test_v1_capture.rs` / `tests/test_v1_blocking.rs`, `compliance/v1/`). The other three
   SDKs carry comments explicitly saying they mirror it.
2. **The backend type** — `rust/capture/src/v1/analytics/types.rs` in PostHog/posthog, which all
   four SDKs cite as the source of the envelope, the `options` struct, and the four result codes.
3. **The three mirroring SDKs**, used to confirm the contract is genuinely shared and to find the
   divergences: `posthog-go` (`capture_v1.go`, `capture_v1_send.go`,
   `capture_v1_integration_test.go`); `posthog-node` in the posthog-js monorepo
   (`packages/node/src/capture-v1/{sender,transform,errors,types,config,routing}.ts` and tests);
   `posthog-python` (`posthog/capture_v1.py`, `posthog/test/test_capture_v1.py`, `AGENTS.md`).

The contract is remarkably consistent across all four — the same endpoint, Bearer-only auth,
envelope, sentinel-lifting table, four result codes, partial-retry algorithm, retryable status set
(`{408,500,502,503,504}` with `429` terminal), `Retry-After`-as-clamped-minimum with a 30s ceiling,
the same four `PostHog-*` headers, and the same default of 4 total attempts. Where they differ, the
spec states the winner and flags the divergence.

## Decisions

**New separate spec `capture-v1`, not an addition to `capture`.** The repo's stated rule is "one
capability per spec folder; a new capability is a new sibling, never folded into an existing spec"
(`project.md`, `README.md`). The precedent is `logs` (and `traces`): a versioned-endpoint pipeline
that names `/i/v1/logs` gets its own spec rather than being merged into a generic spec. Capture v1
is exactly that shape — a distinct wire contract on a versioned endpoint (`/i/v1/analytics/events`)
with its own auth, result protocol, and retry semantics. Folding this into the `capture` spec would
also bloat a spec that is deliberately kept readable as the generic public-API contract. The generic
`capture` spec is left untouched.

**Named `capture-v1`.** Matches the endpoint version and the compliance-suite capability string
(`capture_v1`) already used by the harness and the posthog-go adapter. The reference SDK's internal
`v1_capture` / `V1Event` naming is noted in the spec as a permitted platform-idiomatic spelling.

**Modeled as a transport, not a public API.** All four implementations sit downstream of event
production: the same enriched, `before_send`-processed events are handed to a v1 serializer/sender.
The spec therefore scopes itself to serialization, transport, and response reconciliation, and
explicitly defers enrichment and batching policy to the `capture` / `event-batcher` specs. This
keeps the boundary clean and avoids restating the capture contract.

**`429` is terminal.** Verified in all four: the retryable set is exactly `{408,500,502,503,504}`
and `429` is classified terminal, with comments in posthog-go (`capture_v1_send.go`) and
posthog-python (`capture_v1.py`) stating this is a deliberate divergence from v0 (which retries
`429` when it carries `Retry-After`). The v1 backend signals transient overload through retryable
`5xx` + `Retry-After`, so a client `429` is treated as terminal.

**`Retry-After` is a clamped minimum.** All four wait `max(configured_backoff, Retry-After)` and
clamp `Retry-After` to the maximum backoff (canonical 30s), so a hostile/buggy header cannot park
the sender; the configured backoff schedule is never truncated below itself. posthog-go, posthog-rs,
and posthog-python all pin the 30s ceiling with a comment that it "unifies the default … (all 30s)".

**Sentinel-lifting drops mistyped values rather than 400-ing the batch.** All four strip every
sentinel key from `properties` unconditionally (these must never reach v1 backend properties) but
emit the lifted value only when it coerces to the expected type; an uncoercible value is dropped so
the backend applies its default. This is a deliberate robustness choice — one mistyped sentinel must
not make the server reject an entire batch. The boolean/string coercion rules are identical across
the four (native bool; `"true"/"1"/"false"/"0"` case-insensitive/trimmed; any nonzero number → true;
strings only for the string field).

**Unknown result codes and absent uuids are treated as accepted.** Forward-compatibility: a result
code the SDK does not recognize is terminal-success, and a uuid missing from the `results` map is
accepted. Verified in all four (posthog-rs uses a `#[serde(other)] Unknown` catch-all; the others
have explicit default arms).

## Known divergences — surfaced for a human decision, not papered over

**1. Compression codec breadth.** The four SDKs support different codec sets:

| SDK | gzip | deflate | zstd | br (brotli) |
| --- | --- | --- | --- | --- |
| posthog-rs | ✅ | ✅ | ✅ | ✅ |
| posthog-go | ✅ | ✅ | ✅ | ✅ |
| posthog-python | ✅ | ✅ | ✅ | — |
| posthog-node | ✅ | — | — | — |

(The task brief listed posthog-python as gzip/deflate; it also ships **zstd** behind the optional
`posthog[zstd]` extra — corrected here from the source.)

**Recommendation: permitted implementation choice, not a compliance gap.** Compression is negotiated
per codec — the server sniffs the body by magic bytes and the `Content-Encoding` header signals the
codec, and the compliance harness advertises support per codec (`encoding_gzip`, `encoding_deflate`,
`encoding_zstd`, `encoding_br`). `gzip` is the universal baseline; supporting a superset is a
platform choice (bundle-size and dependency tradeoffs differ — a browser-adjacent SDK reasonably
ships gzip only). The spec therefore requires the `gzip` baseline and the correct `Content-Encoding`
signalling, and marks broader codec support as an allowed variation. **Flagged for human
confirmation** that gzip-only (posthog-node) is acceptable rather than a parity requirement.

**2. posthog-node routes `$ai_*` events through the legacy v0 submitter regardless of mode.** Only
posthog-node emits LLM analytics (`$ai_*`) events, and it keeps them on the v0 `/batch/` path even
when in v1 mode, on isolated queues, because the AI ingestion path has no v1 form yet
(`packages/node/src/capture-v1/routing.ts`). The routing is decided on the post-`before_send` event
name.

**Recommendation: permitted (in fact necessary) divergence, not a compliance gap** — there is no v1
endpoint for `$ai_*` events to route to, so v0 is the only correct path, and the other three SDKs
have no such events to route. The spec captures this as a requirement that binds only SDKs which
emit `$ai_*` today. **Flagged for human decision** on whether this should be a normative cross-SDK
requirement (every future SDK that adds LLM analytics must carve `$ai_*` out of v1) or documented as
a posthog-node-local concern until an AI v1 ingestion path exists.

## Risks / Trade-offs

- **This spec describes shipped behavior across four SDKs rather than a single reference**, so a
  requirement could over-generalize a posthog-rs-specific detail. Mitigation: every requirement was
  cross-checked against all four implementations; where they differ, the spec states the winner and
  the divergence section records the difference.
- **The backend `rust/capture/src/v1/analytics/types.rs` is the ultimate source of truth** and could
  evolve (new result code, new `options` field). Mitigation: the result protocol is
  forward-compatible (unknown codes → success) and the sentinel table is closed (unknown `$`
  properties pass through untouched), so additive backend changes do not break conformant SDKs.
- **The endpoint/version could change.** Transport is isolated in two requirements (endpoint+auth,
  headers) so a version bump is a contained edit.

## Open Questions

- Compression parity: is gzip-only (posthog-node) acceptable indefinitely, or should broader codec
  support become a parity target? (Recommendation above: acceptable; gzip is the baseline.)
- `$ai_*` carve-out: normative cross-SDK requirement, or posthog-node-local until an AI v1 path
  exists? (Recommendation above: bind only SDKs that emit `$ai_*` today.)
- Should a `capture-v1` acceptance `.feature` file be added? The product-pipeline precedents
  (`logs`, `traces`) ship **no** acceptance feature file, so this change follows suit; the existing
  cross-SDK `capture_v1` compliance suite already exercises the transport.
