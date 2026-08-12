## 1. Cross-SDK evidence

- [x] 1.1 Audit mechanism objects on primary manual, automatic, logger, and crash capture paths across maintained first-party SDKs
- [x] 1.2 Inventory the common mechanism fields preserved by exception ingestion and distinguish platform extensions
- [x] 1.3 Separate boundary-derived defaults from metadata that context-free builders cannot determine

## 2. Internal wire capability

- [x] 2.1 Add the client/server `exception-event-mechanism` capability for SDK-generated manual and automatic exception events
- [x] 2.2 Define canonical types and omission semantics for `type`, `handled`, `source`, and `synthetic`
- [x] 2.3 Require builders to preserve all supplied common mechanism metadata
- [x] 2.4 Define stable mechanism type, handled state, source, and synthetic state semantics
- [x] 2.5 Define related exception-level normalization and capture-boundary defaults

## 3. Acceptance and discoverability

- [x] 3.1 Add private client/server acceptance scenarios for common field preservation, synthetic state, boundary defaults, and unknown metadata
- [x] 3.2 Add the internal capability to the root capability index and project context
- [x] 3.3 Keep the client-only public `capture-exception` capability and its public acceptance feature unchanged

## 4. Validation and archive

- [x] 4.1 Run `openspec validate standardize-exception-event-mechanism --strict` and resolve all findings
- [x] 4.2 Archive the completed change so the canonical spec and archived proposal are included in the same branch
- [x] 4.3 Run `openspec validate --specs --strict` after archive
