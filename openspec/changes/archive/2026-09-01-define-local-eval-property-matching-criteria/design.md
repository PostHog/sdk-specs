## Context

The merged equality and string-search requirements define part of local feature-flag property matching. The remaining operator families and result boundaries were not specified consistently across server SDKs.

The reference audit used PostHog `master` at `55be8f3f6a949ac5588d55e135c5da037a936cd0` and compared the Node, Python, Go, Ruby/Rails, PHP, Java, .NET, and Rust local evaluators. Elixir has no local-definitions evaluator and remains excluded.

## Goals / Non-Goals

**Goals:**

- Define observable condition and property-matching behavior for local feature-flag evaluation.
- Publish one scoped operator inventory with consistent operand direction and aliases.
- Preserve three evaluator outcomes: match, definitive no-match, and inconclusive/remote fallback.
- Specify portable behavior for regex, numbers, dates, semantic versions, and cohorts.
- Provide table-driven acceptance vectors for server-side SDK local evaluators.

**Non-Goals:**

- Modify SDK or backend implementations.
- Define event-property querying outside feature-flag evaluation.
- Standardize backend loading, cache, typed decoding, tracing, or parser implementation details.
- Reproduce direct feature-flag API validation rules or require support for definitions outside the local-definition contract.
- Make Elixir implement local evaluation.

## Decisions

### 1. Keep the contract platform-neutral

Requirements describe values received by local evaluation and the result visible to callers. They do not prescribe backend cache formats, decoder architecture, parser libraries, or internal evaluation metadata.

### 2. Preserve match, no-match, and inconclusive results

Missing local context is inconclusive. A present property that cannot be interpreted by an otherwise valid criterion is a definitive no-match. A malformed condition is inconclusive unless an operator requirement defines a safe result. Negative operators invert only a valid comparison and never turn unavailable context or parser failure into a match.

### 3. Publish one scoped operator inventory

The inventory separates ordinary person/group property operators from dynamic-cohort ranges, cohort membership, and flag dependencies. The `min` and `max` wire aliases behave as `gte` and `lte`.

### 4. Extend the merged equality and string-search baseline narrowly

The merged stringification and equality requirements remain authoritative. This change adds multi-contains behavior and confirms that contains, prefix, suffix, and multi-contains use ASCII lowercase. Multi-contains evaluates an array of condition values with ANY semantics.

### 5. Bound regex portability

Regex operators perform case-sensitive search without implicit anchors. Invalid syntax does not match either polarity. Syntax unsupported by a target SDK or execution failure is inconclusive and cannot escape as an application exception.

### 6. Use finite binary64 numeric comparison

Numeric ordering accepts string conditions and string or JSON-number properties, parses complete untrimmed decimals as finite IEEE-754 binary64 values, and does not fall back to lexicographic comparison. Cohort ranges accept numeric or numeric-string bounds, are inclusive, and validate both bounds before applying negation.

### 7. Interpret dates in the effective timezone

Absolute dates use a bounded portable grammar and integral Unix-second values. Explicit offsets are honored, while naive values use the effective project/team timezone and fall back to UTC when it is unavailable. Relative dates subtract on the effective timezone's local wall clock. DST overlaps choose the earlier instant; gaps are inconclusive. Month and year subtraction clamps after each step.

### 8. Define semantic-version behavior without prescribing a parser library

Direct comparisons normalize supported prefixes, omitted components, and leading zeros before applying the documented precedence and build-metadata rules. Tilde, caret, and wildcard operators use their standard range boundaries. Range matching ignores build metadata and admits prereleases only for a comparator with the same core version.

### 9. Use three-valued cohort composition

Dynamic cohort groups preserve true, false, and inconclusive results. A conclusive true dominates OR; a conclusive false dominates AND. The legacy group type `property` aliases AND. Negation applies only to a conclusive leaf result. Cycles and unsupported or malformed cohort criteria are inconclusive and do not crash application code.

### 10. Use tables as conformance vectors

The canonical spec and private acceptance feature use scenario outlines for operator defaults, result states, equality, strings, regex, numeric comparison and ranges, dates, semantic versions, and cohorts. The vectors focus on observable SDK behavior rather than backend implementation structure.

## Risks / Trade-offs

- Existing SDKs will fail some vectors; those failures become explicit parity work.
- Exact JSON number spelling cannot be recovered after a host runtime collapses numeric kinds. Such SDKs use safe fallback when available and document deterministic limitations otherwise.
- Regex syntax is not portable across all SDK engines. Unsupported constructs fall back remotely rather than producing a false local answer.
- Team timezone is not available in every local-definition integration. UTC fallback remains deterministic but can differ from remote evaluation.
