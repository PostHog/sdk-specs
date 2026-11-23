## 1. Register the streaming capture sources

- [x] 1.1 Add `rails.live` and `rails.streaming_template` to the canonical first-party `$exception_source` table.
- [x] 1.2 Add a scenario pinning the streaming capture category to `middleware` with `mechanism.handled` false.

## 2. Verify against the shipped implementation

- [x] 2.1 Confirm the source strings, mechanism type, and handled state against the merged posthog-ruby #338 diff rather than the PR description.
- [x] 2.2 Sync the delta into `openspec/specs/exception-event-metadata/spec.md` and archive the change.

The merged diff sets `source: 'rails.live'` and `source: 'rails.streaming_template'` and builds the mechanism as `{ 'type' => 'middleware', 'handled' => false }`; its specs assert both. The OpenSpec CLI is not installed in this environment, so strict validation was not run; the delta was checked against the canonical requirement by exact text diff.
