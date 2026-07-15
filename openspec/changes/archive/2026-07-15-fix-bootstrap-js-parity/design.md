# Design

All five corrections trace to a re-audit of `posthog-js` `main`. Line refs below are the source
of truth; the spec is descriptive of this behavior.

## Flag load: replace vs merge (posthog-featureflags.ts:121-161)

`receivedFeatureFlags` computes the new flag set from the incoming response:

- **complete response** (not `options.partialResponse`, not `response.errorsWhileComputingFlags`):
  `newFeatureFlags = featureFlags` verbatim. The prior cache (bootstrapped or previously loaded)
  is not merged in. So a complete `/flags` **replaces** flags and payloads; bootstrapped-only keys
  and stale bootstrapped payloads are dropped.
- **partial response** (`options.partialResponse`, e.g. survey-only): merge with current so
  previously loaded/bootstrapped flags are preserved.
- **`errorsWhileComputingFlags`**: upsert — merge current with the successfully computed keys
  (v4 filters out `failed` entries), so keys that could not be recomputed keep their prior value.

The earlier spec ("bootstrapped-only keys survive a flags load") described the merge path as if it
applied to complete responses. It does not. This was the most consequential drift and was locked
into an acceptance scenario.

## Bootstrap application is a replace snapshot (posthog-featureflags.ts:316-338)

`initialize()` applies `config.bootstrap.featureFlags` by calling `receivedFeatureFlags` as a
complete response. Per the rule above that **replaces** the served cache, so bootstrap wins over a
persisted cache from a previous session, and it runs on every init while `bootstrap.featureFlags`
is set (not only first install). iOS instead merged bootstrap under the persisted cache
(persisted wins), which is the opposite.

## `$used_bootstrap_value` latch (posthog-featureflags.ts:647, :663, :848)

`this._flagsLoadedFromRemote = !errorsLoading`, where `errorsLoading` is an HTTP/transport-level
flag; `response.json?.errorsWhileComputingFlags` is handled separately (:663) and does not gate
the latch. `$used_bootstrap_value: !this._flagsLoadedFromRemote` (:848) is therefore a global "a
remote response has been received" marker, set after any successful 200 including a partial or
errored one. The spec's "has not yet received a /flags response" was ambiguous about partial
responses; it now states any successful response counts.

## Identity reconciliation (posthog-core.ts:746-793, :2511-2558)

The bootstrap identity block branches on the existing state:

- differing id + existing anonymous -> `identify(bootstrapDistinctId)` (merge).
- differing id + existing identified -> preserve, warn.
- otherwise (the `else`, which includes a matching id and fresh installs) -> `set_property(USER_STATE, isIdentifiedID ? IDENTIFIED : ANONYMOUS)` and `register({ distinct_id, $device_id })`.

So a bootstrap id that **matches** an existing anonymous id still marks the user identified via
the `else` branch. iOS's reconcile guard `getDistinctId() != bootstrapId` returned early, leaving
the user anonymous.

`identify()` (:2511-2558) has no opt-out early return: it registers the distinct id and sets
`USER_STATE_IDENTIFIED` before any capture, so local identity persists while opted out and only the
`$identify` emission is suppressed downstream. iOS's `identify()` bails on `isOptOutState()` before
persisting, so an opted-out user's identified bootstrap was lost.

## Scope

Identity bootstrap remains first-session for the distinct id (never overwrites a persisted
identity — matches the js `existingDistinctId != null` guards). Flag bootstrap is corrected to the
js snapshot-replace model. The `sessionID` requirement is unchanged.
