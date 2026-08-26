## Context

PostHog has two superficially similar `is_set` behaviors. Analytics property queries treat an explicit database/JSON null as not set, while the feature-flags service uses property-key presence for request-time override matching. Local SDK feature flag evaluation must match the flags-service runtime, not analytics query semantics.

At PostHog commit `005ade15f27`, `rust/feature-flags/src/properties/property_matching.rs` implements `is_set` with `matching_property_values.contains_key(key)` and explicitly tests that a present JSON null matches. The same matcher distinguishes partial from complete property context for `is_not_set`: a present key definitively does not match, a missing key in partial context is inconclusive, and a missing key matches only when the context is known to be complete.

Current server SDK behavior differs on explicit null evaluation properties:

| Behavior | SDKs and inspected revisions |
|---|---|
| Null is treated as set | Node.js `94ed3f09b`, Ruby `8b1e2fe`, Go `5cfdbb4`, PHP `b28a880`, Rust `8a186c9`, pending Elixir PR #192 (`089ae9e`) |
| Null is treated as not set | Python `5eb886d`, Android server SDK `54553db4`, .NET `b25ea94` |

The same implementations also disagree on `is_not_set`:

| Present property | Missing property | SDKs and inspected revisions |
|---|---|---|
| Does not match | Inconclusive | Pending Elixir PR #192 (`089ae9e`) |
| Inconclusive | Inconclusive | Python `5eb886d`, Go `5cfdbb4`, PHP `b28a880`, Ruby `8b1e2fe`, Android server SDK `54553db4`, .NET `b25ea94` |
| Does not match | Matches | Node.js `94ed3f09b`, Rust `8a186c9` |

All implementations distinguish a missing map key from a present key for at least some operators. The important local-evaluation constraint is that omission from caller-supplied properties does not prove that the property is absent in PostHog. Missing context must therefore remain inconclusive for both presence operators rather than being treated as a definitive `is_set` non-match or `is_not_set` match.

## Goals / Non-Goals

**Goals:**

- Align local `is_set` and `is_not_set` evaluation with the authoritative flags-service runtime's partial-property behavior.
- Distinguish a present null from an omitted property key.
- Preserve remote fallback when caller-supplied evaluation context omits the property.
- Make a present property definitively fail `is_not_set` without remote fallback.
- Document the current SDK split for targeted follow-up work.

**Non-Goals:**

- Redefine analytics query, storage, ingestion, or property-unset behavior.
- Require SDKs to infer stored PostHog properties that are absent from request-time evaluation context.
- Define an SDK evaluation option or `/flags` request field for callers to assert that a property is known to be absent.
- Change equality, `is_not`, or other non-presence property operators.
- Standardize language-specific representations beyond each SDK's JSON null equivalent.

## Decisions

### Explicit null counts as set

An `is_set` filter matches whenever the property key is present, including when its value is explicit null. This follows the flags-service runtime and prevents a definitive local non-match from disagreeing with remote flag evaluation.

The alternative was value-presence semantics, as currently used by Python, Android, and .NET. That matches analytics query behavior but not request-time override matching in the flags service.

### Every present falsey value remains set

Null, boolean false, numeric zero, empty strings, and empty collections all have a present property key. SDKs must check membership rather than generic truthiness or non-nullness.

### Missing request context remains inconclusive

When a property key is omitted from caller-supplied local evaluation properties, the evaluator cannot know whether PostHog has a stored value. Both `is_set` and `is_not_set` must produce the existing inconclusive/requires-server signal. Explicit null is different because the caller supplied the key and local evaluation can make a definitive presence decision.

### is_not_set follows partial-property semantics

When the property key is present, `is_not_set` definitively does not match, including for null and other falsey values. A missing key remains inconclusive because SDK property maps are partial and do not prove absence. This mirrors the flags service with `partial_props` enabled. Matching `is_not_set` for a missing key requires complete property context or a future explicit known-absence input.

### Acceptance tests cover the semantic boundary

The canonical acceptance cases distinguish absent, null, and representative falsey values for both `is_set` and `is_not_set`. SDK-specific unit tests should cover the host language's null sentinel and collection types.

## Risks / Trade-offs

- [Affected SDKs can change a flag from disabled to enabled for explicit null overrides] → Release as a documented flags-service parity fix and add regression tests before changing each SDK.
- [Node.js and Rust currently match `is_not_set` when a property is omitted] → Change missing partial context to inconclusive so local evaluation cannot contradict stored PostHog properties.
- [Other server SDKs currently leave `is_not_set` inconclusive even when a property is present] → Let present properties definitively fail the filter, using Elixir PR #192 as the reference implementation.
- [Some SDK APIs erase the difference between omitted and null properties] → Treat the case as inconclusive unless the SDK can prove that the key was explicitly supplied.
- [Analytics queries use different null semantics] → State explicitly that this capability governs local feature flag evaluation against request-time property overrides.
- [Cross-SDK acceptance adapters may not yet express explicit null property values] → Extend the shared acceptance vocabulary before requiring implementation PRs.
