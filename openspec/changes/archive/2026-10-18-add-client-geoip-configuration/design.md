## Context

`$geoip_disable` tells the backend to skip GeoIP enrichment for an event. Server SDKs send
events from datacenter IPs, so enriching them attributes every event to the server's location.
That is why the server default is to disable enrichment, and why the setting belongs on the
client object rather than on every call site.

## Decisions

**Put the requirement in `capture`.** The setting is event enrichment that applies to every
event-producing API (`capture`, `identify`, `alias`, `group_identify`, `$exception`,
`$feature_flag_called`). `capture` already owns the shared enrichment pipeline that those APIs
pass through, in the same way as the "Environment-sourced release identifier" requirement.
`setup` describes initialization rather than an inventory of config options.

**Null inherits, false overrides.** Node, Python, PHP, and Rust (on the APIs where it has a
per-call option) resolve the effective value as `per-call ?? client`. Treating an omitted
argument as `false` would make the client-level setting unusable from any wrapper that passes
its optional argument through. Go's per-message `DisableGeoIP` on events is a plain `bool`, so
it can't tell an omitted value from an explicit `false` without an API break; `Enqueue`
overwrites it from config. Rather than force a major release, the requirement lets such an SDK
keep the client setting authoritative until it can make the distinction, and tags the
explicit-override scenario `@geoip_per_call_unset_capable`. The rule it may not break is
reading the zero value as an explicit `false`.

**Recommend a default rather than leaving it open.** Node, Python, and Go default to disabling
GeoIP on the server; PHP and Rust default to enabling it. Server events come from the server's
network, so disabling is the better default, but changing a shipped default is a breaking
change. The requirement makes the default a SHOULD, records the PHP and Rust divergence, and
leaves any change to each SDK's next major release.

**Marker placement is normative.** PHP's change had to decide whether `$geoip_disable` goes
alongside `$group_set` or inside it on `$groupidentify`. It is event context, not a group
property, so it sits among the ordinary event properties — the same reasoning the
`$release_id` requirement uses for `$set` / `$set_once` / `$group_set`.

## Open questions

- Should PHP and Rust switch to disabling GeoIP by default in their next major releases?
- .NET defaults the event property to disabled but defaults flag-request GeoIP control to
  enabled. Which of the two is intended?
