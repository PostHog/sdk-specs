## Why

sdk-specs#190 (change `2026-11-05-mcp-payload-personal-data`) made every SDK run a pattern-based personal data pass over tool arguments, results, error text and exception values by default. Building the reference port (posthog-js#5603) showed the cost. Six adversarial review rounds kept finding new cases: JSON escapes, card-shaped numbers, window cuts, URL boundaries. Each fix added machinery, and every rule had to be reproduced exactly in five SDKs with no acceptance suite running to catch drift.

The data in question is what the server's own tools received and returned. The host already holds it, and the SDK relays what the customer's server sees. Hosts that must not send it already have parameter capture, response capture and the before-send hook. Common practice for agent telemetry keeps pattern-based scrubbing out of SDKs, and where it is needed it runs in the backend, configurable in one place. A server-side scrubber can be added if demand shows up, with no SDK release.

## What Changes

- **Payload privacy**: the payload personal data pass is removed. A new rule says the personal data pass does not apply to `$mcp_parameters`, `$mcp_response`, `$mcp_error_message` or `$exception` values, which are relayed as captured after the credential passes. New scenario: personal data in tool payloads is relayed, and intent stays redacted.
- **Configuration**: the `payload personal data` row is removed.
- **Acceptance**: the four payload scenarios from #190 are removed.
- **Kept from #190**:
  - `$mcp_feedback_<name>` JSON text is sanitized as free text.
  - The corrected reason in "Optional events".

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Payload privacy** requirement, and the Configuration table.

## Impact

- No SDK implemented the payload pass, so no SDK behavior changes. posthog-js#5603 is closed.
- `$mcp_input_keys` counts only names the PostHog token or URL pass would change, as before #190.
