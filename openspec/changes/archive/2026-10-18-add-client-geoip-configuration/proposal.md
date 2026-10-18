## Why

The specs describe GeoIP control only as a per-call option: `capture`, `identify`, `alias`,
`group-identify`, and the flag-evaluation specs all list a `disable_geoip` / `disableGeoip`
argument, and no requirement says what happens when it is omitted. Server SDKs have had a
client-level setting behind that argument for a long time, and they do not agree on how the two
interact or what the default is.

posthog-php [#263](https://github.com/PostHog/posthog-php/pull/263) added a client-level
`disableGeoip` option with per-call overrides and had to pick its inheritance rules and default
from reading the other SDKs, because the contract does not state them. That is the gap this
change closes.

## What Changes

- Add a `capture` requirement for the client-level GeoIP setting: server SDKs expose one, it
  defaults to disabling backend GeoIP enrichment, and client SDKs do not expose it.
- Define per-call inheritance: an explicit boolean wins in both directions, and an omitted or
  null per-call value inherits the client setting rather than meaning `false`.
- Define the marker: `$geoip_disable: true` sits among the event's ordinary properties, never
  inside `$set`, `$set_once`, or `$group_set`, is stamped before `before_send`, and is absent
  when the effective value does not disable GeoIP. A caller-supplied `$geoip_disable` property
  is left alone.
- Define that remote flag-evaluation requests carry the same effective value as the request
  body's `geoip_disable` field.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: add "Client-level GeoIP control with per-call override".

## Impact

Audited server SDK behavior at the time of writing:

| SDK | Client-level setting | Default | Per-call override | Required change |
|---|---|---|---|---|
| Node (`posthog-node` / core stateless) | yes, `disableGeoip` | disables GeoIP | yes, `?? client setting` | none |
| Python | yes, `disable_geoip` | disables GeoIP | yes, `None` inherits | none |
| Go | yes, `Config.DisableGeoIP` (`nil` means disable) | disables GeoIP | no — `Enqueue` overwrites the per-message field from config | honour an explicitly supplied per-message value |
| PHP | yes, `disableGeoip` (added in #263) | **does not** disable GeoIP, a deliberate compatibility default | yes, explicit `false` wins, null inherits | align the default in its next major release |
| Ruby | no | n/a | per-call only, omitted sends nothing | add a client-level setting |
| .NET | no | event path defaults the property to true; flag options default to `false` | property-level override only | add a client-level setting and reconcile the two defaults |
| Elixir | no | n/a | per-call only | add a client-level setting |

Client SDKs are unaffected: they run in the end user's network context, so GeoIP enrichment
stays on and no option is required.

The default value is the part of this contract SDKs disagree on most. The requirement states
the majority server behavior (disable by default); PHP's compatibility default and .NET's
split defaults are called out above rather than treated as settled.
