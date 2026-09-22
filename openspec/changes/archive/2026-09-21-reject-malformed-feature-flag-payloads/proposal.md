## Why

The payload spec currently calls parse failures “missing/unparsed payloads,” leaving raw-string fallback ambiguous. [Python PR #947's review](https://github.com/PostHog/posthog-python/pull/947#pullrequestreview-5265006317) explicitly selects `None` for malformed JSON and highlights empty-string inconsistencies between single and bulk APIs.

## What Changes

- Require malformed serialized payloads, including empty and whitespace-only input, to resolve to the language's no-payload value, never the raw string.
- Preserve valid JSON values, including quoted strings, empty strings, `false`, `0`, and `null`.
- Preserve flag evaluation results and healthy sibling payloads when payload decoding fails.
- Require equivalent handling for cached, locally evaluated, and remotely evaluated payloads in single and bulk APIs.
- **BREAKING** for SDKs that currently expose malformed payloads as raw strings, and for getters whose public API returns serialized strings for valid payloads instead of decoded JSON values. This includes the deprecated Go `GetFeatureFlagPayload` API and requires a return-type migration decision in that SDK.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `get-feature-flag-payload`: Define the shared serialized-payload decoding contract.
- `get-feature-flag-result`: Preserve structured flag results while treating malformed payloads as absent.
- `get-feature-flags-and-payloads`: Apply the same absent-payload semantics in bulk without discarding valid flag values or sibling payloads.

## Impact

Spec and acceptance documentation only; no SDK implementation changes in this repository. Follow-up SDK conformance work may be needed.

## Non-goals

Changing evaluation, network fallback, or tracking; fixing the Python PR or resolving its review threads. Valid-payload return types may need to change for serialized-string getter APIs to meet this contract.
