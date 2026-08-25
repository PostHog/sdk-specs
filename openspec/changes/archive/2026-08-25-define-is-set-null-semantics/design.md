## Context

PostHog has two superficially similar `is_set` behaviors. Analytics property queries treat an explicit database/JSON null as not set, while the feature-flags service uses property-key presence for request-time override matching. Local SDK feature flag evaluation must match the flags-service runtime, not analytics query semantics.

At PostHog commit `0530e9b535f`, `rust/feature-flags/src/properties/property_matching.rs` implements `is_set` with `matching_property_values.contains_key(key)` and explicitly tests that a present JSON null matches.

Current server SDK behavior differs on explicit null evaluation properties:

| Behavior | SDKs and inspected revisions |
|---|---|
| Null is treated as set | Node.js `a816e2f09`, Ruby `8b1e2fe`, Go `5cfdbb4`, PHP `b28a880`, pending Elixir PR #192 |
| Null is treated as not set | Python `b72fed3`, Android server SDK `54553db4`, .NET `b25ea94` |

All implementations distinguish a missing map key from a present key for at least some operators. The important local-evaluation constraint is that omission from caller-supplied properties does not prove that the property is absent in PostHog, so missing context must remain inconclusive rather than being treated as a definitive `is_set` non-match.

## Goals / Non-Goals

**Goals:**

- Align local `is_set` evaluation with the authoritative flags-service runtime.
- Distinguish a present null from an omitted property key.
- Preserve remote fallback when caller-supplied evaluation context omits the property.
- Document the current SDK split for targeted follow-up work.

**Non-Goals:**

- Redefine analytics query, storage, ingestion, or property-unset behavior.
- Require SDKs to infer stored PostHog properties that are absent from request-time evaluation context.
- Define an SDK evaluation option or `/flags` request field for callers to assert that a property is known to be absent.
- Change equality, `is_not`, or other property operators.
- Standardize language-specific representations beyond each SDK's JSON null equivalent.

## Decisions

### Explicit null counts as set

An `is_set` filter matches whenever the property key is present, including when its value is explicit null. This follows the flags-service runtime and prevents a definitive local non-match from disagreeing with remote flag evaluation.

The alternative was value-presence semantics, as currently used by Python, Android, and .NET. That matches analytics query behavior but not request-time override matching in the flags service.

### Every present falsey value remains set

Null, boolean false, numeric zero, empty strings, and empty collections all have a present property key. SDKs must check membership rather than generic truthiness or non-nullness.

### Missing request context remains inconclusive

When a property key is omitted from caller-supplied local evaluation properties, the evaluator cannot know whether PostHog has a stored value. It must produce the existing inconclusive/requires-server signal. Explicit null is different because the caller supplied the key and local evaluation can make a definitive match.

### Acceptance tests cover the semantic boundary

The canonical acceptance case will distinguish absent, null, and representative falsey values. SDK-specific unit tests should cover the host language's null sentinel and collection types.

## Risks / Trade-offs

- [Affected SDKs can change a flag from disabled to enabled for explicit null overrides] → Release as a documented flags-service parity fix and add regression tests before changing each SDK.
- [Some SDK APIs erase the difference between omitted and null properties] → Treat the case as inconclusive unless the SDK can prove that the key was explicitly supplied.
- [Analytics queries use different null semantics] → State explicitly that this capability governs local feature flag evaluation against request-time property overrides.
- [Cross-SDK acceptance adapters may not yet express explicit null property values] → Extend the shared acceptance vocabulary before requiring implementation PRs.
