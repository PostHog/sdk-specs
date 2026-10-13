## 1. Contract update

- [x] 1.1 Compare `posthog-python` exception capture (ambient OpenTelemetry span, hex format, caller precedence) with `posthog-node` (no trace IDs on exceptions).
- [x] 1.2 Add the active trace context requirement and scenarios to the `exception-event-metadata` delta spec.
- [x] 1.3 Add matching acceptance scenarios to `acceptance/private/exception-event-metadata.feature`.
- [x] 1.4 Sync the change into the canonical spec.

## 2. Validation and archive

- [x] 2.1 Validate the canonical specs strictly and check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` passed. This is a specification check, not an executed SDK conformance test.
