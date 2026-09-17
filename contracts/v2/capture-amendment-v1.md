# Capture amendment v1

This approved additive amendment applies on top of the byte-identical phase-1
catalog and decisions. `inputs/capture-amendment-v1.ts` is its typed source;
`inputs/provenance.json` pins its identity and SHA-256. It adds no operation.

| Consumer | Added optional input | Meaning |
| --- | --- | --- |
| `/setup.config` | `disable_geoip: boolean` | Initialization-wide GeoIP control. |
| `/capture` | `options: CaptureOptions` | Analytics-v1 controls serialized in the event-root `options` object, not ordinary properties. |
| `CaptureOptions` | `cookieless_mode`, `disable_skew_correction`, `process_person_profile`: boolean; `product_tour_id`: string | Individually optional native event controls. |

Omission leaves native defaults intact. Explicit false and empty strings remain
supplied values; there is no schema default insertion. The setup field is an
initialization input, not a new live `/set_config` field. `CaptureArgs` extends the
base event arguments for `/capture`; other `EventArgs` consumers retain their
base signatures. The transport still delivers representable negative inputs to
the SDK. Missing native parameters are `unsupported_binding`, not discarded
options or fabricated SDK behavior.

## Effective catalog identity and compatibility

The transport envelope remains `2.0.0` / `http-json-v2`. Its existing
`catalog_sha256` negotiation/report field now identifies the **effective** catalog.
Generation and consumers compute SHA-256 over UTF-8 text containing:

1. The lowercase base catalog SHA-256, then LF.
2. For each amendment in provenance order, `<id>:<lowercase SHA-256>`, then LF.

There is a final LF; no JSON whitespace or file path participates in the digest.
For this selection the effective digest is
`7b2e0eddfb9c72ac80c938de70bf4025eb58fc1d655d380df42cc7544734f145`.
Generated operations/configuration metadata expose `base_catalog_sha256` and the
ordered amendment identities, source paths and digests. Generated types and
protocol schemas use the effective digest. The harness verifies the pinned base
and amendment bytes and recomputes the identity before use.

A peer advertising only the historical base identity is incompatible:
`catalog_mismatch` must precede fixture allocation. The base remains provenance,
not a fallback negotiation identity. Historical reports retain their original
identity; the effective contract does not reinterpret them. Regeneration first
cross-checks the frozen 180 routes / 143 configuration paths, then applies the
amendment; the effective configuration has 144 paths. Canonical IDs and phase-1
inventory are unchanged.

## Migration input amendment

`/setup.config.compression` already selects `none`, `gzip`, `deflate`, `br` or
`zstd`. The six previously blocked enabled-compression source cases now explicitly
select the encoding named by their independent encoding requirement. This replaces
source SDK algorithm choice with caller algorithm choice: **approved input
amendment, not byte-identical invocation parity**. The existing disabled case
continues to select `none`. All source wire assertions remain unchanged.

The migration ledger records the mapping per case and retains original typed
inputs in its historical blocker ledger. Per-encoding SDK capability declarations
remain independent from runtime, client/server role and host fixture support.

The next flag slice will reconcile `/on_feature_flags` callback data/error
semantics with native loading and cache behavior. That callback contract is not
changed by this capture amendment.
