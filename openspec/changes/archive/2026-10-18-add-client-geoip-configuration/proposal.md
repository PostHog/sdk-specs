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
  SHOULD default to disabling backend GeoIP enrichment, and client SDKs do not need it. The
  default is a SHOULD because posthog-php and posthog-rs ship the opposite default and changing
  it is a breaking change left to each SDK's next major release.
- Define per-call inheritance: an explicit boolean wins in both directions, and an omitted or
  null per-call value inherits the client setting rather than meaning `false`. An SDK whose
  shipped per-call option can't represent "not set" (posthog-go) conforms by keeping the
  client setting authoritative until a major release can tell the two apart; the scenario
  that needs an explicit per-call override is tagged `@geoip_per_call_unset_capable`.
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
| Go | yes, `Config.DisableGeoIP` (`nil` means disable) | disables GeoIP | events: no — the per-message `DisableGeoIP` is a plain `bool` and `Enqueue` overwrites it from config; flags: yes, `*bool` | none now (client setting stays authoritative); add an unset-capable per-message option in its next major release |
| PHP | yes, `disableGeoip` (added in #263) | **does not** disable GeoIP, a deliberate compatibility default | yes, explicit `false` wins, null inherits | none now; may change the default in its next major release |
| Rust | yes, `disable_geoip` | **does not** disable GeoIP (builder default `false`) | flags and `$feature_flag_called`: yes, `Option<bool>` inherits; events: no per-call option, and a caller-supplied `$geoip_disable` property wins over the client setting | none now; may change the default in its next major release |
| Ruby | no | n/a | per-call only, omitted sends nothing | add a client-level setting |
| .NET | no | event path defaults the property to true; flag options default to `false` | property-level override only | add a client-level setting and reconcile the two defaults |
| Elixir | no | n/a | per-call only | add a client-level setting |

Client SDKs are unaffected: they run in the end user's network context, so GeoIP enrichment
stays on and no option is required.

The default value is the part of this contract SDKs disagree on most: Node, Python, and Go
disable GeoIP by default, while PHP and Rust enable it. The requirement therefore recommends
disabling by default (SHOULD) rather than requiring it, so no SDK has to break its shipped
default to conform. .NET's split event/flag defaults are called out above rather than treated
as settled.
