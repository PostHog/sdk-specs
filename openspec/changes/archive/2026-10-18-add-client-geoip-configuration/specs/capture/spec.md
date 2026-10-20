## ADDED Requirements

### Requirement: Client-level GeoIP control with per-call override

A server SDK SHALL expose a client-level GeoIP option (`disableGeoip`, `disable_geoip`, or the
platform's casing) that controls whether the events it sends ask the backend to skip GeoIP
enrichment. That option SHOULD default to disabling enrichment: server SDKs send events from
their own network, so enriching them would attribute every event to the server's location.
posthog-php and posthog-rs currently default to enabling enrichment. Changing a shipped default
is a breaking change, so each SDK makes it, if at all, in its next major release. Client SDKs
SHALL NOT require the option: they run in the end user's network context, where GeoIP
enrichment is the intended behavior.

Event-producing APIs that accept options — at least `capture`, `identify`, `alias`, and
`group_identify` — SHALL accept the same option per call. A per-call value that is not set
(omitted or null) SHALL inherit the client-level setting and SHALL NOT be read as `false`. An
explicitly set per-call value SHALL override the client-level setting in both directions: an
explicit `false` SHALL re-enable GeoIP enrichment for that call even when the client-level
setting disables it.

An SDK whose shipped per-call option can't represent "not set", such as posthog-go's
non-nullable `DisableGeoIP` message field, conforms by keeping the client-level setting
authoritative for that API until a major release lets it tell an unset value from an explicit
one. It SHALL NOT read the zero value as an explicit `false`. Scenarios that need an explicit
per-call override on an event API are tagged `@geoip_per_call_unset_capable`.

When the effective value disables GeoIP, the SDK SHALL mark the event with
`$geoip_disable: true` among the event's ordinary properties and SHALL stamp it before
`before_send` runs, so a hook can inspect, replace, or remove it. The marker SHALL NOT be copied
into `$set`, `$set_once`, or `$group_set`, because it is event context rather than a person or
group property. When the effective value does not disable GeoIP, the SDK SHALL omit the marker
and SHALL NOT remove a `$geoip_disable` property the caller supplied in the call's properties.

A remote feature-flag evaluation request SHALL carry the same effective value as the
`geoip_disable` field of its request body, resolved from the per-call option where the flag API
exposes one and otherwise from the client-level setting.

`$geoip_disable` is a processing-control sentinel in the sense of the
`feature-flag-called-tracker` minimal-event allowlist, so a minimized `$feature_flag_called`
event SHALL retain it when the SDK stamped it.

#### Scenario: The client-level setting marks an ordinary event (@server)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** capture is called with event "Save" and no per-call GeoIP option
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: An explicit per-call false re-enables enrichment for one call (@server @geoip_per_call_unset_capable)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** capture is called with event "Save" and the per-call GeoIP option set to false
- **THEN** the enqueued "Save" event should omit "$geoip_disable"
- **WHEN** capture is called with event "Save Again" and no per-call GeoIP option
- **THEN** the enqueued "Save Again" event should have property "$geoip_disable" equal to true

#### Scenario: An omitted per-call value inherits an enabled client setting (@server)
- **GIVEN** the client is constructed with the GeoIP option set to allow enrichment
- **WHEN** capture is called with event "Save" and no per-call GeoIP option
- **THEN** the enqueued "Save" event should omit "$geoip_disable"

#### Scenario: A caller-supplied marker survives an enabled client setting (@server)
- **GIVEN** the client is constructed with the GeoIP option set to allow enrichment
- **WHEN** capture is called with event "Save" and properties:
  | property        | value |
  | $geoip_disable  | true  |
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: Group identify carries the marker outside $group_set (@server)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** group identify is called for group type "company" and key "acme" with properties:
  | property | value |
  | name     | Acme  |
- **THEN** the enqueued "$groupidentify" event should have property "$geoip_disable" equal to true
- **AND** the enqueued "$groupidentify" event "$group_set" should omit "$geoip_disable"

#### Scenario: A flag evaluation request carries the effective value (@server)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** a remote feature-flag evaluation request is made with no per-call GeoIP option
- **THEN** the request body field "geoip_disable" should be true
- **WHEN** a remote feature-flag evaluation request is made with the per-call GeoIP option set to false
- **THEN** the request body field "geoip_disable" should be false
