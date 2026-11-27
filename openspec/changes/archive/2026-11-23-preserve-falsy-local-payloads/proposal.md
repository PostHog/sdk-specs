## Why

`evaluate-flags` pins that a snapshot payload "is not coerced by truthiness" only in the
**Remote scalar payload reads preserve type and decoding boundaries** scenario. Nothing in
**Snapshot payload access** says the same for a flag resolved from loaded local definitions, so the
contract is silent exactly where SDKs get it wrong.

posthog-node got it wrong:
[posthog-js#5817](https://github.com/PostHog/posthog-js/pull/5817) (`posthog-js#5814`) fixes
`FeatureFlagsPoller.getAllFlagsAndPayloads`, which kept a payload only `if (matchPayload)`, so
`evaluateFlags(...).getFlagPayload(key)` returned nothing for payloads of `0`, `false` or `""`. The
single-flag local path (`getFeatureFlagResult(..., { onlyEvaluateLocally: true })`) returned them,
so the two paths disagreed for the same flag.

The spec needs updating because a reader checking an SDK against **Snapshot payload access** today
finds no requirement the old behavior violated, and nothing stops another SDK's bulk local
enumeration from dropping the same payloads.

## What Changes

- `evaluate-flags`: **Snapshot payload access** states that payload presence is decided by whether
  the source supplied a payload, never by truthiness, that `false`, `0`, an empty string, `[]` and
  `{}` are present payloads, and that a locally resolved flag keeps them, including when the
  snapshot is built by enumerating every locally evaluated flag.
- `evaluate-flags`: a new scenario outline covers falsy payloads from local and remote evaluation,
  alongside the existing malformed-JSON outline.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `evaluate-flags`: **Snapshot payload access** gains the truthiness rule and a falsy-payload
  scenario outline.

## Impact

- **posthog-node**: matches as of posthog-js#5817; the single-flag local path already did.
- Other SDKs with local evaluation and a bulk payload path (posthog-python, posthog-go,
  posthog-php, posthog-ruby, posthog-dotnet, posthog-elixir, posthog-rs) are unaudited for this
  requirement. It constrains behavior they are expected to have already.
- Deliberately silent on an explicit JSON `null` payload: SDKs differ on whether `null` means an
  absent payload or a present one, and the existing remote scenario outline keeps a `null` row.
  Nothing here changes how `null` is handled.
