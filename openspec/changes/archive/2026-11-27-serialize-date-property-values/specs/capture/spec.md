## ADDED Requirements

### Requirement: Capture serializes date and time property values as ISO 8601 strings in UTC

When the SDK serializes a captured event for wire delivery or a disk-backed event queue, a custom property value of one of the runtime's built-in date, time or date-time types SHALL serialize as an ISO 8601 string. The SDK MUST NOT serialize such a value as the runtime's default string form when that form is not ISO 8601, as a JSON object of the value's fields, or as JSON `null`, and MUST NOT drop the property or the event because of it.

A value that names an instant — a date-time, whether it carries an offset, a zone, or neither — SHALL be normalized to its equivalent UTC instant and written with the `Z` suffix, the same normalization the envelope `timestamp` follows. The string SHALL NOT depend on the host's time zone, on the caller's offset, or on a framework setting that changes how the runtime converts between date types. A value that carries a calendar date and no time of day SHALL serialize as `YYYY-MM-DD`, and SHALL NOT be shifted into another day by a conversion through an instant.

The number of fractional-second digits is not specified. An SDK MAY write none, three, or more, and MAY truncate rather than round.

The rule SHALL apply recursively, including to date and date-time values nested in objects or arrays, and SHALL apply wherever the SDK serializes caller-supplied properties for delivery, including the person and group property payloads of identify and group identify.

This is a serialization rule. It does not require an SDK's public property types to accept any particular date type, and it does not define the serialization of a runtime date or time type that names neither an instant nor a calendar date, such as a bare time of day, a duration, or a zone-less local date-time.

Known gap: posthog-python (`isoformat()`), posthog-go (`encoding/json` on `time.Time`) and posthog-dotnet (`System.Text.Json` round-trip form) keep the caller's offset instead of normalizing to UTC. posthog-ruby normalizes only top-level property values, so a date-time nested in an object or array keeps its offset there.

#### Scenario: A date-time property value with an offset is sent as the same instant in UTC (@both)
- **GIVEN** an initialized SDK whose runtime has a date-time type that carries a UTC offset, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Date Property" and a custom property "renews_at" whose value is that type set to 2026-11-23 10:30:15 at offset +05:30
- **AND** the SDK is flushed
- **THEN** one event named "Date Property" should be received
- **AND** its custom property "renews_at" should be a string that starts with "2026-11-23T05:00:15" and ends with "Z"

#### Scenario: A calendar-date property value keeps its calendar date (@both)
- **GIVEN** an initialized SDK whose runtime has a calendar-date type with no time of day, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Date Property" and a custom property "signed_up_on" whose value is that type set to 2026-11-23
- **AND** the SDK is flushed
- **THEN** one event named "Date Property" should be received
- **AND** its custom property "signed_up_on" should equal "2026-11-23"

#### Scenario: A nested date-time property value is normalized too (@both)
- **GIVEN** an initialized SDK whose runtime has a date-time type that carries a UTC offset, with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Nested Date" and a custom property "plan" whose value is an object with member "renews_at" set to that type at 2026-11-23 10:30:15 at offset +05:30
- **AND** the SDK is flushed
- **THEN** one event named "Nested Date" should be received
- **AND** the member "renews_at" of its custom property "plan" should be a string that starts with "2026-11-23T05:00:15" and ends with "Z"
