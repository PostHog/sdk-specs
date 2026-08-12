## 1. Cross-SDK and processor evidence

- [x] 1.1 Audit primary manual, framework, logger, uncaught, task, panic, signal, and crash capture paths across maintained first-party SDKs
- [x] 1.2 Inventory SDK-produced exception metadata and Cymbal's raw and processed exception properties
- [x] 1.3 Distinguish capture integration, source-file, and nested-relationship meanings
- [x] 1.4 Audit native `$debug_images` producers and Cymbal's accepted image shape

## 2. Internal wire capability

- [x] 2.1 Add the client/server `exception-event-metadata` capability for SDK-generated exception events
- [x] 2.2 Define the canonical event envelope and omission semantics
- [x] 2.3 Define `$exception_level`, `$exception_source`, and capture-boundary defaults
- [x] 2.4 Define mechanism type, handled state, synthetic state, and nested relationship source
- [x] 2.5 Define metadata precedence and low-level builder preservation
- [x] 2.6 Define optional native debug-image and frame-linkage metadata
- [x] 2.7 Document custom fingerprint and release-input ownership without downstream policy
- [x] 2.8 Distinguish SDK-produced fields from Cymbal-derived fields

## 3. Acceptance and discoverability

- [x] 3.1 Add private client/server scenarios for manual, framework, logger, terminating, nested, native, and unknown-metadata paths
- [x] 3.2 Add the internal capability to the root capability index and project context
- [x] 3.3 Keep public `capture-exception`, stack ordering, and `exception-steps` capabilities independent

## 4. Validation and archive

- [x] 4.1 Validate the change strictly and resolve all findings
- [x] 4.2 Archive the completed change so the canonical spec and archived proposal remain in the same branch
- [x] 4.3 Run `openspec validate --all --strict` after archive
