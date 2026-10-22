## 1. Contract update

- [x] 1.1 Compare `posthog-python` exception capture (ambient OpenTelemetry span, zero-padded hex, validity check, lazy import) with `posthog-node` (no trace IDs on exceptions).
- [x] 1.2 Add the active trace context and the absent-or-unreadable requirements, with scenarios, to the `exception-event-metadata` delta spec.
- [x] 1.3 Add matching acceptance scenarios to `acceptance/private/exception-event-metadata.feature`. The read-failure case stays in the spec only, because an adapter cannot cause it through public behavior.
- [x] 1.4 Add a canonical example event to `acceptance/private/exception-event-metadata.examples.json`.
- [x] 1.5 Sync the change into the canonical spec.
- [x] 1.6 Address review: no hard OpenTelemetry dependency, server-only applicability, unsampled spans, leading zeros, no caller-precedence rule, no Cymbal claim.

## 2. Validation and archive

- [x] 2.1 Validate the canonical specs strictly and check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` passed. This is a specification check, not an executed SDK conformance test.
