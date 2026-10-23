## Why

Six SDKs independently fixed the same bug in the same week: an event property holding a non-finite floating-point number (NaN, +Infinity, -Infinity) produced a payload that ingestion rejected, or that the SDK itself refused to serialize, so the event — and in several SDKs the whole batch around it — was lost.

The failure mode differed per language, but the cause is shared: JSON has no representation for these values, and each SDK's default encoder did something unusable with them.

| SDK | PR | Previous behavior |
|---|---|---|
| posthog-python | [#1081](https://github.com/PostHog/posthog-python/pull/1081) | emitted the bare tokens `NaN` / `Infinity`, which strict parsers reject, losing the batch |
| posthog-ruby | [#315](https://github.com/PostHog/posthog-ruby/pull/315) | events lost during serialization, including nested values |
| posthog-dotnet | [#348](https://github.com/PostHog/posthog-dotnet/pull/348) | the selected batch failed to serialize, taking healthy neighboring events with it |
| posthog-unity | [#150](https://github.com/PostHog/posthog-unity/pull/150) | invalid JSON in the queue; reload truncated following properties or stalled |
| posthog-godot | [#1](https://github.com/PostHog/posthog-godot/pull/1) | the whole event was dropped at strict admission |
| posthog-flutter | [#656](https://github.com/PostHog/posthog-flutter/pull/656) | desktop sent the strings `"NaN"` / `"Infinity"` / `"-Infinity"` |

posthog-js never had the bug: `JSON.stringify` already turns a non-finite number into `null`.

Four of those PRs say in their own description that the shared capture, HTTP-client and event-batcher specs do not prescribe a policy here, so each SDK had to pick one. They converged, which is the point — but nothing in this repo holds the line for the next SDK or the next port.

## What Changes

- A new `capture` requirement, **Capture normalizes non-finite numeric property values**: non-finite numbers SHALL be replaced with JSON `null`, SHALL NOT appear as bare `NaN`/`Infinity` tokens or as strings, and SHALL NOT cost the event, its batch, or a neighboring event. Recursive into nested objects and arrays; array slots keep their index; caller containers are not mutated; the rule holds for queued and immediate capture, after `before_send`, and on every disk serialization.
- The requirement deliberately leaves **one** point open: whether an object member whose value normalized to `null` is then serialized as a null member or omitted by the existing null-member cleanup. The SDKs genuinely diverge there and the answer interacts with **Capture drops null-valued object properties**, so this change records the divergence instead of picking a winner.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: new **Capture normalizes non-finite numeric property values** requirement.

## Impact

- **posthog-python**, **posthog-ruby**, **posthog-dotnet**, **posthog-unity**, **posthog-godot**, **posthog-flutter** (desktop): already conform after the PRs above.
- **posthog-js**: already conforms through `JSON.stringify`.
- **posthog-ios**, **posthog-android**, **posthog-go**, **posthog-php**, **posthog-elixir**, **posthog-rs**, **posthog-java**, **posthog-kmp**: not audited for this change. Per repo convention, SDK conformance is not a prerequisite for archiving the spec change.
- **Acceptance adapters**: no feature-file scenarios added. The existing capture steps carry properties as a JSON document string, and JSON cannot express NaN or infinity, so executable coverage needs a new step vocabulary. Out of scope here.
