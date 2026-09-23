## Context

The server identify fallback generates a personless UUID. Legacy capture conveys the person-processing control as `properties.$process_person_profile`; Capture v1 lifts it into the typed `options.process_person_profile` field. The new acceptance assertion currently checks only the legacy field.

## Goals / Non-Goals

**Goals:** Preserve the same personless behavior while specifying and verifying its exact representation on each received transport.

**Non-Goals:** Change SDK production behavior, identity precedence, adapter bindings, or the delivery-mode rollout.

## Decisions

Use one server identify acceptance case and one receiver-side personless assertion. Inspect the actual capture request path and require the exact false boolean in the field defined for that endpoint; fail unknown paths. The adapter neither chooses nor supplies the expected format. Keeping one case tests the shared identity contract, while transport-specific wire assertions prevent a permissive either-field check.

## Risks / Trade-offs

- A new ingestion format requires an explicit assertion branch and a spec update; unknown paths fail visibly instead of being accepted by accident.
