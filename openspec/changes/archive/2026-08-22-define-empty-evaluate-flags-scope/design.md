## Context

`evaluateFlags` accepts an optional request-time key list, but the current contract only exercises omitted lists and non-empty lists. Four audited SDKs use truthiness or collection length to decide whether filtering is active, so an explicitly empty list broadens to all flags. Node.js keeps the empty scope in the returned snapshot, but it can still perform local-definition work or call `/flags` before filtering every result out.

Callers commonly build key lists dynamically. Treating an empty result as unscoped can unexpectedly evaluate every flag and increase network and server work.

## Goals / Non-Goals

**Goals:**

- Give omitted, empty, and non-empty request-time key lists distinct, testable meanings.
- Make an explicitly empty list a cheap no-op with an empty snapshot and no `/flags` request.
- Preserve the existing non-empty scoped-fallback and local-wins rules.
- Identify the migration required by each audited server SDK.

**Non-Goals:**

- Change in-memory `snapshot.only(keys)` filtering.
- Require every host language to use the same public type for an optional key list.
- Change missing-key negative-knowledge behavior.
- Prevent independently scheduled background definition polling.

## Decisions

### Preserve presence separately from list length

An omitted or null list means no request-time filter, so normal evaluation considers all available flags. A present empty list means the caller requested no keys. A present non-empty list means the caller requested exactly those keys.

This follows collection semantics and avoids turning a dynamically produced empty list into a broad evaluation. Normalizing empty to omitted was rejected because it can silently increase work and billing.

### Short-circuit an explicitly empty scope

The SDK returns a valid empty `FeatureFlagEvaluations` snapshot before consulting evaluated-result caches, running the local evaluator, or calling `/flags`. Independently scheduled definition polling is outside the call and may continue.

Filtering a remote response after requesting it was rejected because the result is correct but the work and billed request are unnecessary. Rejecting an empty list as invalid was also rejected because a no-op composes naturally with dynamically selected keys.

### Use Node.js as the result-shape baseline and strengthen its request behavior

Node.js already returns an empty snapshot for an explicit empty list. The canonical contract keeps that result and adds the missing guarantee that `/flags` is not called. Android, Python, Go, and .NET must also stop treating explicit emptiness as an unscoped request.

## Risks / Trade-offs

- **Breaking behavior for callers that pass an empty list expecting all flags** -> Document that omission or null is the unscoped form and release affected SDK changes under their normal breaking-behavior policy.
- **Some option models cannot distinguish omission from explicit emptiness** -> Adjust the option representation or retain presence metadata at the API boundary before applying defaults.
- **Background definition polling can make network assertions ambiguous** -> Acceptance tests count direct remote feature-flag evaluation requests, not independently scheduled definition refreshes.
