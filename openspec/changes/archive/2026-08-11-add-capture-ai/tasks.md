## 1. Spec delta

- [x] 1.1 Write the `capture-ai` delta spec: canonical `capture_ai` behavior requirement
  (surface parity, UUID return, isolated route, UUID generation, oversized-event drop
  logging, never-throws) with scenarios
- [x] 1.2 Write the `enable_full_ai_capture` flag requirement (default false, wrapper-only
  scope, privacy-mode precedence) with scenarios
- [x] 1.3 Review the delta: every requirement has >=1 scenario, scenarios use WHEN/THEN

## 2. Acceptance feature

- [x] 2.1 Add `acceptance/public/capture-ai.feature` covering the three canonical @server
  scenarios (UUID return + AI route, separate routes from `capture`, no AI-name rerouting)

## 3. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 3.1 Add Purpose, Applicability, Public signatures (posthog-python, posthog-node,
  surface-parity rule), Configuration, Behavior, Error handling, Content, and Transport
  (non-normative) sections to `openspec/specs/capture-ai/spec.md`
- [x] 3.2 Add the capture-ai capability to the Capabilities table in the top-level `README.md`
  (`public API (server)` scope) and to the illustrative Public SDK APIs list in
  `openspec/project.md`

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 4.2 Run apply then archive to create `specs/capture-ai/spec.md`

## 5. Downstream follow-up (separate changes, not this one)

- [ ] 5.1 posthog-python: promote the private `_capture_ai` (shipped since 7.29.0) to the
  public `capture_ai` surface described here
- [ ] 5.2 posthog-node: land the in-review `captureAi`/`captureAiImmediate` implementation
  conforming to this contract
- [ ] 5.3 Other server SDKs (Rust, Go, Ruby, ...) adopt this spec if and when they add AI
  support
