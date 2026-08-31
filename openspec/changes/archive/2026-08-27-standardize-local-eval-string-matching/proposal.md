## Why

Local feature-flag evaluators currently disagree with the `/flags` service on case-insensitive property matching, so the same flag and properties can produce different results locally and remotely. The existing contract specifies ASCII-only prefix/suffix matching but leaves `icontains`, `exact`/`is_not`, and value stringification incomplete, allowing implementations to choose incompatible Unicode comparison APIs.

## What Changes

- Define the backend-compatible, operator-specific case normalization contract: ASCII lowercase for the contains/prefix/suffix families and Unicode lowercase for `exact`/`is_not`.
- Define the released backend's boolean-like gate before stringification or filter-array membership, including aggregate boolean arrays and vacuously truthy empty arrays.
- Define conditional ANY/NONE semantics for non-boolean-like `exact`/`is_not` filter arrays.
- Define canonical `serde_json` stringification, including compact composites, sorted object keys, finite-number spellings, and runtimes that cannot preserve distinct numeric kinds.
- Add Unicode discriminator scenarios for Rust-compatible full lowercase, including contextual final sigma and dotted-I expansion.
- Preserve existing missing-property inconclusive behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Specify complete string/equality property-filter matching semantics compatible with the Rust flags service.

## Impact

This changes the normative local-evaluation contract used by server-side SDK implementations and their conformance tests. It does not change the public feature-flag API or the released flags-service backend; SDK matchers must align with the existing backend behavior described in PostHog/posthog#78019. [PostHog/posthog#90694](https://github.com/PostHog/posthog/pull/90694) separately proposes replacing the surprising boolean and empty-array behavior.
