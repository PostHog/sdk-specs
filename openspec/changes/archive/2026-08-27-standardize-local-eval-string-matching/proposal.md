## Why

Local feature-flag evaluators currently disagree with the `/flags` service on case-insensitive property matching, so the same flag and properties can produce different results locally and remotely. The existing contract specifies ASCII-only prefix/suffix matching but leaves `icontains`, `exact`/`is_not`, and value stringification incomplete, allowing implementations to choose incompatible Unicode comparison APIs.

## What Changes

- Define the backend-compatible, operator-specific case normalization contract: ASCII lowercase for the contains/prefix/suffix families and Unicode lowercase for `exact`/`is_not`.
- Require stringify-first equality and define ANY/NONE semantics for `exact`/`is_not` filter arrays.
- Define the JSON lexical stringification model used by the flags service, including the distinction between `323` and `323.0`, while acknowledging runtimes that cannot preserve that distinction in host values.
- Add Unicode discriminator scenarios that distinguish lowercase normalization from Unicode casefold/equivalence.
- Preserve existing missing-property inconclusive behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Specify complete string/equality property-filter matching semantics compatible with the Rust flags service.

## Impact

This changes the normative local-evaluation contract used by server-side SDK implementations and their conformance tests. It does not change the public feature-flag API or the flags-service backend; SDK matchers must align with the existing backend behavior described in PostHog/posthog#78019.
