# YAML parity suite v1

This source-traceable migration suite preserves the harness's 157 YAML cases at
`029a94a3861c79f5e99d656b03648ba903eb6e7e`. The current slices contain five AI cases, 98 analytics-v1 cases 33 legacy capture cases, 17 remote flag cases and four local cases: **157/157 controlled-executed**.
The frozen 728-case canonical inventory, its IDs, frozen base catalog and published corpora are
separate and unchanged. The effective execution API includes the approved capture, native flag-semantics and local-evaluation amendments. Native SDK and package/cutover gates remain.

- `capture-ai.feature`: five AI cases with typed public-call inputs and wire assertions.
- `capture-analytics-v1.feature`: 18 endpoint, header, envelope and event-wire cases.
- `capture-analytics-v1-batching.feature`: 22 property, batching, freshness and UUID cases.
- `capture-analytics-v1-retry.feature`: 29 retry identity, metadata, status, timing and mock-response cases.
- `capture-analytics-v1-outcomes.feature`: 18 partial-result, terminal, and default-omission cases.
- `capture-legacy.feature`: 32 legacy capture format, retry, identity and flush cases.
- `capture-amendment-v1.feature`: 12 formerly blocked capture cases with approved inputs.
- `remote-flags-v1.feature`: 17 native server getter/lifecycle cases with approved setup reconciliation.
- `local-evaluation-v1.feature`: four local origins, 119 public getter evaluations and eight fresh authenticated reload barriers.
- `approved-amendments.json`: current resolutions and deliberate per-case input mappings.
- `blocked-cases.json`: historical pre-amendment assessment with exact original inputs,
  ordered assertions and independent API/encoding requirements; preserved as provenance.
- `remote-flag-blocked-cases.json`: 17 additional exact-source remote flag blockers;
  nonexecutable historical assessment, resolved by separate amended executable rows.
- [Remote/local flag contract gate](remote-flags-contract-gap.md): direct-remote input,
  startup/cache default conflicts and the bounded read-only local readiness assessment.
- `cases.json`: one migration identity per source YAML identity, original filters,
  translated source location, API-family candidate operations, independent SDK
  requirements, and evidence references.
- `manifest.json`: feature and ledger SHA-256 digests plus pinned legacy provenance.

The harness checks feature and ledger digests and one-to-one case mapping before
execution. This suite uses revision identity `yaml-parity-v1`; substantive published
expectation changes need a new suite version. During local development, update its
manifest with intentional source/ledger changes. The runtime reads Gherkin and JSON
metadata, never YAML actions. Original YAML remains intact.

## Selection

Run/discover with `--migration-suite`, or name a migration feature with `--feature`.
Default canonical discovery and `--all-features` still refer only to the frozen
canonical inventory. `--case-id` explicitly requests a migration identity and leaves
other cases in the report as `not_selected`.

Automatic selection has two levels:

1. The adapter's public `supported_routes` select API-family candidates: `/capture_ai`
   for four AI cases and `/capture` for the ordinary-capture no-reroute case and all
   98 executable analytics-v1 cases and all 33 legacy capture cases.
2. The selected profile's optional `sdk_capabilities` independently declares
   `capture_ai_v0` for the five AI cases or `capture_v1` for the 98 executable analytics-v1 cases,
   or `capture_v0` for the 33 legacy capture cases, preserving each source suite's API requirement.
   The eight format-specific legacy cases also require the declared batch or event
   API contract described below; the 25 generic legacy cases are shared.

`capture_ai_v0` declares AI v0 API delivery, not analytics-v1 or a server runtime.
The feature's `@both` reflects operation-based cross-runtime applicability; original
`server` filters remain recorded as provenance, not a wire-format inference.
`@capture-ai` names the behavior area and `@api_capture_ai_v0` records the version.
The ledger is the executable selection metadata. Tags alone do not create an
undeclared SDK claim. No other feature taxonomy is introduced in this slice.

`capture_v1` declares analytics-v1 delivery through ordinary `/capture` and
`/i/v1/analytics/events`; it does not imply a server runtime or reconfigure the
selected profile. A concrete claim with missing `/capture` reports
`unsupported_binding`. An adapter that declares v1 support but actually sends legacy
traffic fails the relevant wire assertions; the harness does not switch its API.

An absent candidate operation without a relevant claim is `not_selected`. A concrete
AI-v0 claim without `/capture_ai` instead yields `unsupported_binding`; that claim
alone does not select the ordinary `/capture` case. Missing capability metadata is
reported as not declared, not interpreted as support. Explicit case requests keep
missing operations or SDK capabilities visible as `unsupported_binding`. Supporting
`/setup` and `/flush` are required after selection. `storage.empty.v1` is a harness
fixture requirement, not an SDK feature; its absence is `blocked_fixture`.

The ordinary-capture case accepts **either** `/batch` or `/i/v1/analytics/events`,
independently of runtime. It rejects the AI endpoint. The bounded native flag SDK-type applicability is documented below; no missing
binding is classified as `not_applicable`.

## Observation and return semantics

The first AI/wire slices retain `phc_test_key` and `flush_at: 1`. Capture arguments retain the
source types, supplied UUID and timestamp offset verbatim. No clock, scheduler,
retry or preload override is injected. Flush is a separate public invocation.
Assertions read the complete mock-server recorded-request collection since the
case reset, including initialization traffic, not a flush-only window. As in the
legacy executor, path comparisons ignore trailing slashes. The timestamp assertion
checks every event in the first request; UUID/property assertions use its first
event. UTC timestamp equality preserves fractional precision, while the
`timestamp_like` property is compared as an unchanged string.

The old adapter `{success:true,uuid}` envelope is not an SDK API. Under the frozen
v2 catalog, `/capture_ai` returns a native string or null. Admission assertions
require a nonempty returned UUID, supplied-UUID assertions check the exact return,
and correspondence assertions compare that retained return to the received UUID
after flush. A null return fails admission. No adapter supplies expected values or
synthetic success fields.

## Evidence levels

157 translations and 157 controlled executions are evidenced in
`harness/docs/harness-v2-yaml-parity-evidence.md` (sibling repository). Controlled
server, browser, mobile and edge profiles exercise the same public-call transport.
AI cases accept both analytics profiles; the analytics-v1 cases run on declared v1
profiles, with a legacy-wire inconsistency tested as a failure. They validate the harness, not any real SDK.
Native SDK evidence is empty. No entries in the frozen 518-entry assertion crosswalk
are marked resolved by this separate ledger.

## Analytics-v1 observation scope

These 18 cases correspond exactly to `targets_v1_endpoint` through
`distinct_id_at_root_not_properties` in the pinned YAML, stopping before custom
properties. Every case retains `/setup`, `/capture`, `/flush` in that order, with
`flush_at: 1`; no protocol, clock, retry, compression or other default is injected.
The timestamp override and timestamp-like property are distinct typed arguments.

Path checks observe every accumulated request and ignore trailing slashes; the two
endpoint cases also require exactly one request. They do not assert HTTP method.
Headers and body assertions observe only request zero. Header patterns retain
`^application/json`, `^.+/.+$` and `^.+$`; attempt is parsed as an integer, UUIDs
are parseable UUIDs rather than a specific version, and bearer scheme is
case-insensitive with trimmed token whitespace after the required space.

The envelope check requires canonical UTC `created_at` and a nonempty batch array,
not an exhaustive schema. Omission checks inspect only root `api_key`, `token` or
`sent_at`; empty/non-JSON bodies pass those omission checks as in the source. Event
required-field presence and timestamp checks inspect all events in the first
request. UUID, identity type and root/property placement inspect its first event.
Field presence alone does not validate type or non-nullness. Identity placement
rejects the key in object properties but does not require properties to be an object.
Scenario names describe those assertions rather than stronger source descriptions.


## Analytics-v1 properties and batching observation scope

The next 22 cases cover `custom_properties_preserved` through
`different_events_same_content_different_uuids`, stopping before retries. The setup
thresholds are exactly 1, 3, 4 or 10 where supplied. Empty flush and the two final
UUID cases omit additional setup configuration; the binding supplies only the
source token and mock host. SDK defaults remain native. Repeated captures are
sequential, with zero-based formatting only of top-level string inputs; nested
objects, arrays, numbers and booleans stay typed and unchanged.

`$set`, `$set_once` and `$groups` are ordinary capture properties, not profile API
calls. Their assertions require an object on the first received event, not exact
object contents. Scalar property assertions preserve the source's value equality
(including boolean/numeric equality), while the public inputs retain JSON types.
Batch field-presence and UTC timestamp checks inspect all events of request zero;
UUID validity, properties and identity checks inspect only its first event.
Parsed-event counts inspect request zero, not every request or a schema assertion.

All-UUID uniqueness collects present fields across every accumulated request and
can pass with missing UUIDs or no events. The identical-content case requires at
least two collected UUIDs and compares only the first two; it does not validate
every collected value as a UUID. These are parity limits, not complete protocol
coverage.

Threshold delivery has no public `/flush` call: three sequential captures are
followed by a full real one-second observation and a request-count lower bound of
one. Empty flush checks the complete accumulated collection, including startup
traffic. `created_at` must be canonical UTC and within an absolute five seconds of
the real current wall clock; this does not prove the exact batch-assembly instant.
Neither scenario installs a fixed clock or substitutes a flush-only observation.

Migration preflight checks declared candidate routes even when an individual case
(such as empty flush) does not invoke capture. A concrete `capture_v1` claim without
`/capture` remains `unsupported_binding` before fixture allocation. The normal
empty-flush case invokes only `/setup` and `/flush`.


## Analytics-v1 retry and mock-response observation scope

Cases 41–69 cover `preserves_uuid_on_retry` through `max_retries_respected`, stopping
before `handles_200_full_success`. All source response sequences, literal error
bodies, supplied thresholds, `max_retries: 3`, ordered public calls and real waits
remain explicit. There are 100 public calls and 109 seconds of post-call observation
across these 29 cases; native completion time is additional. Unspecified settings
remain omitted. The public catalog already supports `config.max_retries`.

UUID and timestamp preservation compare only the first two filtered event lists,
including present null values and ignoring missing fields. Batch duplicate checks
ignore missing/falsey UUIDs but inspect every received batch. Retry attempts and
stable request IDs inspect all recorded requests; different request IDs/timestamps
compare only requests zero and one, without imposing UUID/date syntax checks.

A successful retry means **any recorded 200**, not necessarily the last response.
Terminal-status counts exclude paths containing `/flags`; other request counts use
the entire recorded collection. The backoff case checks only the first delay
**≥100ms**, not exponential growth. `Retry-After: "3"` checks the first delay
**≥2500ms** after an **8000ms** wait. Exactly four requests must be observed after
**15000ms** with three configured retries. No queue retention/deletion is asserted.

Six response-format cases and two error-header cases explicitly inspect
**mock-authored responses**, not SDK interpretation of those responses. Results
shape means an object, not validated UUID keys; result equality permits the source's
string/object entries and an empty object. Header checks retain source casing and
falsey-value handling. The ledger marks these cases with `mock_authored_response`
evidence. Actual public calls still produce the requests and the server's replies.
These earlier assertions alone do not establish partial-result pruning or complete per-event acknowledgement.

The controlled engine owns buffering, request identities, HTTP status decisions and
bounded retry scheduling. Bindings neither retry nor manufacture observations.
Diagnostics retain each recorded request timestamp, request headers/events, and its
associated response status/headers/body. The real waits are not accelerated. Native
SDK conformance and the remaining 65 YAML cases remain pending; all 518 original
crosswalk entries remain unresolved.


## Historical analytics-v1 outcomes increment and pre-amendment gaps

The bounded cases 70–98 add **18 executable cases**: 70–82, 87, 89, 94, 97–98.
The other **11 remain blocked**, not translated or credited as harness-ready.
At that increment the total was **92/157**. The subsequent legacy capture slice
below brings the total to **124/157**, with 12 blocked and 21 unstarted. See the sibling harness evidence
for source IDs, receipts, and the current review gate.

The partial-response cases preserve ordered mock outcome fixtures, mapped by the
mock to the UUIDs actually sent. Bindings observe the first response and second
request: eligible UUIDs must remain, known terminal UUIDs must disappear. Unknown
extra UUIDs and duplicates are not comprehensively rejected. The mixed-pruning
case separately counts the **last** batch. Attempts and stable request IDs inspect
all requests; Retry-After checks only the first delay (≥2500ms). The 18 cases make
70 public calls and retain all 54 seconds of real post-call waits.

The controlled engine reads actual HTTP response bytes, prunes its actual buffer
by returned UUID outcomes, and schedules retries itself. A real-HTTP component
check also verifies retained buffer entries between flushes. This validates the
harness double, not native SDK handling. Earlier response-format checks still
establish mock-authored response facts only. No malformed-result policy is added.

Disabled compression maps the source `enable_compression:false` losslessly to
`/setup.config.compression:"none"`. Case 87 checks header absence on request zero.
No enabled algorithm is selected by the harness. Historical migration uses the
existing setup boolean and is observed at batch-body root; its default remains
omitted. Unset options are checked independently on the first event's root
`options` object, never substituted with properties.

The frozen catalog cannot express the remaining inputs:

- Cases 83–86 and 88 supply only `enable_compression:true`; the catalog instead
  takes an algorithm enum. Substituting gzip/deflate/br/zstd would change SDK choice
  into caller choice. Their `encoding_gzip/deflate/br/zstd` requirements remain
  independent feature declarations in the blocker ledger, not runtime predicates
  or fixture capabilities. The source enabled-header checks match **any request**;
  only gzip has a decompression assertion and the pinned mock only decodes gzip.
  None of these five cases has an execution or native-decompression claim.
- Cases 90–93 and 95 require supplied `EventArgs.options` controls:
  `cookieless_mode`, `disable_skew_correction`, `process_person_profile`, and
  `product_tour_id`. No such argument exists. Properties/person_profiles are not
  substitutes for event-root options.
- Case 96 supplies initialization-level `disable_geoip`; the catalog only exposes
  a per-event argument. Moving the setting to captures would change the source.

`blocked-cases.json` records exact original inputs/ordered assertions and proposed
additive seams for later contract review. These are provenance records, not a
runtime action DSL, executable Gherkin, or selectable migration IDs. Explicitly
selecting a ledger-only blocked identity is an invalid selector, not a pass.
The catalog, schemas, defaults, canonical 728-case inventory and all 518 unresolved
crosswalk rows remain untouched.


## Historical legacy capture increment: API contracts and observation scopes

All 33 `contracts/capture_tests.yaml` cases are accounted for: **32 executable**
and **one blocked** (`sends_gzip_when_enabled`). They require `/capture` as their
candidate public operation and independently declared `capture_v0`. The `@both`
annotation reflects cross-runtime applicability, not any wire-format inference.
A concrete `capture_v0` claim with missing `/capture` remains `unsupported_binding`
for otherwise matching cases. Explicit selectors expose undeclared API/variant
requirements as `unsupported_binding`; missing storage fixtures are `blocked_fixture`.

The pinned harness `README.md:41–49` and `ADAPTER_GUIDE.md:48–63` document two
legacy capture contracts: `{api_key,batch}` with root event identity and event
payloads with properties identity. They explicitly distinguish these from platform:
a mobile SDK may use the batch API. Pinned `mock_server/state.py:269–303` accepts
batch objects, event arrays, data-wrapped arrays and single events; the capture
endpoint handler accepts both batch and event routes. Existing profile `protocol`
metadata distinguishes legacy/v1 only, not these two legacy formats.

Two independent SDK API declarations replace the old role-as-wire proxies:

| Declaration (in addition to `capture_v0`) | Complete grouped obligations |
| --- | --- |
| `capture_v0_batch` | `event_has_required_fields`, `distinct_id_is_string`, `token_is_present`, `uses_proper_batch_structure`, `multiple_events_batched_together` |
| `capture_v0_event` | `event_has_required_fields_client`, `distinct_id_is_string_client`, `token_is_present_client` |

These are whole versioned API contract variants, not per-field opt-outs. A profile
that selects a variant must satisfy its whole applicable group. Runtime, identity,
products, host fixtures and `protocol` do not supply a missing declaration or choose
the actual SDK wire behavior. The suite adds no literal endpoint assertions where
none existed. Original `sdk_types` remain provenance in the ledger, not platform
gates. Controlled mobile-batch and server-event tests exercise the grouped checks;
inconsistent claims fail their wire assertions rather than being silently excluded.

- Root/properties identity checks inspect the first event of request zero and compare
  the exact supplied string. They do not forbid an extra copy in the other location.
- The batch token helper accepts any event's root `token` in request zero, or body
  root `api_key`/`token`. It does not accept event-root `api_key` or nested tokens.
  The event token helper scans all events of request zero and uses first-truthy
  precedence: event `token`, event `api_key`, properties `token`, properties `api_key`.
  A wrong truthy earlier field shadows a matching later field. Body auth and later
  requests cannot rescue that assertion.
- UUID and timestamp presence are first-event key-presence checks, allowing null;
  separate UUID validity checks parse the first event UUID without requiring v7.
  `$lib` presence does not assert `$lib_version`, string type or non-nullness.
  Timestamp conversion inspects all events in request zero; its property remains
  the original offset string. Scalar property inputs stay typed and comparisons
  retain source value equality, including boolean/number equality.
- Batch checks require an array (including empty), and optionally presence of root
  `api_key` without validating its value. The five-capture case requires one request
  and a batch array, not exactly five delivered events. Empty flush counts the
  complete accumulated collection, including initialization requests.
- Retry fixtures retain 408/500/502/503/504, terminal 400/401/403/413, and 429 with
  `Retry-After: "3"`. All counts include `/flags` traffic. Success means any 200.
  The first delay is ≥2500ms for Retry-After, or ≥100ms for backoff; exponential
  growth is not proved. Configured three retries require exactly four requests.
  All **88 seconds** of original waits remain; native-call completion is additional.
- Collected UUID uniqueness ignores absent fields and can pass without UUIDs.
  Retry preservation compares only the first two filtered UUID/timestamp lists,
  including null. In-batch duplicate checks ignore missing/falsey UUIDs but inspect
  all received requests. The identical-content pair compares only two collected UUIDs.

The engine owns the queue, identity generation, HTTP response handling and retry
scheduling. The binder invokes public methods once and does not inject SDK defaults.
The positive controls make **110 public calls and 48 actual HTTP requests** for all
32 cases; API setup supplies only source settings, token and mock host.

The compression blocker preserves its sole `enable_compression:true` input and
any-request gzip-header assertion. `capture_v0`/`encoding_gzip` declarations do not
supply a representable enabled algorithm choice. No frozen catalog or schema was
amended and no explicit gzip input substituted. Blocker rows are nonexecutable
provenance, not selectable cases. Native SDK coverage and YAML retirement remain
pending; all 518 original crosswalk rows are still unresolved.


## Approved capture-amendment-v1

The current effective resolution adds all 12 historical capture blockers. Read
[the shared amendment](../../contracts/v2/capture-amendment-v1.md) for the typed
API and negotiated effective identity. Original blocker rows, source inputs,
source IDs and prior 124 executable rows remain unchanged. The new rows in
`cases.json` reference the amendment and retain empty native SDK evidence.

Six enabled-compression cases deliberately map `enable_compression:true` to
`config.compression` with the required gzip/deflate/br/zstd algorithm. This is an
approved input change from native algorithm choice, not byte-identical source
invocation parity. The disabled case still maps false to `none`. Profiles may
declare multiple encodings; each case selects its explicit algorithm, independently
of runtime and declared API family. Source header checks search any request;
the gzip decompression case checks only request zero for nonempty encoding,
decompressed text and parsed events. The other encodings retain header-only
source assertions. Supplemental controlled-engine roundtrips prove real compressed
HTTP bytes, not a stronger migrated source assertion or native SDK support.

Five supplied-option cases preserve event-root options and false values; assertions
still inspect only the first event of the first request, even in the three-event
batch. The GeoIP case supplies the initialization-wide boolean and observes
`$geoip_disable` in first-event properties. Omission retains native defaults.

The controlled tests require Python gzip/zlib plus `brotli` and `zstd` executables
on PATH for their real native encoders/decoders. They add no SDK dependency. These
are controlled test-engine prerequisites, not selection inference from installed
encoders. The engine owns enrichment, actual encoding and HTTP delivery; adapters
only invoke its methods.

Next: implement the 17 remote cases against normal server/client behavior, with
server reads making remote requests when no local evaluation/cache applies and
client reads using cache or awaiting native loading. Reconcile the existing
`/on_feature_flags` callback's delivered values/error semantics first. Four local
cases still need genuine definitions-loader/provenance seams. Neither flag work
nor SDK integration is part of this capture slice. All 518 frozen assertion
crosswalk entries remain unresolved.

## Remote flag amendment: 17 origins

See [native flag semantics](../../contracts/v2/flag-semantics-v1.md) and the sibling
`harness/docs/harness-v2-remote-flags-evidence.md`. All 17 rows use ordinary
`/get_feature_flag` and independent `flags_v2` selection, with genuine `@server`
context, selected by explicit `ExecutionProfile.sdk_type`, not runtime. Missing
SDK type is `blocked_contract`; opposite type is `not_applicable`. Empty storage
and no installed local definitions/results are preconditions;
startup/capture silence are assertions. Only the repeated-getter case requires
`flags_getter_remote_uncached`. That declaration cannot opt out of lifecycle tests.

Sixteen `force_remote:true` source inputs are intentionally removed, preserving
all other types and omissions. No preload/TTL override is inserted. This is an
approved setup amendment, not byte-identical parity. The original blocker ledger
and source YAML remain unchanged. `approved-amendments.json` and each new row record
the per-call removals. Caching server single-getter cases remain eligible.

First-flags-body token/api_key precedence, nested device property, omitted versus
empty groups, omitted versus false GeoIP, singleton keys, v=2 and /decide exclusion
retain their exact source scopes. Authorization absence observes ordinary request
zero. Counts match paths containing /flags, across initialization through the
actual call/flush boundary. Field/result equality retains Python equality.
502/504 then 200 means two requests and true from the public getter, with no source
retry-delay assertion. Named event assertions observe all non-/flags requests;
properties are checked on the first matching named event. Tracking must be received
after public flush. Endpoint defaults overlay parsed successful fixture objects
before JSON serialization reaches the native HTTP parser.

The three existing canonical callback scenarios are separately bound, retaining
their IDs and bytes. Supplementary client cache/load comparisons are not additional
YAML origins. Native SDK/existing adapter evidence remains empty; all 518 frozen
crosswalk rows remain unresolved. Four local reload/provenance cases are pending.


## Local evaluation amendment: final four origins

See [native local evaluation](../../contracts/v2/local-evaluation-v1.md) and sibling
`harness/docs/harness-v2-local-parity-evidence.md` for the current disposition.
The four local rows use `/get_feature_flag` plus the independent SDK declaration
`feature_flags_local_evaluation_v1`. The original source has no SDK-type filter;
`@both` does not infer client/server type or select a wire API. Supporting public
reload/readiness operations are required; declared local capability with a missing
getter is an unsupported binding, and absent provenance instrumentation is a
blocked fixture. No fixture declaration creates an SDK capability.

All definitions, person/group/cohort inputs, omissions and JSON types remain
explicit data. `personal_api_key` maps losslessly to `config.secret_key`; native
startup/cache defaults remain unchanged. All 119 getter results must be conclusive
boolean/string values observed locally under the exact invocation, with no remote
flag traffic during the complete initialization/reload/getter window. Eight
5000ms barriers invoke the real public reload and readiness APIs and require new
authenticated definitions HTTP 200. Both definition paths are valid. The combined
single-instance sequence 1→2→1→2→omitted returns true,false,true,false,true.

This completes controlled migration credit for 157 origins, not native SDK
conformance or all 728 canonical cases. The existing 518 crosswalk entries remain
unresolved; historical blocker assessments above are preserved with current
amendment dispositions recorded separately.
