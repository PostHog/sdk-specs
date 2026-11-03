## Context

This change is a canonical specification correction for server applicability, followed by acceptance-test and adapter work. Node's public `captureException(error, distinctId?, additionalProperties?, uuid?, flags?)` already produces a handled `$exception` through its normal pipeline. Its implementation registers exception normalization as a pending promise, so public flush must remain responsible for waiting and delivery.

The follow-up branches start at the existing group-identify heads:

| Repository | Branch | Parent |
| --- | --- | --- |
| sdk-specs | `test/capture-exception-delivery` | `test/group-identify-delivery` at `69be743` |
| harness | `feat/capture-exception-delivery` | `feat/group-identify-delivery` at `5a08d72` |
| posthog-js | `test/node-capture-exception-compliance` | `test/node-group-identify-compliance` at `5ddadc79d` |

sdk-specs #103 at `9b501e8` makes the structured exception list authoritative. Use that shape for new received-event assertions and retain the correction when refreshing against the eventual merged spec.

### Audited surfaces

- **Node:** `packages/node/src/client.ts:3120` exposes manual capture with an optional distinct ID and caller properties. `packages/node/src/extensions/error-tracking/index.ts:46` builds the event from the core exception builder. `packages/core/src/error-tracking/error-properties-builder.ts:41` defaults to `mechanism.handled = true` and produces `$exception_list` and `$exception_level`. No production change is proposed for the selected cases; end-to-end conformance still needs validation.
- **PHP:** `lib/Client.php:428` exposes `captureException(Throwable|string, ?string, array): bool`, builds `$exception_list`, and forwards optional caller identity through capture. It also demonstrates that the client-only applicability statement omits an existing server surface. PHP execution is outside this batch.

The observable correction is to recognize server APIs and assert their delivered events, rather than add an exception API or normalization behavior to SDKs.

## Goals / Non-Goals

**Goals:**

- Observe one handled exception event after a public capture and flush.
- Check caller identity, primary type/message, handled state, native stack frames, and scalar/nested caller properties.
- Preserve existing legacy scenarios and keep fixture construction separate from SDK event construction.
- Verify the newly opted-in cases through a freshly built Node SDK in CJS/ESM and capture v0/v1.

**Non-Goals:**

- Automatic fatal-error handling, terminating subprocesses, persisted crashes, next-launch reconstruction, and breadcrumbs are separate lifecycle behavior.
- This batch does not change SDK production code or promise comprehensive exception-envelope conformance.
- Release and CI pin advancement remain a separate rollout.

## Decisions

### Correct applicability without prescribing one server signature

Set applicability to client and server SDKs exposing manual exception capture. Document Node's existing positional server signature as a surface variant. The supplied distinct ID selects the event identity; SDKs with ambient identity retain their existing public signature.

### Observe delivery in the existing feature

Add two ordinary scenarios to `acceptance/public/capture-exception.feature`. Move its current Background into each legacy scenario and retain legacy applicability tags on those scenarios. New scenarios use only an isolated instance, public initialization, a public operation, public flush, and the mock receiver.

The first scenario uses a native `TypeError("boom")`, distinct ID `exception-user`, and these properties:

```json
{"area":"checkout","retryable":false,"attempt":0,"context":{"operation":"charge","codes":[1,2],"success":false}}
```

The second uses `TypeError("boom without properties")`, distinct ID `exception-user-no-properties`, and omits the properties argument. Both check exactly one request and one parsed event, event name, identity, structured type/message, handled state, and nonempty stack frames. The first also checks the supplied properties with type-sensitive JSON equality.

### Make the RPC descriptor a native exception fixture

Add a shared step, `capture exception is called with JSON arguments:`, invoking `/capture_exception` with its JSON unchanged. The initial route shape is:

```json
{
  "error":{"type":"TypeError","message":"boom"},
  "distinct_id":"exception-user",
  "properties":{"area":"checkout"}
}
```

The `error` descriptor denotes a native test exception, not an SDK exception payload. The Node adapter supports the selected TypeError fixture using the native constructor and preserves the generated stack. It passes the native object, distinct ID, and properties directly to `client.captureException()`, preserving omitted optional arguments. Unsupported fixture descriptors are visible harness binding failures; native SDK results and exceptions retain the existing completion classification.

Constructing a native fixture is necessary because JSON cannot carry a JavaScript Error object. Passing the descriptor itself to the SDK would exercise plain-object coercion instead of the native-error path.

### Keep assertions on received data

Reuse request/event count, event field, and JSON property assertions. Add focused received-envelope assertions for primary type/message, handled state, and nonempty stack frames. Their source is `properties.$exception_list[0]` on the receiver's event; they do not use queue controls or rewrite payloads.

Controlled hosts must demonstrate failure for dropped, duplicated, wrongly named, or misidentified events; changed or missing properties; a missing/empty exception list; wrong type/message; non-boolean handled state; and missing/empty stacks. Profile mismatch and missing route remain visible and distinct from SDK failures.

## Risks / Trade-offs

- **Incoming #103 edits overlap the existing handled-exception scenario.** Retain its structured-summary correction when refreshing the follow-up branch; do not reproduce its archived change or PHP compliance audit.
- **Native stack details vary by runtime and build mode.** Assert a nonempty frame list, not absolute file paths or synthetic fixture frame strings. Existing frame-ordering and stack-preservation scenarios remain intact.
- **Exception normalization is asynchronous.** Exercise the SDK's public flush barrier rather than wait on a harness-owned queue or sleep.
- **Optional public parameters differ between SDKs.** Advertise only the route and fixtures actually supported by each adapter; preserve the Node native method's result and argument omission.

## Migration Plan

Implement and validate the checkout-based specs, harness, and Node adapter together. Run controlled hosts, then a source-built Node consumer in all four configurations. Only then opt the new scenarios in with `@sdk:server` and verify whole-suite selection.

Apply and archive the spec change on this same branch before opening its PR. Once the follow-up commits exist, use `gh stack` to track them above each repository's group-identify PR, and link cross-repository dependencies. Pin changes and publication follow the separately approved release sequence after specs squash-merge.

If runtime validation exposes a production SDK divergence, report it and obtain a separate scoped decision rather than changing the acceptance contract to match it.
