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

**Null inherits, false overrides.** Three of the four SDKs with a client-level setting resolve
the effective value as `per-call ?? client`. Treating an omitted argument as `false` would make
the client-level setting unusable from any wrapper that passes its optional argument through.
Go currently resolves it the other way (config always wins) and is listed as needing a change.

**State a default rather than leaving it open.** Node, Python, and Go all default to disabling
GeoIP on the server. Leaving the default unspecified is what let PHP's and .NET's defaults
drift apart, so the requirement states the majority behavior and the proposal records the
two known divergences for a human to confirm.

**Marker placement is normative.** PHP's change had to decide whether `$geoip_disable` goes
alongside `$group_set` or inside it on `$groupidentify`. It is event context, not a group
property, so it sits among the ordinary event properties — the same reasoning the
`$release_id` requirement uses for `$set` / `$set_once` / `$group_set`.

## Open questions

- Should PHP's compatibility default be recorded as a sanctioned temporary divergence with a
  target release, or treated as a bug?
- .NET defaults the event property to disabled but defaults flag-request GeoIP control to
  enabled. Which of the two is intended?
