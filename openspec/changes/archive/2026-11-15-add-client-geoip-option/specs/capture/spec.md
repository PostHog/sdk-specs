## MODIFIED Requirements

### Requirement: Client-level GeoIP control with per-call override

A server SDK SHALL expose a client-level GeoIP option (`disableGeoip`, `disable_geoip`, or the
platform's casing) that controls whether the events it sends ask the backend to skip GeoIP
enrichment. That option SHOULD default to disabling enrichment: server SDKs send events from
their own network, so enriching them would attribute every event to the server's location.
posthog-php and posthog-rs currently default to enabling enrichment. Changing a shipped default
is a breaking change, so each SDK makes it, if at all, in its next major release. A client SDK
is not required to expose the option: it runs in the end user's network context, where GeoIP
enrichment is the intended behavior. A client SDK that does expose one follows
"Client SDK GeoIP opt-out" below instead of this requirement.

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

## ADDED Requirements

### Requirement: Client SDK GeoIP opt-out

A client SDK MAY expose a client-level GeoIP option in its configuration, named `disableGeoIp`,
`disableGeoip`, `disable_geoip`, or the platform's casing. The option is optional: a client SDK
sends events from the end user's network context, where GeoIP enrichment is the intended behavior,
so a client SDK that exposes no such option conforms. posthog-ios, posthog-android (from 3.77.0),
posthog-flutter and posthog-js's core (node, react-native) expose one; posthog-js's browser package
does not, and directs callers to `before_send`.

A client SDK that exposes the option SHALL satisfy the following.

1. **Default.** The option SHALL default to allowing enrichment (the value that does not disable
   it), the opposite of the server-SDK default.
2. **Event marker.** When the option disables enrichment, the SDK SHALL mark every analytics event
   it captures with `$geoip_disable: true` among the event's ordinary properties.
3. **Precedence over caller properties.** The SDK SHALL stamp the marker after merging the caller's
   per-call properties and the registered super properties, so neither can clear the opt-out for an
   individual event. This is the one place where client behavior differs from the server
   requirement, which leaves a caller-supplied value alone.
4. **Hook ordering.** The SDK SHOULD stamp the marker before `before_send` / `beforeSend` runs, so a
   hook can inspect, replace, or remove it. posthog-flutter stamps it after its Dart `beforeSend` on
   every platform, because the native SDKs and the desktop core add SDK properties after the Dart
   callbacks run; a Flutter callback therefore cannot see or remove the marker. A client SDK that
   cannot stamp before its hook SHALL document that in the option's own reference documentation.
5. **Excluded destinations.** The marker SHALL NOT be copied into `$set`, `$set_once`, or
   `$group_set`, and the SDK SHALL NOT attach it to `$snapshot` session replay events.
6. **Minimized flag events.** A minimized `$feature_flag_called` event SHALL retain the marker, as
   the processing-control sentinel rule of `feature-flag-called-tracker` requires.
7. **Enrichment allowed.** When the option allows enrichment, the SDK SHALL omit the marker and
   SHALL NOT remove a `$geoip_disable` property the caller supplied in the call's properties.
8. **Flag requests.** A remote feature-flag evaluation request SHALL carry the option's value as the
   `geoip_disable` field of its request body, for both values of the option.
9. **No per-call override.** A client SDK is not required to accept the option per call. Where a
   client SDK's internal flag API already accepts an explicit override, that override stays
   authoritative for that call.

A client SDK whose events are produced by a host SDK it does not control, such as posthog-flutter on
the web where the host application initializes posthog-js, SHALL leave the option without effect on
that platform and SHOULD log a debug-level warning naming the host SDK's own mechanism.

#### Scenario: The option defaults to allowing enrichment (@client)
- **GIVEN** the SDK is set up without the GeoIP option
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should omit "$geoip_disable"

#### Scenario: The option marks a captured event (@client)
- **GIVEN** the SDK is set up with the GeoIP option set to disable enrichment
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: The SDK marker wins over a caller-supplied value (@client)
- **GIVEN** the SDK is set up with the GeoIP option set to disable enrichment
- **WHEN** capture is called with event "Save" and properties:
  | property       | value |
  | $geoip_disable | false |
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: A caller-supplied marker survives the default option (@client)
- **GIVEN** the SDK is set up without the GeoIP option
- **WHEN** capture is called with event "Save" and properties:
  | property       | value |
  | $geoip_disable | true  |
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: The flags request carries the option's value (@client)
- **GIVEN** the SDK is set up with the GeoIP option set to disable enrichment
- **WHEN** the SDK requests remote feature flags
- **THEN** the flags request body should have "geoip_disable" equal to true
