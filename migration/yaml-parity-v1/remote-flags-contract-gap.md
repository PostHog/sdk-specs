# Flag YAML parity: historical invocation assessment

**Current disposition: all 17 remote origins translated and controlled-executed
under approved flag-semantics-v1; all four local cases translated and controlled-executed
under approved local-evaluation-v1.** Migration total: **157/157**, without native SDK evidence.

The [local amendment](../../contracts/v2/local-evaluation-v1.md) resolves the
historical loader/provenance gaps below through the existing native public reload,
public readiness, fresh authenticated HTTP 200 and bounded native per-call observation.
No historical blocker rows or source inputs are erased.

The analysis below and `remote-flag-blocked-cases.json` are historical. The approved
redesign removes source harness forcing inputs, uses ordinary native getters,
reconciles callback data/errors, and separates genuine SDK-type context from wire
API selection. See [the effective amendment](../../contracts/v2/flag-semantics-v1.md)
and `approved-amendments.json` for current decisions/dispositions. Historical
force-control proposals below are not current API requirements.

## Historical source assessment

Sources: harness `029a94a3861c79f5e99d656b03648ba903eb6e7e`, specs
`9cb330e3bac8868f39cc7dd665e42817285c9493`, frozen public catalog SHA-256
`ac8165c607ea0d15e924d3984e4da49d68cdcb77d1d2fe8de18da142603870e3`.
Action/client/mock references below mean `git show HEAD:<path>` in the harness,
not the dirty working actions. The manifest pins the relevant remote sources.

## Exact remote contradictions

Paths in this section are relative to `contracts/v2/inputs/public-rpc-catalog.md`.

- **15 cases, 16 getter calls:** `Evaluation` / `FlagRead` / `ValueRead`
  (175–193) cannot represent source `force_remote:true`. The generated getter
  argument schema rejects it. `only_evaluate_locally:false` permits fallback,
  not forced remote evaluation (511). `fresh:true` returns fallback immediately
  without fetching when no eligible remote result exists (571). Neither is a
  lossless translation. Request-scoped getter wording (569) does not add an input.
- **Two lifecycle cases** (`no_flags_request_on_init_alone`, line 254;
  `no_flags_request_on_normal_capture`, 265): init omits preload configuration,
  while the target defaults `preload_feature_flags=true` (510). Setup completes
  local initialization, not remote readiness (633). Observing before a scheduled
  preload happens would be a race, not faithful evidence of the source silence
  policy. Capture-through-flush retains the full startup observation window.
- **Repeated getter case** (283): the source requires two identical sequential
  forced-remote calls to make two requests, without a cache override. Target
  evaluated-result TTL is 300000ms (512). An implementation cannot silently set
  TTL to zero or claim the old non-caching profile is the canonical default.

Startup/default policy also needs resolution before executing the 15 getter cases:
extra startup requests can consume raw response fixtures or contaminate first-
request/count assertions. The ledger records the direct blocker per case rather
than counting these overlapping concerns as additional cases.

No public-call bindings, controlled engines or Gherkin executable identities are
added for these blockers. Their proposed IDs are provenance, not selectors. The
manifest's `remote_flag_blockers` is nonexecutable metadata (as with the prior
blocker ledger); runtime discovery does not execute or preflight these rows.

## Selection after a contract decision

The public `/get_feature_flag` operation is the candidate seam, including its
initialization/capture lifecycle family; supporting `/setup`, `/capture`, `/flush`
remain real prerequisites where called. An independent, grouped direct-remote
API declaration must describe the resolved behavior. Its name and semantics are
pending approval, so blocker rows have empty `sdk_capabilities` and explicit
`selection_status:pending_contract_decision`, not a claim of universal support.
Original server gates remain provenance. Runtime, role, identity, products and
fixture availability do not establish this API. No per-header/field opt-outs are
proposed. Explicit selection or an actual API claim must retain missing public
operations as gaps; missing host controls are separate fixture blockers.

## Obligations retained for the eventual remote translation

`actions.py:235–245` and `sdk_adapter/client.py:25–46` preserve omitted optionals.
The source has no explicit wait actions; its actual init/getter/flush completion
boundaries remain the windows, with no added polling or shortened delays.

- First flags body uses paths **containing `/flags`**, not an exact route/method
  assertion (`actions.py:939–998`). Token accepts top-level `api_key` only when
  `token` is absent. Nested `person_properties.$device_id` stays a property,
  not the separate device-bucketing argument. Empty groups versus omitted groups,
  false GeoIP versus omitted GeoIP, and singleton requested keys stay distinct.
- Query assertion preserves `v="2"`; forbidden paths normalize trailing slashes
  and exclude `/decide` (`1227–1234`). Header absence observes the first ordinary
  recorded request, not all flags requests (`1748–1756`). No stronger method/path
  contract follows from descriptive prose.
- Count assertions observe the full request collection since init. Two getters
  are two public invocations, not retained snapshot reads. The resulting legacy
  HTTP response, including endpoint defaults overlaid by the configured
  `featureFlags` object, must reach the native parser and public getter return.
  HTTP 502/504 followed by 200 must yield exactly two requests and `true` returned;
  source assertions do not require the canonical 300ms retry-delay floor.
- `$feature_flag_called` is received capture traffic after public flush, with both
  matching properties, not an adapter-maintained enqueue count. Native engine
  code must own parsing, retries, tracking and actual buffered delivery.
- Field/result comparisons retain Python equality, including bool/numeric equality
  where the helper uses it; typed input preservation does not strengthen equality.

Pinned `endpoints/decide.py` actually defines `FlagsEndpoint` at `/flags` and
`/flags/`; there is no separate `endpoints/flags.py` at this revision. State/server
record real HTTP and serve ordered configured responses. The pinned server parses
fixture body strings as JSON; successful object responses overlay the endpoint's
defaults, including `featureFlagPayloads:{}` and
`errorsWhileComputingFlags:false`, before `jsonify` serializes the result
(`mock_server/server.py:50–66`, `mock_server/endpoints/decide.py:22–27`). Preserve
the exact fixture strings as source inputs and this resulting HTTP representation
as the native parser input; the strings are not sent verbatim. The existing
snapshot/cached-getter fixtures are not proof of this direct remote path.

## Historical bounded read-only local assessment

Source IDs have prefix
`yaml:029a94a:feature_flags_local_evaluation:versioned_boolean_matching:`.

| Source suffix | YAML line | Getters | Fresh reloads |
| --- | ---: | ---: | ---: |
| `matching_version_missing` | 8 | 38 | 1 |
| `matching_version_1` | 995 | 38 | 1 |
| `matching_version_2` | 1433 | 38 | 1 |
| `version_only_reload_1_2_1_2_missing` | 1871 | 5 | 5 |

These four cases remain unstarted. All 119 supplied local-only getter inputs fit
`ValueRead`; no `force_remote` input occurs here. The setup personal API key has
a plausible lossless `SetupConfig.secret_key` name mapping, enabling local
execution under catalog 511. That does **not** solve the following shared gaps:

1. **Fresh definitions reload operation:** source helper `actions.py:270–282`
   invokes `reload_feature_flag_definitions(timeout_ms=5000)`, requires
   `success:true` and `ready:true`, and witnesses a **new** HTTP 200 definitions
   fetch after the call starts. There is no such public operation in the 180-route
   catalog. `/reload_feature_flags` (671) refreshes evaluations, not definitions;
   its no-argument completion callback includes failed/skipped attempts (580).
   Waiting for polling, rereading old readiness, or installing definitions directly
   cannot replace the eight explicit reload barriers.
2. **Local provenance observation:** each getter requires a bool/string value,
   `success is True`, `locally_evaluated is True`, and zero accumulated `/flags`
   traffic (`actions.py:247–259`). `/get_feature_flag` returns plain JSON, with
   no local provenance. `/get_feature_flag_result` also lacks local provenance
   and is a different invocation. A binding must not fabricate the old adapter
   envelope. The existing activity fixture counts cumulative local attempts;
   it does not attest a particular getter's conclusive result provenance.
3. **Startup/default policy:** every case omits preload overrides and forbids
   remote evaluation throughout initialization and reloads. The same canonical
   preload default needs a resolved local-only profile interpretation; call-level
   `only_evaluate_locally:true` alone does not govern startup.

The native-component `flags.definitions.install.v1` fixture explicitly disclaims
HTTP loading/readiness/refresh proof (`contracts/v2/flags-state-fixture-v1.md`).
Its controlled consumer supports constant definitions, not the full versioned
comparison loader in these cases. No local engine was changed or executed.

The mock definitions endpoint requires project-token query authentication and
Bearer personal-key authentication (`mock_server/state.py:78–104`), accepts both
modern and legacy routes (`server.py:84–94`), and records definition requests
separately from ordinary flags/capture traffic. Preserve that distinction, all
119 values, eight five-second reload deadlines, and same-instance sequence
`1 → 2 → 1 → 2 → omitted`. Missing version resets legacy behavior; do not default
it to 2. No corpus/vector DSL or Rules-v2 corpus execution is implied.

## Minimal decision proposals — not approved contract changes

1. Specify an additive direct-remote getter control that faithfully represents
   `force_remote:true`, including whether evaluated-result cache is bypassed;
   the repeated-call case requires two requests. Do not repurpose `fresh`.
2. Separate source migration startup/cache defaults from canonical defaults via
   an explicitly approved, independently declared API contract, or deliberately
   amend canonical policy through its normal specification workflow. Adding a
   getter parameter alone cannot resolve init-only silence. Existing schema-valid
   preload/TTL overrides would change the original inputs and require an explicit
   semantic replacement, not parity credit.
3. For local migration, specify a genuine definitions-reload public operation
   with native bounded completion and observable fresh authenticated fetch; do
   not rename evaluated reload or native state installation as this operation.
4. Define native per-call local provenance evidence (a genuine observation fixture
   or approved public result contract). Keep legacy adapter success/readiness
   wrappers distinct from native SDK return values.

These are user-level decisions between faithful migration and the frozen target,
not implementation choices. Keep canonical 728 cases, all 518 unresolved crosswalk
rows, catalog, schemas and published corpora unchanged until that decision.
