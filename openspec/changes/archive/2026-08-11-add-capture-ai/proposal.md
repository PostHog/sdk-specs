## Why

AI observability events routinely exceed analytics payload norms (multi-MB
multimodal content). RFC 1198 decided each supporting SDK exposes a dedicated
`capture_ai` method on an isolated delivery route with its own caps, instead of
special-casing `$ai_*` inside `capture`. posthog-python ships this today
(private `_capture_ai`, since 7.29.0) and posthog-node has it in review; both
go public beta now. This change codifies the one cross-SDK shape before the
public release freezes it, so Rust/Go later inherit the contract instead of
re-diverging.

## What Changes

- New capability spec `capture-ai` covering: surface parity with the host
  SDK's `capture`, event-UUID return value, client-generated UUID, the
  `enable_full_ai_capture` flag, isolated delivery, drop logging, the
  provider-native content promise, and a non-normative transport section.
- New acceptance feature `acceptance/public/capture-ai.feature`.

## Capabilities

### New Capabilities

- `capture-ai`: dedicated AI-observability event capture on an isolated
  delivery route, with client-generated UUID event ids, a single
  `enable_full_ai_capture` configuration flag governing AI-wrapper redaction
  and truncation, and a non-normative current-transport section.

### Modified Capabilities

None. `capture` is untouched — AI-named events (`$ai_*`) captured through
`capture` are not rerouted; only calls to `capture_ai` ride the isolated
route.

## Impact

- `openspec/specs/capture-ai/spec.md` — created on archive from this change's
  delta.
- `openspec/project.md` — Capabilities section gains a line for the
  capture-ai capability (prose alignment at archive).
- posthog-python and posthog-node implement this contract for public beta;
  Rust and Go inherit it if and when they add AI support.
- Adds `acceptance/public/capture-ai.feature`; no SDK implementation code
  changes in this repository.
