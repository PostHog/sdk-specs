## Context

RFC 1198 already decided the cross-SDK shape this change codifies. posthog-python ships it today
as the private `_capture_ai` (since 7.29.0); posthog-node has an equivalent implementation in
review. This change transcribes the already-agreed contract into a canonical spec before the
public beta release freezes it — see proposal.md for the "why now."

## Goals / Non-Goals

**Goals:**

- State the one cross-SDK shape (`capture_ai` surface parity, UUID generation, isolated
  delivery route, `enable_full_ai_capture`, drop logging, provider-native content) so Rust/Go
  inherit it instead of re-diverging when they add AI support.

**Non-Goals:**

- Designing the shape from scratch — RFC 1198 and the shipped posthog-python implementation
  already settled it.
- Specifying the wire-level transport as a binding contract; the transport section is explicitly
  non-normative and may change (Capture v1 cutover) without altering the Requirements.
- Client SDK (browser/mobile) adoption — this capability is `server`-only for now.

## Decisions

### One isolated route, not `$ai_*` special-casing inside `capture`

`capture_ai` is a separate method on its own delivery route (own queue, own caps, own endpoint)
rather than a property-name check inside `capture`. This keeps analytics batching/size limits
unaffected by multi-MB multimodal payloads and keeps `capture`'s behavior unconditional: an
`$ai_*`-named event sent through `capture` is never rerouted. Alternative considered: sniffing
`$ai_*` event names inside `capture` and rerouting — rejected because it makes `capture`'s
delivery route depend on event-name content, which is surprising and untestable as a stable
contract.

### Client-generated UUID, at-least-once delivery permitted

The SDK, not the server, generates the event UUID whenever the caller doesn't supply one, and
returns it to the caller. This makes the UUID — not the delivery count — the dedupe invariant, so
retries that duplicate a send are compliant as long as the server dedupes on
`[timestamp, distinct_id, event, uuid]`. This is why at-least-once and at-most-once are both
declared compliant delivery semantics in the spec.

### Single flag, `enable_full_ai_capture`, scoped to wrapper libraries only

One boolean, default false, governs three related wrapper-only behaviors (route, truncation,
media redaction) together rather than three separate flags, because they're facets of the same
"trust the AI wrapper with full content" decision. It explicitly never touches manual
`capture_ai` calls — a direct caller already gets the unredacted pipe-through behavior described
in the Content section, so there's nothing for the flag to gate there.

## Risks / Trade-offs

- **At-least-once delivery could read as a reliability weakening** → The spec states the
  invariant explicitly (UUID, not delivery count) so implementers don't over-engineer exactly-once
  delivery guarantees the contract doesn't require.
- **Non-normative transport section could be mistaken as binding** → Labeled explicitly
  "non-normative" and "may change without notice," with the Capture v1 cutover called out as an
  example that must not change the Requirements.

## Migration Plan

This repository change is documentation-only. posthog-python's existing private `_capture_ai`
and posthog-node's in-review implementation are the reference implementations this spec
generalizes from; making the public surface conform (renaming `_capture_ai` to a public
`capture_ai`, per the brief for the posthog-python task) happens in those SDKs' own repos as
separate changes.

## Open Questions

None.
