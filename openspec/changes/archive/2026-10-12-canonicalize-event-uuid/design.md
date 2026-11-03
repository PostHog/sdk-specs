## Context

The capture v1 response shape lives in the backend
(`rust/capture/src/v1/analytics/response.rs`): a 2xx carries a `results` map
whose keys are canonical uuids. The request side is lenient, so the SDK can send
a form the server never echoes back. The mismatch is invisible — the batch is
accepted, the per-event verdicts are simply never matched — which is why both
SDKs found it only when they started acting on verdicts.

## Decisions

**The requirement is about the wire value, not the input format.** SDKs keep
accepting whatever uuid forms they accept today (and typed-uuid SDKs keep their
type). What the spec pins down is that the serialized value, and the uuid handed
back to the caller, are canonical.

**Normalization runs after the before-send hook.** Both SDKs normalize at the
last moment for the same reason: the hook can replace the uuid with any accepted
form, and the returned uuid must match what was sent. Specifying it earlier in
the pipeline would leave the hook as a hole.

**An unparseable override does not fail capture.** go's `makeUUID` falls back to
a generated UUIDv7 (v4 if the clock-based path fails); python logs the invalid
value and falls back to a generated UUIDv7. Dropping or throwing would make a
typo in an optional field lose an event, which neither SDK does. The spec
requires the fallback and a log, and leaves the log's wording open.

**Scenarios are tagged `@server`.** Both shipped implementations are server
SDKs, and the capture return value the scenarios check is the server shape.
Client SDKs that accept a uuid override are expected to behave the same way, but
this change does not assert it without evidence.

## Open questions

Both implementations sit on unreleased `v1` branches. The behavior is a bug fix
rather than a new surface, and it matches what the backend already does, so the
contract is recorded now; if the series changes shape before release this
requirement should be re-checked.
