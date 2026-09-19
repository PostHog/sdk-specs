## 1. Acceptance coverage

- [x] 1.1 Replace the generic eligible-interaction scenario in `acceptance/private/autocapture.feature` with browser-click (`click`) and mobile-touch (`touch`) scenarios matching the delta spec; preserve event-name, screen-context, and sanitized-hierarchy assertions.
- [x] 1.2 Verify no-capture, sensitive-input, and repeated-setup scenarios remain unchanged, and that neither scenario requires capturing the element label as payload content.

## 2. Validate and synchronize

- [x] 2.1 Run `openspec validate clarify-mobile-autocapture-event-type --strict` and verify the acceptance scenarios agree with the delta spec.
- [x] 2.2 After approval, archive this change with `openspec archive clarify-mobile-autocapture-event-type` to synchronize the canonical spec without hand-editing it.
- [x] 2.3 Run `openspec validate --specs --strict` and `git diff --check`; confirm only the autocapture contract, its acceptance feature, and this change's artifacts are affected.
