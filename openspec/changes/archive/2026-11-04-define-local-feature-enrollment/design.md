## Context

This is a canonical specification correction for SDKs that evaluate downloaded flag definitions. The flags service already makes enrollment a person-level decision before holdouts and release conditions.

Pinned sources:

- [Backend matcher](https://github.com/PostHog/posthog/blob/87025e064dc64f67c56e7569ffd897501c7e3791/rust/feature-flags/src/flags/flag_matching.rs#L1723-L1741): reads person enrollment first and immediately returns its boolean result.
- [Backend helpers](https://github.com/PostHog/posthog/blob/87025e064dc64f67c56e7569ffd897501c7e3791/rust/feature-flags/src/flags/flag_filters.rs#L75-L97): only boolean true and string `"true"` enroll; an absent request override requires database properties.
- [Backend enrollment documentation](https://github.com/PostHog/posthog/blob/87025e064dc64f67c56e7569ffd897501c7e3791/docs/internal/feature-flags/feature-enrollment.md): request overrides precede stored properties; group and multivariate early-access links are not supported by the creation API.
- [Python correction](https://github.com/PostHog/posthog-python/blob/fffef4d465e3426e1e34623d3ea73d78aaf1e037/posthog/feature_flags.py#L495-L508), merged in [#1176](https://github.com/PostHog/posthog-python/pull/1176): recognizes enrollment and defers when caller context cannot decide it.
- [Node evaluator](https://github.com/PostHog/posthog-js/blob/69814c77c675918a658e8dad4a02dfdb152398e4/packages/node/src/extensions/feature-flags/feature-flags.ts#L605-L625) and [Ruby evaluator](https://github.com/PostHog/posthog-ruby/blob/f312cbc8648d5ac4d1ff9254e8bc3c189de6d4c3/lib/posthog/feature_flags.rb#L492-L534): proceed directly to holdouts or release conditions without recognizing enrollment. Both need separate implementation changes to reach this contract.

## Goals / Non-Goals

**Goals:** Make single, bulk, and dependency evaluation agree with the service for known enrollment, and defer rather than inventing stored state when context is unavailable.

**Non-Goals:** Implement SDK evaluators, add public APIs, enable group-based early-access feature creation, or change the remote flags protocol.

## Decisions

1. Use exact JSON values, not host-language truthiness or case-insensitive property matching. Boolean true and string `"true"` enroll; other present values, including null and numeric one, opt out.
2. Keep the inactive-flag check. Enrollment then decides before holdouts and conditions, matching the service rather than inheriting the peers' missing implementation.
3. Treat an omitted caller property as unavailable context. The service can consult stored person properties; an SDK cannot infer stored absence from a partial map. Existing remote fallback or local-only unresolved behavior is the appropriate result. Missing enrollment contributes a missing-context cause without replacing the existing precedence of other unresolved causes.
4. Preserve person context across aggregation. A local evaluator may defer an unsupported group definition, but must not mistake a group's enrollment for the person's. The defensive group scenario does not imply that the early-access creation API supports group flags.
5. Put the requirements in the existing local-evaluator capability. Definition loading already preserves complete definitions; no new loader API or parallel evaluator is needed.
6. Use existing black-box harness steps to serve typed definitions over HTTP, call public getters/snapshot accessors, and observe remote requests. The dedicated feature covers the new enrollment behavior without duplicating existing targeting scenarios.

## Validation

The Gherkin targets the [step catalogue](https://github.com/PostHog/posthog-sdk-test-harness/blob/75fb00092c6045daef60c30acc10ac83afefbfe9/docs/gherkin-steps.md) at harness `75fb00092c6045daef60c30acc10ac83afefbfe9`. Discovery checks all expanded cases for registered step bindings. SDK execution and integration opt-in are separate from discovery.

Cases cover both enrolled values, nine non-enrolled values, enrollment before holdouts, inactivity, absent/null/false markers, bulk and dependent values, local-only omission, remote fallback, and conflicting person/group context. The missing-context snapshot also resolves an ordinary control flag, so an unloaded definition set cannot satisfy its assertions. Public snapshot reasons and their precedence remain specified in OpenSpec; the current snapshot-read harness route exposes values and key enumeration, not unresolved-reason accessors.

Run strict OpenSpec validation before and after archive, harness discovery with `--require-ready`, and `git diff --check`. These checks validate the specification and harness bindings, not cross-SDK conformance.

## Risks / Trade-offs

- Correcting assignments changes behavior for people whose enrollment was previously ignored. The requirement follows the service's existing rule, and separate SDK fixes should include base/head regression tests.
- Omitting enrollment context can add a remote request where an SDK previously returned a local targeting result. Passing the enrollment property allows a local decision; local-only evaluation remains remote-free.
- Node and Ruby are known implementation gaps at the pinned revisions. Other local evaluators were not audited by this change.
