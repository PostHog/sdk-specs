## 1. Contract update

- [x] 1.1 Confirm the shipped normalization in posthog-go (`message.go`:
      `makeUUID`, `canonicalUUID`, `prepareForSend`) and posthog-python
      (`client.py`: `_stringify_event_uuid`, `_normalize_event_uuid` re-run
      after `before_send`), including the unparseable-override fallback.
- [x] 1.2 Draft the canonical event uuid requirement and its scenarios.
- [x] 1.3 Sync the requirement and the narrative notes into the canonical
      `capture` spec.

## 2. Validation and archive

- [x] 2.1 Check the diff against the canonical spec.
- [x] 2.2 Archive the completed change on this branch.

Validation: read the shipped source on both `v1` branches. `openspec validate
capture --type spec --strict` reports the same long-requirement warnings as the
rest of the spec, and `openspec validate --specs --strict` totals are unchanged
from `main` (32 passed, 32 failed, all pre-existing warnings). These are
specification checks, not executed SDK conformance tests.
