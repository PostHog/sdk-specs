## Context

PostHog's query behavior describes `is_set` as "the property has any value" and treats an explicit database/JSON null as not set. Backend tests at PostHog commit `0530e9b535f` expect null string, numeric, and boolean properties to fail `is_set`, while false and zero remain set.

Current server SDK behavior differs on explicit null evaluation properties:

| Behavior | SDKs and inspected revisions |
|---|---|
| Null is treated as set | Node.js `a816e2f09`, Ruby `8b1e2fe`, Go `5cfdbb4`, PHP `b28a880` |
| Null is treated as not set | Python `b72fed3`, Android server SDK `54553db4`, .NET `b25ea94`, Elixir PR #192 `a68e720` |

All implementations distinguish a missing map key from a present key for at least some operators. The important local-evaluation constraint is that omission from caller-supplied properties does not prove that the property is absent in PostHog, so missing context must remain inconclusive rather than being treated as a definitive `is_set` non-match.

## Goals / Non-Goals

**Goals:**

- Align local `is_set` evaluation with PostHog query and remote evaluation behavior.
- Distinguish explicit null from falsey but valid values.
- Preserve remote fallback when caller-supplied evaluation context omits the property.
- Document the current SDK split for targeted follow-up work.

**Non-Goals:**

- Redefine storage, ingestion, or property-unset behavior.
- Require SDKs to infer stored PostHog properties that are absent from request-time evaluation context.
- Change equality, `is_not`, or other property operators.
- Standardize language-specific representations beyond each SDK's JSON null equivalent.

## Decisions

### Explicit null means not set

An `is_set` filter matches only a present non-null property value. This follows PostHog query behavior and the user-facing description that the property must have a value, rather than relying only on container key presence.

The alternative was key-presence semantics, as currently used by Node.js, Ruby, Go, and PHP. That approach is easy to implement with map membership, but it lets local evaluation enable a flag that remote evaluation would not enable for the same explicit null value.

### Falsey non-null values remain set

Boolean false, numeric zero, empty strings, and empty collections are values. SDKs must not use generic truthiness for `is_set` because that would incorrectly classify these values as absent.

### Missing request context remains inconclusive

When a property key is omitted from caller-supplied local evaluation properties, the evaluator cannot know whether PostHog has a stored value. It must produce the existing inconclusive/requires-server signal. Explicit null is different because the caller supplied a value override and local evaluation can make a definitive non-match.

### Acceptance tests cover the semantic boundary

The canonical acceptance case will distinguish absent, null, and representative falsey values. SDK-specific unit tests should cover the host language's null sentinel and collection types.

## Risks / Trade-offs

- [Affected SDKs can change a flag from enabled to disabled for explicit null overrides] → Release as a documented correctness fix and add regression tests before changing each SDK.
- [Some SDK APIs erase the difference between omitted and null properties] → Treat the case as inconclusive unless the SDK can prove that an explicit null was supplied.
- [Legacy materialized PostHog columns have historical empty-string differences] → Define the SDK contract around current remote/query semantics and non-null values rather than reproducing storage-specific legacy behavior.
- [Cross-SDK acceptance adapters may not yet express explicit null property values] → Extend the shared acceptance vocabulary before requiring implementation PRs.
