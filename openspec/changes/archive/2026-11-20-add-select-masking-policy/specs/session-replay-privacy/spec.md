## ADDED Requirements

### Requirement: Explicit per-select masking policy

A **per-select masking policy** is an optional application-supplied callback that decides, for one
`<select>` element, whether the identity of its chosen options may be recorded. This requirement
applies to an SDK that records a DOM and offers such a policy; posthog-js browser names it
`session_recording.selectMaskingFn` and types it
`(element: HTMLSelectElement) => 'masked' | 'unmasked'` (posthog-js `origin/main` `7bf3339b7`
`packages/types/src/posthog-config.ts:733`). No SDK is obliged to add the surface. An SDK that
does not offer it keeps the behavior of its input-masking category settings and text-masking
callback unchanged.

The policy SHALL be opt-in and SHALL NOT change recordings while the application supplies no
callback. Supplying one overrides the recorder's select category setting for every select the
policy answers for.

**Decision values.** Only an exact unmasked answer SHALL permit the select's chosen option
identities to be recorded. Every other answer SHALL mask the selection. An invalid return value
and an exception thrown out of the callback SHALL resolve to masked, and the exception SHALL NOT
escape the recorder (posthog-js `packages/rrweb/rrweb-snapshot/src/select-masking.ts:46-50`). This
is the capability's fail-closed rule applied to one element: an SDK that cannot obtain a decision
withholds the data rather than recording it.

**What masking withholds.** A masked select SHALL NOT record selection identity metadata — the
option identifiers or indices that say which options are chosen — and SHALL omit a masked native
rendered-selection clone (`<selectedcontent>`). Its displayed text SHALL be replaced through the
SDK's existing text/input masking callback where one is configured; an application whose callback
returns its input unchanged still records that text, so the callback remains responsible for
sanitizing its own output. Static option labels in the select's markup are not the selection and
remain visible. Pointer events are not covered by the policy: a click on an option in a
listbox-style select (`multiple`, a `size` greater than 1, or a customizable picker) still records
the clicked target and position. An application whose option labels or click targets must stay
private SHALL use an explicit block or mask marker such as `ph-no-capture`, which this policy does
not replace.

**What unmasking permits.** An unmasked select SHALL retain its chosen options, including options
that share a value, so a replay reproduces the exact selection.

**Where the decision is applied.** The SDK SHALL apply the same decision to every capture point
that can reveal the selection: full and incremental snapshots, input events, and mutations within
the select's subtree. The decision SHALL be taken before serialization, under the
mask-before-serialization rule, and the policy SHALL be treated as pure — it is evaluated at each
such capture, so a change in state the callback reads takes effect at the next capture and not
retroactively.

**Recorder support.** Where the recorder is loaded separately from the SDK core, the SDK SHALL
confirm that the loaded recorder and its initializer support the policy before starting a
recording that is configured with one, and SHALL refuse to start and log an error otherwise
(posthog-js `packages/browser/src/extensions/replay/session-recording.ts:405-417`). Starting
without that support would silently record selections the application asked to mask.

**Changing the policy.** Replacing or removing the callback mid-session SHALL NOT apply the new
decision to data captured under the old one: the SDK SHALL restart recording and discard data
still queued under the previous policy (posthog-js
`packages/browser/src/extensions/replay/session-recording.ts:165-168`, `:255-261`). Returning a
different decision from the same stable callback reference needs no restart. An SDK that persists
a pending buffer across page loads SHALL NOT carry that buffer across a load while a policy is
configured, because it cannot verify that the next page's callback is the same one.

#### Scenario: An unmasked select retains its selection
- **GIVEN** browser session replay is recording with a per-select masking policy configured
- **AND** the policy returns unmasked for a select whose chosen options are recorded
- **WHEN** a replay snapshot and an input event are captured for that select
- **THEN** the recorded data identifies the chosen options, including options that share a value

#### Scenario: A masked select omits its selection identity
- **GIVEN** browser session replay is recording with a per-select masking policy configured
- **AND** the policy returns masked for a select whose chosen option is "premium-plan"
- **WHEN** a replay snapshot, an input event, and a mutation in the select's subtree are captured
- **THEN** none of the recorded records identify "premium-plan" as the chosen option
- **AND** a masked rendered-selection clone of that select is not recorded
- **AND** the select's displayed text is replaced through the configured text masking callback

#### Scenario: An invalid decision or a throwing policy masks the select
- **GIVEN** browser session replay is recording with a per-select masking policy configured
- **AND** the policy returns a value that is not the exact unmasked decision, or throws
- **WHEN** a replay snapshot is captured for that select
- **THEN** the select's selection identity is not recorded
- **AND** the exception does not escape the recorder and recording continues

#### Scenario: A recorder without policy support does not start
- **GIVEN** a per-select masking policy is configured
- **AND** the separately loaded replay recorder does not support the policy
- **WHEN** session recording is asked to start
- **THEN** recording does not start
- **AND** the SDK logs an error naming the unsupported policy option
