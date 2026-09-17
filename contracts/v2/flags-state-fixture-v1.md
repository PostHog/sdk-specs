# Flags state fixture extension v1

Optional extension to `http-json-v2` / contracts 2.0.0. The frozen RPC catalog and
core envelopes are unchanged. `FlagStateRequest` and `FlagStateResponse` are named
schemas. `POST /v2/fixtures/flags` follows session authorization, body limits,
fixture attribution, serial execution and bounded deadline rules of the core.

| Command | Required capability | Preparation/observation |
| --- | --- | --- |
| `definitions_install` | `flags.definitions.install.v1` | Install a complete v1 definitions document into the initialized SDK's actual local-definition component. Complete only when parsed definitions are available for local evaluation. |
| `evaluation_cache_put` | `flags.evaluation_cache.put.v1` | Install a complete, unexpired evaluated result for the explicit `distinct_id`, with all other evaluation-context fields omitted. Preserve flag/payload key presence and JSON types. |
| `evaluation_provenance` | `flags.evaluation_provenance.v1` | Observe the native evaluator result for one exact public invocation ID, without invoking or changing it. |
| `evaluation_activity` | `flags.evaluation_activity.v1` | Observe cumulative counts of actual evaluated-cache lookups and local per-flag evaluation attempts since allocation. |

These are declared native-component fixtures, not private SDK RPCs implemented by
the public adapter. Each successful response identifies `layer:native_component`
and the concrete `implementation` site. Hosts unable to prepare or instrument the
real component return `blocked_fixture`. They must not synthesize getter results,
intercept evaluations with a shadow map, or count public calls as evidence of
internal activity. Missing applicable public methods remain `unsupported_binding`.

Definitions use the existing v1 service document (`flags`, `cohorts`, and
`group_type_mapping`), including the real rule/filter data. Schema validation of
the envelope does not prove the host can represent every definition. A host must
reject unsupported shapes as `blocked_fixture`, not silently omit them. Replace
the entire loaded definition set; do not clear evaluated cache entries, trigger
remote evaluation, or emit flag exposures as a side effect of preparation. This
fixture establishes loaded state; it does not prove HTTP loading, polling,
cache-provider loading, version refresh, or their invalidation semantics.

Cache preparation must use the SDK's actual context key and expiration mechanism,
under the fixture clock. It is scoped to the supplied identity with other context
fields omitted, not a global override. Do not claim a remote load occurred or mark
fresh/remote-readiness provenance. A host that cannot seed an eligible evaluated
entry without doing so must report a blocker. Stateful cached getters can instead
use the public `/update_flags` operation as an explicit SDK call.

Activity comes from instrumentation at the native lookup/evaluator sites. A lookup
counts even on a miss; evaluation counts even when inconclusive. Observation and
preparation do not increment these counters. The runner compares observations
immediately before and after the operation under test. In particular, an empty
request-time key list must not touch either component. An HTTP request alone does
not prove that local/cache work was skipped.

Preparation and cumulative-activity controls run after setup, at quiescent
boundaries with the fixture scheduler held. No background evaluation may race
with installation or cumulative-activity observation. If a host cannot guarantee
that boundary, it returns `blocked_fixture`. Deadlines use real
monotonic time independent of the fixed SDK wall clock. A timed-out control must
be stopped before teardown; no late mutation may enter another fixture. Close
disposes stores, instrumentation and retained objects without SDK reset/shutdown
calls hidden in fixture cleanup.

The first consumer prepares simple constant boolean/variant definitions and a
rule requiring an unavailable person property, plus exact-identity evaluated-cache
entries. These are existing definition shapes, not a second executable test DSL.
Controlled-host results prove harness behavior only. Real SDK hosts require their
own genuine component implementation and may remain blocked.

The [local-evaluation-v1 amendment](local-evaluation-v1.md) defines the optional
per-call observer, its local/remote/fallback/not-evaluated classifications and
fixture/call/key/value attribution. Unlike cumulative activity, this observer
can establish a particular getter's conclusive local provenance. Its types and
policy participate in the effective negotiated amendment digest.

Per-call provenance reads a settled, immutable record for the completed owning
call in the same live fixture. It does not require pausing unrelated background
work. A host unable to guarantee native invocation attribution reports a fixture
failure; missing or ambiguous records cannot fall back to cumulative activity,
local-only input or inferred local success. Existing preparation/cache/activity
scheduler requirements above remain unchanged.
