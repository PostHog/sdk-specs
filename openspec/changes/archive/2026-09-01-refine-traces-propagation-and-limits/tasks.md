## 1. Establish the Contract

- [x] 1.1 Verify against the W3C Trace Context flags rules (permitted `sampled` mutation, and the requirement to zero flags an emitted version does not define) and the OpenTelemetry API contract for a non-recording span carrying the parent `SpanContext`.
- [x] 1.2 Confirm ingestion stores the OTLP `flags` field verbatim and reads nothing from it, so propagating a cleared sampled bit changes no server behavior.
- [x] 1.3 Confirm the OpenTelemetry `attributeValueLengthLimit` default and drop-the-batch failure mode, to justify choosing a finite default here.
- [x] 1.4 Re-read the archived `2026-07-31-add-traces` design for the `exception.stacktrace` deferral and the conditions it named for revisiting.

## 2. Write the Delta

- [x] 2.1 Split inert handles into no-op and pass-through in `No-op span handles`, with scenarios for both the echo and the activation.
- [x] 2.2 Rewrite the sampled-flag rules in `Trace context interop` and align the wire `flags` rules in `Span data model`, including parent remoteness.
- [x] 2.3 Add `maxAttributeValueLength` to `Span limits` and `Configuration knobs`, covering nested strings, bounded traversal, and unusable knob values.
- [x] 2.4 Add `exception.stacktrace` to `Scoped span helpers and exception recording` with its ordering relative to `beforeSpanSend` and the value bound.

## 3. Validate and Review

- [x] 3.1 Run `openspec validate --specs --strict --no-interactive` and `openspec validate refine-traces-propagation-and-limits --strict`.
- [x] 3.2 Run `git diff --check`.
- [ ] 3.3 Resolve the open question on whether `maxAttributeValueLength` carries one cross-SDK default. Left open in `design.md`: the knob is specified per-platform like every other knob in this capability, and a single number can be pinned by a follow-up once a second SDK implements traces.
- [x] 3.4 Decide whether acceptance scenarios belong in `acceptance/` for the propagation cases. Spec scenarios suffice for now: `acceptance/` carries no traces feature file, so the harness would have to be stood up before any traces scenario could run.
- [x] 3.5 Archive into the canonical `traces` spec.
