## ADDED Requirements

### Requirement: Hidden input values follow input masking

For browser replay, a hidden input — an `<input>` whose `type` is `hidden` — SHALL be treated as an input whose value is masked under the SDK's broad input masking, not as an exempt element. Hidden inputs routinely carry CSRF tokens, prices, and account identifiers, so their values MUST NOT be recorded in clear text while input masking is on.

While broad input masking is enabled (`maskAllInputs`, on by default), the SDK SHALL mask a hidden input's value both in the initial snapshot of the node and in every later recorded change to that value. The SDK SHALL NOT record the clear-text value in any replay payload for that node.

The type-specific input masking option (`maskInputOptions` in posthog-js) SHALL accept `hidden` alongside the other input types. An explicit entry decides the outcome for hidden inputs on its own: `hidden: true` masks them even when broad input masking is disabled, and `hidden: false` records them unmasked.

A custom input masking callback (`maskInputFn` in posthog-js) SHALL receive hidden input values like any other masked input value, and its return value SHALL be what is recorded.

`file` inputs remain the only input type exempt from broad input masking. An application that must keep a hidden value out of replay entirely can still block the element with `ph-no-capture` or `blockSelector`.

This requirement is browser-only. Native and mobile replay has no hidden input concept; those SDKs mask inputs under the password/secure-control and text rules above.

Reference: posthog-js PostHog/posthog-js#5561, which ports rrweb-io/rrweb#1745 — hidden-value masking in `packages/rrweb/rrweb-snapshot/src/snapshot.ts` and in the mutation path of `packages/rrweb/rrweb/src/record/index.ts`, and the `hidden` key on `MaskInputOptions` in `packages/types/src/posthog-config.ts`.

Covering test: posthog-js `packages/rrweb/rrweb/test/record/hidden-input-masking.test.ts` (broad masking, an explicit `hidden` option both ways, a custom callback, and masking disabled) and the `records hidden values with maskAllInputs=%s` case in `packages/rrweb/rrweb/test/integration.test.ts`.

#### Scenario: Broad input masking masks a hidden input value
- **GIVEN** browser session replay is recording with broad input masking enabled
- **AND** the page contains `<input type="hidden" value="initial">`
- **WHEN** the full snapshot is recorded
- **THEN** the recorded value for that node is masked
- **AND** no replay payload contains the text "initial"

#### Scenario: A later hidden input value change stays masked
- **GIVEN** browser session replay is recording with broad input masking enabled
- **AND** a hidden input was snapshotted with its value masked
- **WHEN** the application sets that input's value to "updated value"
- **THEN** the recorded value change for that node is masked
- **AND** no replay payload contains the text "updated value"

#### Scenario: An explicit hidden option masks while broad masking is disabled
- **GIVEN** browser session replay is recording with broad input masking disabled
- **AND** the type-specific input masking option sets `hidden` to true
- **AND** the page contains `<input type="hidden" value="initial">`
- **WHEN** the full snapshot is recorded
- **THEN** the recorded value for that node is masked

#### Scenario: An explicit hidden option can opt a hidden input out of masking
- **GIVEN** browser session replay is recording
- **AND** the type-specific input masking option sets `hidden` to false
- **AND** the page contains `<input type="hidden" value="initial">`
- **WHEN** the full snapshot is recorded
- **THEN** the recorded value for that node is "initial"

#### Scenario: A custom input masking callback receives hidden values
- **GIVEN** browser session replay is recording with broad input masking enabled
- **AND** a custom input masking callback that returns "[masked]"
- **AND** the page contains `<input type="hidden" value="initial">`
- **WHEN** the full snapshot is recorded
- **THEN** the recorded value for that node is "[masked]"
