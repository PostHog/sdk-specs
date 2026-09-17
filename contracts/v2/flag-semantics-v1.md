# Native feature-flags semantics v1

This approved overlay reconciles flag notifications and ordinary native flag
startup/getter/cache behavior. It is pinned as `inputs/flag-semantics-v1.ts` in
provenance and participates, after capture-amendment-v1, in the effective negotiated
catalog identity. Frozen catalog/decisions, all 180 operation argument/result shapes,
and the capture amendment input remain unchanged.

## Native callback, not remote-success readiness

`/on_feature_flags` uses `on_feature_flags`, distinct from `readiness`:

- Enabled flag keys (`string[]`).
- Native flag values/variants (`Record<string, boolean | string>`).
- Optional loading context (`{ errorsLoading?: boolean }`).

The callback observes native data directly; bindings neither read a getter to fill
it nor replay it after the owning SDK callback has returned. Native immediate
registration may supply only two arguments. Later notifications may supply a
context with absent `errorsLoading`, explicit false, or true. Callback arguments
are transported individually as Outcomes, so an actual undefined argument remains
`kind:undefined`, not false or null. Undefined object properties project to absent
JSON properties. The target tuple is a two-/three-item union; it does not add a
third argument to a native two-argument callback.

Listeners can fire on native changes and loading errors, not just successful
remote loads. Cached/bootstrap availability and error notifications are **not**
evidence of a fresh successful HTTP response. Actual subscription removal is
idempotent and suppresses future native callbacks, rather than hiding observations.
The genuine no-argument flush/reload completion signature remains `readiness`.
This overrides the frozen base's no-argument feature-flags notification policy;
it does not change no-argument completion callbacks for other operations.

Read-only native source assessment: posthog-js checkout HEAD
`dbbb58e286db3762673f71995a8aeea89aa44123`,
`packages/browser/src/posthog-featureflags.ts:1524–1539,1634–1664` and
`packages/types/src/feature-flags.ts` (`FeatureFlagsCallback`). The browser filters
false/empty values from both enabled-key and variant arguments, immediately calls
with two arguments when loaded, and later delivers `{errorsLoading}`. No SDK source
or native SDK test was changed/executed. The controlled engine demonstrates the
harness boundary, not conformance of that SDK checkout.

## Scoped native startup/cache policy

For ordinary flag operations, omitted initialization and cache options retain the
SDK's native behavior. The frozen universal preload=true / evaluated-result
TTL=300000 assumptions are superseded here, not silently applied to all SDKs.
Existing supported explicit native settings and `only_evaluate_locally` /
`send_event` retain their meanings. Unavailable operations/parameters/behavior
remain unsupported; an adapter must not implement its own cache or fetching policy.

Server migration cases start from empty storage, without installed local definitions
or evaluated results. Initialization/capture silence are **assertions**, not
capability prerequisites. Unsolicited flag traffic fails them. A caching server can
exercise the single-getter wire checks from empty state. Only the two-getter count
case additionally requires `flags_getter_remote_uncached`: a normal remote getter
with no local evaluation or evaluated-result caching. It says nothing about
startup or capture traffic.

`flags_v2` declares the flags v2 wire API independently of platform. The source
cases additionally retain their genuine `@server` context. The runner applies this
bounded SDK-type rule to these amended cases and the three existing `@client`
callback scenarios, not to unrelated canonical selection. The optional
`ExecutionProfile.sdk_type: "client" | "server"` is an explicit adapter declaration,
independent of runtime family, identity and wire API. Missing declarations block
selected type-specific cases as `blocked_contract`; opposite declared types are
`not_applicable`. Older profiles remain schema-valid. A server SDK running at the
edge or on desktop remains a server; a client SDK running on desktop remains a
client. No SDK type is inferred from runtime.

Client comparison evidence is separate: explicit public native reload emits the
actual loaded callback before cached reads; explicit public cache preparation
allows zero-network reads. Neither setup injects preload or TTL settings. A cached
or error callback alone never proves successful network readiness.

## Identity and source reconciliation

The effective digest is `3a0a24cdfa3a1bfd677c677b1be7f15400dbb543fcb2d29a0f84f5d6fdc4bc26`,
recorded in `generated/operations.json`; peers using the
base-only or capture-only digest reject with `catalog_mismatch` before allocation.
Generated policy metadata links this overlay explicitly. Input bytes and the
base-plus-ordered-amendment identity are verified by both generator and consumer.

The 17 remote YAML translations deliberately remove 16 source forcing inputs from
15 cases. This is an **approved test-setup amendment**, not byte-identical invocation
parity. All remaining inputs, wire assertions and source observation scopes remain.
The original ledger is immutable history; current resolutions live separately in
`migration/yaml-parity-v1/approved-amendments.json`. Four local-definition reload /
per-call provenance cases remain pending, outside this amendment's execution scope.
