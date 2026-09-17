# SDK execution contracts 2.0.0

**Phase-2 boundary, not an SDK conformance receipt.** This directory is the shared
source for RPC, fixture and report shapes. It contains no SDK binding or Gherkin
runner. Consumers include the harness core client, controlled-host transport tests,
and the phase-3 flush runner. The optional [flush fixture extension v1](flush-fixture-v1.md)
adds declared clock, storage, scheduling and native-component queue observation
controls. The optional [flags state fixture extension v1](flags-state-fixture-v1.md)
adds native loaded-definition/evaluation-cache preparation and evaluator activity
observations. The optional [concurrent invocation fixture v1](concurrent-invocation-v1.md)
coordinates overlapping public calls with individual completion receipts. These
extensions do not add SDK operations or substitute adapter state for native components. Canonical OpenSpec, acceptance features, published corpora and the frozen
phase-1 inventory are unchanged.

## Approved amendments

The effective API includes [capture-amendment-v1](capture-amendment-v1.md): optional
initialization-wide `disable_geoip` and capture-only typed event-root `options`.
The frozen source snapshots remain unchanged; generated artifacts identify the
base plus ordered checksummed amendments. Negotiation uses their effective digest, so a
base-only or capture-only adapter is rejected before any invocation. No native SDK conformance
is implied by this contract or the controlled migration receipts.

[Native flag semantics v1](flag-semantics-v1.md) adds the data-bearing
`on_feature_flags` signature and reconciles ordinary native startup/getter/cache
policy. Optional `ExecutionProfile.sdk_type` explicitly declares client/server
SDK type independently of runtime; selected type-specific cases without it are
`blocked_contract`. Older profiles remain schema-valid. No-argument flush/reload
completion remains `readiness`. Current effective
digest: `c52ae7fac46f0395a78276bbc6c3b97ea83538005bcee11b60b2dc33879adfaa`.

[Native local evaluation v1](local-evaluation-v1.md) scopes the existing public
reload to native definitions refresh where declared and adds bounded native
per-invocation provenance. Fresh authenticated HTTP and public readiness are
separate checks; a void return or old readiness alone cannot satisfy a reload.

## Reproduce and consume

Requires Node >=22 and npm. From this directory:

```sh
npm ci --ignore-scripts
npm run generate   # only when intentionally regenerating
npm run check      # in-memory regeneration, exact committed-file comparison
npm test
```

`package-lock.json` locks TypeScript, ts-json-schema-generator, Ajv and the strict
JSON test parser. TypeScript code fences and operation rows in the selected catalog
are compiled, not converted into type-name strings masquerading as schemas. The
TypeScript AST independently enumerates configuration fields, cross-checking the
phase-1 ledger when available. Generation checks the base 180 distinct routes and 143 distinct
configuration paths, then emits 180 routes and 144 effective configuration paths. Published/distributed copies need no local notes directory or
phase-1 ledger to generate. Generated files are distribution assets, not authoring
sources. Schema `$id` URLs are identifiers; consumers load these local files, not
HTTP resources.

| File | Use |
| --- | --- |
| `inputs/provenance.json` | Selected source identities, original locations and SHA-256 digests. |
| `inputs/public-rpc-catalog.md` | Byte-identical selected catalog, hash `ac8165c607ea0d15e924d3984e4da49d68cdcb77d1d2fe8de18da142603870e3`. |
| `inputs/public-rpc-decisions.md` | Byte-identical selected decision evidence. Historical source-inventory links refer to the original notes; neither generator nor transport follows them. |
| `protocol.ts` | Authored transport, fixture, callback, profile, typed-cell and reporting records. |
| `generated/catalog.ts` | Extracted shared types and named `Op…Args` / `Op…Result` types for every route. |
| `generated/catalog.schema.json` | JSON Schema draft-07 definitions for semantic argument/result targets, including shared records and typed references. |
| `generated/protocol.schema.json` | Draft-07 definitions for wire frames and reports. |
| `generated/operations.json` | Route, receiver kind, argument/result schema references, reference-valued result kinds, exact row/behavior provenance and shared default/decision links. |
| `generated/configuration.json` | All 144 effective paths with types/source provenance; shared configuration schema and default/behavior provenance. |
| `blockers.json` | Three bounded target uncertainties; no inferred semantic decisions. |
| `test/schema.test.mjs`, `test/oracles.mjs` | Positive/negative schema checks and executable cross-field contract oracles to port into harness tests. Not a transport implementation. |

Validate a **named definition**, e.g.
`generated/protocol.schema.json#/definitions/InvokeRequest`; the document roots are
schema libraries, not permissive request validators. Use draft-07, finite JSON
numbers, and no type coercion, property deletion, or default insertion. Apart from the approved amendment, the only
compiler refinements to the extracted catalog types are integral `integer`, the
catalog's explicit-offset/nanosecond timestamp syntax, and string-encoded zero-based
integer keys for survey `initial_responses` (JSON object keys cannot be numbers).
Calendar validity, positive limits and field-specific semantic policies remain in
the selected catalog; shape validation alone is not a full behavior oracle.

The contract version is **2.0.0**; the transport identifier is **http-json-v2**.
A changed frozen input needs an explicit new selection/version, not an edited hash
to make generation pass. The selected catalog's defaults/behaviors govern expected
outcomes; the adapter's observed outcome never chooses the expectation. All default
provenance is descriptive: no generated schema uses JSON Schema `default` to inject
SDK inputs. The effective catalog identity algorithm and base-only compatibility boundary
are specified in [capture-amendment-v1](capture-amendment-v1.md). Canonical alignment listed in the decision input remains downstream.

## 1. Envelope versus SDK semantics

`Invoke` has exactly `call_id`, `route`, `receiver`, `args`, and optional `references`.
The route is one of the 180 operations; the receiver kind is the operation manifest's
kind. The request frame additionally carries `fixture_id` and bounded host
`timeout_ms`. Every actual public SDK operation has one call ID, including public
getters and nested callback calls. No adapter-internal public SDK calls, retries,
flushes, reads, or polling may be hidden inside an invocation.

The **wire envelope** is enforced before calling the SDK: known route, strict frame,
JSON object arguments, valid scoped receiver/references, unique IDs, and no reference
collisions. The per-operation **argument schema is a semantic target**, not an
admission gate. For example, `/identify` with `{}` and `/capture` with `{"event":42}`
are well-formed Invokes, even though they fail their semantic argument schemas.
Representable negative inputs must reach the SDK unchanged. Null, empty strings,
false, zero and empty maps/lists are never replaced by omission. Do not drop unknown
SDK option fields to force a binding to succeed. If an input cannot be expressed by
the selected public API/runtime, return an attributed `blocked_fixture` (native
representation impossible) or `unsupported_binding` (missing public parameter/API),
not a simulated SDK rejection or a pass. A malformed envelope is a harness error,
not an SDK error.

## 2. HTTP/JSON transport deployment

By default, the host binds an ephemeral **127.0.0.1 TCP port** supplied to the runner.
An explicit private-network deployment opt-in also permits operator-configured
adapter DNS/IP hosts and listen ports, for example separate containers on an
isolated Docker network. The runner's `--allow-private-network` flag permits those
hosts; it does not verify that the selected network is private. Operators must
provide isolation and must not expose these HTTP services through published host
ports or public networks. Without opt-in, the runner accepts only `127.0.0.1`.

Adapter URLs require HTTP and an explicit port, with no credentials, non-root
path, query, or fragment. Mock bind and advertised hosts are configured separately;
mock services retain fresh per-case ephemeral ports and retired URL isolation.
Wildcard binding requires explicit configuration and never implies an advertised
hostname. This deployment amendment does not change the `http-json-v2` wire
protocol, envelopes, negotiation, or catalog identity.

All endpoints below use POST, with exactly one UTF-8 JSON object body and one JSON
object response, `Content-Type: application/json`.
Maximum request/response body size is **1 MiB**. No redirects or automatic retries.
Reject malformed UTF-8, duplicate object keys (including escaped-equivalent keys),
NaN/Infinity and numeric overflow to infinity, comments, trailing commas and trailing
JSON data. A standard parser that silently overwrites duplicate keys is insufficient.
Numbers must be losslessly representable by the host or explicitly blocked; do not
round a large integer while translating languages. Runtime NaN/Infinity/bigint inputs
use value-reference fixtures, not nonstandard JSON.

| Endpoint | Request definition | Successful HTTP 200 response definition |
| --- | --- | --- |
| `/v2/negotiate` | `NegotiateRequest` | `NegotiateResponse` |
| `/v2/fixtures/allocate` | `AllocateRequest` | `AllocateResponse` |
| `/v2/fixtures/references` | `ReferenceRequest` | `ReferenceResponse` |
| `/v2/invoke` | `InvokeRequest` | `InvokeResponse` |
| `/v2/fixtures/context-scope` | `ContextScopeRequest` | `ContextScopeResponse` |
| `/v2/fixtures/observations` | `ObservationsRequest` | `ObservationsResponse` |
| `/v2/cancel` | `CancelRequest` | `CancelResponse` |
| `/v2/fixtures/close` | `CloseRequest` | `CloseResponse` |

All definitions are in `protocol.schema.json`. All calls after negotiation require
`Authorization: Bearer <session_id>`. The host returns an unpredictable session ID;
it scopes fixtures/references and is not recorded in conformance reports. Unknown
sessions return HTTP 401 `ProtocolError`; malformed JSON/envelopes/references return
400; unknown fixtures return 404; duplicate IDs or invalid lifecycle state return
409. Unknown paths return 404. A host unable to produce a protocol response returns
5xx; all non-200 responses, connection errors, oversized/malformed responses and
wrong response attribution are harness errors. No native SDK outcome is inferred
from an HTTP status. Rejected negotiation is a valid HTTP 200 `kind:rejected` frame.

The runner sends:

```json
{"contract_version":"2.0.0","catalog_sha256":"3a0a24cdfa3a1bfd677c677b1be7f15400dbb543fcb2d29a0f84f5d6fdc4bc26","transport":"http-json-v2"}
```

The host accepts **only this exact version, hash and transport**, returning selected
version/hash, session ID, adapter identity, profiles, supported routes and
`max_timeout_ms`. Reject v1 before allocating fixtures or executing a case. A v1
server's 404 or old-shaped response is an incompatible adapter, not grounds for a
v1 fallback. Consumers validate accepted fields against their request, not merely
against a response-shaped object. Profile IDs and supported routes are unique.
An unsupported applicable operation stays `unsupported_binding`; it must not be
filtered into `not_applicable`. Migration-suite automatic candidate selection is
separate from applicability; see the SDK capability selection rules below.

A minimal call after allocation (using the returned receiver ID):

```json
{"fixture_id":"case-1","timeout_ms":5000,"invoke":{"call_id":"capture-1","route":"/capture","receiver":{"kind":"instance","id":"receiver-1"},"args":{"event":"event","properties":{"false":false,"zero":0,"null":null}}}}
```

The response is `{"receipt":{...}}`, where the receipt echoes fixture/call/route and
contains `completion:{"kind":"sdk","outcome":{"kind":"void"}}` for a genuine
void completion. Parent and callback IDs appear only for nested calls. A response
with another fixture/call/route is never accepted. All call IDs are unique within
the run. Invocation requests are not idempotent: duplicate IDs fail **without another
SDK invocation**, and a lost response never authorizes retrying the operation.
Only close is idempotent. Ordinary `/invoke` requests are serial; a second invoke
while one owns the fixture is invalid state. The opt-in concurrent invocation
fixture owns the receiver as a group and does not relax that ordinary-invoke rule. Cancellation and observations remain
available on the control channel while a native operation is pending.

### Bounded completion and cancellation

Host `timeout_ms` is an integer in 1..300000, also no greater than negotiated
`max_timeout_ms`. It starts on host admission using a monotonic clock. The client
uses that deadline plus at most **1000ms transport grace**; handshake, reference
installation, observations and cancel requests have a 5000ms client deadline.
Allocate, context-scope and close use their explicit deadlines. Native SDK
`args.timeout_ms` is separate: it can be zero/omitted/negative as a semantic test and
must not be replaced by the host deadline.

Await the actual asynchronous SDK result, without extra SDK work. When the host
deadline expires, emit `Completion.kind:harness` with `failure.kind:timeout`, mark
the fixture unusable, invalidate all references, and terminate its isolated host
execution. Cancellation is a separate control request and uses `cancelled` with
the same invalidation. Neither is an Outcome tag, a native thrown exception, nor
evidence that queued delivery succeeded. They classify the case as `harness_error`
with the exact call ID. The host must enforce the bound independently of a blocked
SDK event loop (e.g. an isolated worker supervised by a control process).

Cancellation/native completion races are linearized at the host: the first terminal
transition wins. Cancel acknowledges `cancelled` or `already_completed`; no late
native result overwrites a timeout/cancellation receipt or changes a later fixture.
If the control connection fails, the runner records a harness error, terminates the
host and does not reuse it. The runner always attempts bounded close in finally;
teardown failure prevents a success receipt even after assertions passed.

## 3. Fixture and receiver lifecycle

Allocate requires a new `fixture_id`, origin `case_id`, profile ID and deadline.
It creates an isolated fresh host environment and reserves an `instance` receiver;
it does **not** initialize an SDK, call setup/reset/shutdown, or insert configuration.
Its `allocated` response is fixture metadata, not an SDK Outcome. Each fixture belongs
to exactly one case/profile; IDs are not reusable during a session.

`/setup` uses that receiver. On constructor-based SDKs this invocation performs the
single genuine construction and binds the constructed object to the reserved
receiver; the constructor allocation itself is not an explicit method return.
Successful construction has the selected void setup completion. If the SDK instead
has an explicit setup/initialize method, observe that method's actual return. A
method returning a receiver has a value/reference outcome, even though the frozen
`/setup` target expects void; do not consume/discard it to fabricate conformance.
Before-setup methods run only when the public API can genuinely represent that
state. A missing such binding is visible, not repaired by premature construction.
No second hidden initialization is allowed. Repeated setup is an explicit new call
if the scenario requests it, following native behavior.

Close disposes the fixture host and invalidates **all** references, callbacks,
subscriptions and late traffic. It is not `/reset` or `/shutdown`; those are explicit
SDK calls under test. A later case gets a different isolated receiver/environment.
The host retains diagnostic receipts for observation until its negotiated session
ends; close does not keep runtime objects alive. Restart/storage/clock/network/UI
stimuli are future declared fixture capabilities, not arbitrary private RPCs. The
core 2.0.0 reference constructors cover only special values, native exceptions and
callbacks. Other reference kinds come from public results or a separately declared
host fixture; absent fixture construction is `blocked_fixture`, never a JSON stand-in.

## 4. Runtime references and outcomes

The host registry maps `(session, fixture, id)` to one native object/kind. Kind and
fixture must match, including the receiver kind from the operation manifest. Do
not resolve a stale/cross-fixture ID, change its kind, or alias a new receiver to it.
Repeated observation of the same retained native object preserves its reference
identity. Native object liveness and fixture liveness are distinct: a span can have
ended while its reference remains available for a native idempotence test.

Arguments use `references`, keyed by **non-root RFC 6901 JSON Pointer relative to
args**. Decode `~1` as slash and `~0` as tilde exactly once. `-` is not an array index.
Every parent container must exist in JSON; the final slot must be **absent**, not
null or a reference-shaped object. Reject malformed pointers, overlapping ancestor/
descendant paths, existing slots, missing parents and wrong/stale reference kinds.
Normal references are allowed only at matching reference-typed catalog positions.
A negative-input fixture may put kind `value` at the exact catalog argument location
under test (including nested property data), not add a new native parameter.
Semantic requiredness/type errors in the other arguments do not prevent injection.

For an array, referenced positions form a contiguous suffix starting at the JSON
array's length. Install them by numeric index, independent of map iteration order.
For example, `args.config.before_send:[]` plus references at
`/config/before_send/0` and `/config/before_send/1` preserves two callback positions.
`[null]` plus `/config/before_send/0` is invalid. Interior holes cannot be represented
with null placeholders; use a declared fixture or report `blocked_fixture` if a
negative case requires such a runtime shape.

A reference-looking JSON value in `properties`, a JSON callback argument, or a
data-only result remains ordinary data. The host never recursively hunts for
`{kind,id}` objects and replaces them with runtime objects. The `value` special
fixture supports undefined, NaN, positive/negative infinity and bigint decimal;
bigint decimal syntax is `^-?(0|[1-9][0-9]*)$`, and native lack of support is a fixture
blocker. An exception fixture creates a genuine native exception with the given
name/message; stack capture belongs to that host, not a fabricated JSON stack.

`Outcome` is exactly one of:

- `{"kind":"void"}`: genuine native Unit/void or its asynchronous completion.
- `{"kind":"undefined"}`: an actual undefined result distinct from void.
- `{"kind":"value","value":...}`: preserves null/false/zero and actual data.
- `{"kind":"thrown","error":{"kind":"exception","id":"..."}}`: a retained
  actual thrown exception. Returning an error is not throwing it.

For a **reference-valued operation**, `value` is the catalog-typed reference, e.g.
`{"kind":"value","value":{"kind":"snapshot","id":"snapshot-1"}}`.
Do not replace it with null and a side-channel retained handle. For plain data with
native retained identity, `retained` may additionally supply the handle; it is not
permission to call extra getters during serialization. If the value itself is a
reference and `retained` is also present, they identify the same native object.
The manifest's `result_reference_kinds` identifies reference-result positions; it
does not make a ref-looking object in a `Json` result into a handle. Per-operation
result schemas validate the observed `{kind,value}` projection (or `{kind:void}`);
`retained` is separately validated transport metadata. Thrown/undefined observations
are always preserved, even when they fail the operation's normal result target.

Native signature/completion evidence determines Unit/void classification, **not the
expected route's schema**. A real data result from a method declared void remains
a value; an unknown/untyped undefined result cannot be relabeled void merely to
pass. Bindings must document the native void/Unit mapping they use. Native non-JSON
result alternatives without a lossless selected representation are the bounded
`native-non-json-result` blocker; do not stringify them or turn them into thrown.

## 5. Callbacks and owning execution context

Install `ReferenceRequest.fixture.kind:callback` **before** invoking the SDK that
receives it. A plan is an explicit finite sequence, not a general program: signature,
maximum invocation count (1..1000), ordered calls, and one return source. No loops,
branch conditions, eval, remote closures, implicit SDK getters, or assertion language.
`CallbackArguments` records target signatures; actual arguments are observed as
Outcomes, preserving undefined, null and explicit retained identity.

| Signature | Target arguments | Plan return |
| --- | --- | --- |
| `loaded` | instance ref | void |
| `on_error` | exception ref | void |
| `before_send`, `log_hook`, `span_hook` | assembled event/log/span data | data or null; genuine throw follows SDK hook behavior |
| `readiness` | none (reload/flush completion) | void |
| `on_feature_flags` | enabled keys, values/variants, optional `{ errorsLoading?: boolean }` | void |
| `on_feature_flag` | flag value or null | void |
| `on_session_id` | session ID or null | void |
| `on_surveys_loaded` | survey list | void |
| `on_event` | emitted data | void |
| `with_context` | none | continuation result |
| `with_span` | span ref | continuation result |
| `push_identity_provider` | distinct ID, app ID | string or null |
| `anonymous_id_provider` | generated ID | string |
| `early_access` | service-owned feature list | void |

The host executes the plan **inside the real SDK callback on its owning stack/
execution context**. Synchronous callbacks remain synchronous: starting a promise
chain or sending an HTTP request then replaying calls later is not equivalent. For
a native asynchronous callback, preserve the owning async context and await only
the calls/results actually in the plan. If a synchronous callback plan requires an
asynchronous native call that cannot complete synchronously, report `blocked_fixture`
without inventing a result or detaching execution. Host capabilities and native
binding metadata must establish representability before the owning call starts.

Each plan call supplies a route, receiver source, args and optional reference-source
map. Source variants are `reference` (existing fixture ref), `callback_argument`
(zero-based actual runtime argument), and `call_retained` (the retained identity or
typed reference result from an **earlier** plan step). Only reference-valued runtime
arguments are usable for receiver/reference injection. Calls use the same strict
Invoke/reference checks; they do not add arbitrary argument-copying semantics.
Step IDs are unique and dependencies must point backwards. A nested call's native
thrown result is recorded, not implicitly rethrown by the plan; `call_outcome` can
explicitly return/rethrow it. A harness failure stops the plan and records a harness
failure, never a fake native thrown SDK outcome. Any owning SDK result caught or
returned afterward is still observed independently; the case cannot pass over a
failed continuation.

Return sources are a literal Outcome, an actual callback argument (identity/data
preserved), or an earlier call's Outcome. Literal thrown outcomes require a live
exception reference; literal reference results require a live typed reference.
Callbacks returning an observed runtime object return that object itself, not its
serialized record. Notification plans normally return genuine void; intentionally
negative callback-return fixtures remain representable and are not validated into
SDK success by the host.

Callback invocation indexes start at zero per reference. Their IDs are
`@callback/<encoded-fixture-id>/<encoded-reference-id>/<index>`; nested call IDs
append `/<encoded-step-id>`. Encoding is UTF-8 percent-encoding of every character
except ASCII letters, digits, `-._~`. Caller-supplied call IDs must not start
`@callback/`. Repeated callback firings get different IDs. `owner_call_id` is the
currently owning public invocation when one exists; asynchronous background SDK
notifications have null owner, but still belong to the fixture. Nested receipts
carry `callback_invocation_id`, and `parent_call_id` when there is an owning call.

Observations are append-only completion records with per-fixture sequence numbers
starting at 1 (0 is the initial cursor). A response returns all records after
`after_sequence` and a cursor for the last returned sequence, or the supplied cursor
when empty. Callback records preserve ordered argument observations, completion,
invocation ID/index and nested call IDs; call records preserve full receipts. There
are no callback HTTP response/replay endpoints. Polling observations reads host
records only and never invokes an SDK getter. Exceeding a plan's invocation bound
or the 1 MiB observation bound is a `harness_error`, not silent truncation; retain
the diagnostic and fail the case. A callback bound violation never supplies a
fabricated callback value as if it were a normal observation.

`/v2/fixtures/context-scope` enters an existing context handle via its genuine native
context protocol, executes the listed Invokes in order on that owning context, and
exits in finally, all within **one** host request. This is fixture runtime entry/exit,
not an extra SDK RPC. Its result is fixture completion, not a synthetic SDK Outcome.
Entry/exit inability or failure is `blocked_fixture`/`harness_error`. Separate HTTP
calls cannot share execution-local context by storing it in the adapter. Likewise,
`/enter_context` needs a subsequent call in the same callback/explicit context-scope
continuation to test persistence across calls; top-level HTTP replay is not proof.

## 6. Typed step data (for the later runner)

`TypedCell` distinguishes `omitted`, `json` (including explicit null), and
`reference`. An omitted field produces no argument key. A reference produces an
absent JSON slot and a separate pointer entry. JSON values retain their exact types;
`"false"` is a string and `false` is a boolean. Undefined is not JSON null: construct
a value reference when the runtime can represent it. No textual magic sentinel is
reserved inside ordinary user properties.

Later registered step definitions must declare how each cell/outline parameter is
interpreted. JSON-typed table cells use one strict JSON value, string-typed cells
stay literal, and omission is explicit typed metadata rather than an empty string.
JSON doc strings use `application/json`; empty/malformed JSON fails step binding,
not an SDK call. Outline substitution follows the declared type and cannot silently
stringify an object, infer booleans from strings, or lose null/false/zero. These are
boundary rules and typed-data helper inputs, not new executable Gherkin steps.

## 7. Profiles and trustworthy reports

A profile independently names runtime and execution context, identity model,
analytics protocol, product lanes, public module entry/format/package/version, and
fixture capabilities. The optional additive `sdk_capabilities: Id[]` field declares
SDK feature/API support independently from host fixtures. Existing profiles without
it remain valid; absence is unknown, not evidence of feature support. No dimension is inferred from another. For example, server
runtime does not select request identity, analytics-v1 does not enable AI, and a
missing operation does not remove applicability once a case is selected. Exact string capability names are
negotiated; 2.0.0 core names are `references.value`, `references.exception`,
`callbacks.continuation`, and `context.scope`. Capability absence means a fixture
blocker when a selected case needs it. `not_applicable` requires a named target
applicability rule (e.g. a real UI runtime requirement), not an API-presence check.

### Migration-suite candidate selection

The versioned [YAML parity suite](../../migration/yaml-parity-v1/README.md) uses
negotiated public `supported_routes` to select API-family candidates, then independent
SDK capability requirements to refine them. The AI capability is `capture_ai_v0`:
AI capture using `/i/v0/ai/batch/`. This does not choose an analytics protocol, imply a
runtime/identity model, or assert support for ordinary `/capture`. A declared AI-v0
capability with missing `/capture_ai` is an inconsistent claim and reports
`unsupported_binding`, not a pass or exclusion. Explicit case selection likewise
retains missing SDK prerequisites as gaps. The analytics-v1 slice requires the
independent `capture_v1` capability, claiming ordinary `/capture` delivery to
`/i/v1/analytics/events`. Missing `/capture` under this claim is likewise
`unsupported_binding`. Runtime, identity, product lanes and the profile's protocol
label do not supply either declaration. The runner does not reconfigure a profile
whose wire behavior contradicts its claim; wire assertions reveal that mismatch.
Missing supporting `/setup` or `/flush`
is a binding gap after selection. An unavailable required host fixture is
`blocked_fixture`, never an API-family exclusion.

Without a primary operation or required SDK capability, automatic candidates may
be `not_selected` with a precise reason. This is not `not_applicable`, nor a claim
that the behavior is irrelevant to that SDK. Absence of `sdk_capabilities` is
reported as undeclared metadata. No client/server/runtime/product inference fills
it in. Frozen canonical selection remains unchanged in this increment.

A `Report` includes version/hash/run/scope IDs; full profiles; the complete
`inventory` of case/profile pairs with selected/applicable decisions and frozen
source identities; exactly one corresponding result per pair; fixture-to-case
attributions; call receipts; and run-level errors. Keep canonical case IDs from phase 1,
including outline-example identities. Migration cases use their separate versioned
IDs and checked legacy-source ledger; they do not replace phase-1 identities. Case/profile is the uniqueness key, allowing
the same origin case in two profiles. Source revision/path/line must match between
inventory and result. The report does not carry a trusted caller-set success flag.

Statuses are strict tagged records:

- `passed`: selected, applicable and actually executed; all expected assertions pass.
- `failed_assertion`: target expectation differs from actual SDK/fixture evidence.
- `unsupported_binding`: applicable public operation/parameter is missing.
- `blocked_fixture`: required runtime input/host observation cannot be supplied.
- `blocked_contract`: an identified target uncertainty blocks this assertion.
- `not_applicable`: selected case excluded by a named target rule.
- `not_selected`: case excluded by the selector, still inventoried.
- `harness_error`: parser, binding/step, protocol, timeout, cancellation or runner failure.

Failure statuses require a code, specific message, failed-step source/index and call
IDs. A pre-execution failure can have `failed_step:null` and no calls; once executed,
the failing step must be attributed. Step indexes are zero-based; source lines are
one-based. A failure's call IDs list **all case calls**, including nested/prior calls,
not only the final failing call. Every call ID is globally unique, resolves to a
receipt, and belongs through its fixture to that case/profile. Parent IDs must refer
to earlier owning calls in the same fixture and form no cycles. Receipts are never
shared between cases. No orphan or multiply attributed calls/fixtures, unknown
profiles, duplicate inventory/results, mismatched sources, or missing results are
permitted. Callback diagnostics feed case errors; a swallowed plan/host failure
cannot become a passed SDK result.

**Strict success is computed, never trusted from a report field:**

1. Schema, source/profile attribution, complete unique inventory/result
   correspondence and reference/call consistency all validate.
2. There are no run errors (including discovery/selector/unknown-step/ambiguous-step
   errors or teardown failures), and no selected applicable failure, unsupported
   binding, fixture/contract blocker or harness error.
3. At least one **selected, applicable, actually executed** case passes. A nonempty
   inventory consisting only of `not_selected` or `not_applicable` is not success.
4. Unselected entries are `not_selected`; selected excluded entries are
   `not_applicable` with the recorded rule; selected applicable entries cannot hide
   behind either status. A passed case cannot contain a harness-failure receipt.

Malformed reports and accidental zero selection cause nonzero runner exit even when
no case was executed. Negative SDK tests can pass with actual thrown/error outcomes
when the independent target expects them; infrastructure failures cannot. These
schemas do not claim migration parity or execute any of the 728 inventoried cases.

## 8. Bounded blockers and next implementation gate

`blockers.json` preserves nullable override **submaps**, worker-held pending counts,
and encountered native non-JSON result alternatives. Block only affected assertions;
do not assign invented semantics or stop unrelated capture/flush work. In particular,
accepting a nullable field in its type is not a decision about that field's effect.

The harness worker should implement named-schema loading; strict JSON/frame and
cross-field validation; negotiation; bounded HTTP client/fixture lifecycle;
reference/typed-data handling; and report gates. Port these contract tests and add
controlled-host transport tests for real synchronous callbacks, async owning-context
preservation, nested call attribution, void versus undefined, malformed frames,
stale references, timeout/cancel races and teardown isolation. A passing schema test
alone is **not** proof that a host preserves synchronous context or lifetime.
Do not start a real SDK, Node binding or Gherkin step runner for this phase.
