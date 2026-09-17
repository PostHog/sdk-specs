# Flush fixture extension v1

Optional extension to `http-json-v2` / contracts 2.0.0. The core envelopes and frozen
RPC catalog are unchanged. `FlushFixtureRequest` and `FlushFixtureResponse` are
named definitions in `generated/protocol.schema.json`.

`POST /v2/fixtures/flush` uses the negotiated session authorization, strict JSON,
body limits, fixture attribution and deadline rules of the core transport.
Requests carry `fixture_id`, `timeout_ms`, and one `command`. Responses echo both
the fixture ID and command kind. Controls run serially with top-level invocations.
A missing capability is `blocked_fixture`; malformed or misattributed responses
are harness errors. A failed control cannot produce an SDK outcome.

| Command | Required profile capability | Meaning |
| --- | --- | --- |
| `scheduler_manual` | `scheduler.manual.v1` | Before setup, hold automatic delivery and retry scheduling. Explicit flush still executes its eligible attempt; later retries stay scheduled. No replacement SDK defaults or queue mutation. |
| `clock_fixed`, `timestamp` | `clock.fixed.v1` | Before setup, fix the SDK's wall clock to the supplied offset timestamp. Host deadlines still use a real monotonic clock. |
| `storage_empty` | `storage.empty.v1` | Before setup, prepare an empty isolated storage namespace. Not SDK reset. |
| `queue_snapshot` | `queue.snapshot.v1` | Read the actual analytics queue through a declared native component observation fixture. No SDK call, counter reconstruction, draining or mutation. |

Applied controls return `kind:applied`; queue observation returns `kind:queue`
with `observation:{layer:"native_component",implementation,records}`. Each record
has a stable, fixture-local `record_id` and its actual event data. IDs are unique
within a snapshot, survive retry retention, and cannot be reassigned to replacement
records. `implementation` identifies the concrete observation site, not an SDK
conformance claim. Observations occur only at quiescent boundaries: admission and
explicit flush have completed, automatic scheduling is held, and no worker owns
an unobserved batch. A host that cannot establish that boundary must report
`blocked_fixture`; this extension does not decide the `/pending_events` in-flight
count question. A public queue observation would instead be an explicit catalog
RPC, not a hidden call behind this fixture.

Allocation creates a fresh environment; close disposes it and all scheduling and
storage resources. Neither control may initialize/reset/shutdown the SDK. The
harness creates a distinct mock service and URL per case, kept alive through host
close and never reused during the run. Late traffic cannot enter another case.

## First consumer: existing public flush feature

The harness supplies only `project_token` and the case mock `config.host` to setup.
All other configuration remains omitted. Queue preconditions use explicit capture
calls followed by component observation; they never directly seed private queues.
Every setup/capture/flush normal result is checked against the frozen catalog's
void target, independently of the observed result.

The empty-queue scenario's no-network assertion covers the explicit flush call,
from admission through native completion. Startup traffic is retained separately,
not disabled by changing the preload default or discarded to make the assertion
pass. Automatic scheduling stays held through assertions and teardown. The failed
delivery scenario must observe the attempted event receiving 503 and the same
queue record remaining retryable. Seeing a configured 503 alone is not evidence
that the SDK received it.

The controlled host tests implement this extension using their own actual queue
engine. Their results prove harness execution and defect detection only. Real SDK
hosts need their own genuine observation/scheduler fixtures or remain blocked.
