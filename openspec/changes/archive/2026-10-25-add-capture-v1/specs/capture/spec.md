## Narrative alignment

When syncing this delta into the canonical `capture` spec:

- In Purpose, name both delivery wires: legacy capture (`/batch/` or `/capture/`) and capture v1 (`/i/v1/analytics/events`, with `/i/v1/ai/events` for AI events, see `capture-ai`).
- In Behavior step 4 (**Server**), replace the merge order with the capture v1 order: the call's properties and options win; the ambient request context, then the SDK-level default properties, then the values the SDK adds itself (`$is_server`, `$geoip_disable`, system context, feature flag properties, OpenTelemetry trace ids where derived) fill only keys the layers above left unset. Note that on legacy capture the SDK also stamps `$lib` and `$lib_version` over the caller's values, and that posthog-python 7.x and posthog-go 1.x applied their default properties after the caller's properties.
- In Behavior step 5, say that on capture v1 `$lib` and `$lib_version` are not written into `properties`: the server derives them from the `PostHog-Sdk-Info` header. Keep the legacy sentence.
- In Behavior step 6, add that on capture v1 the legacy option properties are hoisted into `options` after the hook returns.
- In Behavior step 7 (**Server**), say that a capture v1 SDK keeps one queue, flush cycle and retry state per delivery lane (analytics and AI).
- In Error handling, replace "invalid distinct id (server)" with the capture v1 rule: an empty or whitespace-only distinct id is treated as missing (a personless event with a generated id, or the SDK's existing error), and the event is never sent without a `distinct_id`.
- Leave the client bullets and the existing requirements unchanged except where this delta modifies them.

## ADDED Requirements

### Requirement: Capture v1 wire contract

An SDK that delivers events through capture v1 SHALL send analytics events with `POST {host}/i/v1/analytics/events` and SHALL NOT use `/batch`, `/capture`, `/e`, `/track` or `/i/v0/e`. The request body SHALL be a JSON object `{"created_at": <RFC 3339 string>, "historical_migration"?: <boolean>, "batch": [<event>, ...]}`, with at least one event, and `historical_migration` present only when true. Historical-migration events and live events SHALL NOT share a request.

Each event SHALL be a JSON object with the fields `event`, `uuid`, `distinct_id` and `timestamp` as JSON strings, `properties` as a JSON object, `options` as a JSON object (an empty object when the event has no options), and `session_id` and `window_id` as JSON strings only when present. The SDK SHALL NOT send any other top-level event field; a top-level `$set` or `$set_once` the SDK's API accepts is placed inside `properties`. The SDK SHALL NOT send `api_key`, `sent_at` or `offset` in the body.

Capture v1 parses the request with one strict JSON parse and rejects the whole request with `400 request_parsing_error` when any field has the wrong JSON type, a required field is missing, or the body is not valid JSON. The SDK SHALL therefore guarantee these types on the wire, including after `before_send`: an event whose hook leaves `distinct_id` or `event` non-string, or whose serialization fails, is dropped locally and reported through the SDK's error surface or a log line, and never sent.

Legacy capture: the body carried `api_key` and `sent_at`, `uuid` and `timestamp` were optional, and a non-string `distinct_id` was converted to text.

#### Scenario: Analytics events go to the capture v1 endpoint only (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be "/i/v1/analytics/events"
- **AND** no capture request should use "/batch", "/capture", "/e", "/track" or "/i/v0/e"

#### Scenario: The body carries the batch envelope and typed event fields (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property | value |
  | plan     | pro   |
- **AND** pending captures are flushed
- **THEN** the first request body should contain a string "created_at" and an array "batch" with exactly 1 event
- **AND** the first request body should omit these root fields:
  | field                |
  | api_key              |
  | sent_at              |
  | historical_migration |
- **AND** the first received event should have string fields "event", "uuid", "distinct_id" and "timestamp"
- **AND** the first received event field "properties" should be an object containing "plan" equal to "pro"
- **AND** the first received event field "options" should be an object

#### Scenario: Historical migration is a request flag (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key", flush threshold 1, and historical migration enabled
- **WHEN** capture is called with distinct id "user-123" and event "Imported"
- **AND** pending captures are flushed
- **THEN** the first request body should contain historical_migration equal to true

#### Scenario: A hook that leaves a non-string distinct id drops only that event (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **AND** before-send replaces the distinct id of events named "Broken" with the number 42
- **WHEN** capture is called with distinct id "user-123" and event "Broken"
- **AND** capture is called with distinct id "user-123" and event "Fine"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the request should contain only the event "Fine"
- **AND** the SDK should report the event "Broken" as dropped locally

### Requirement: Capture v1 request headers

An SDK that delivers events through capture v1 SHALL send these headers on every capture request:

- `Authorization: Bearer <project token>`. The token is never placed in the body.
- `Content-Type: application/json`.
- `User-Agent`, equal to the `PostHog-Sdk-Info` value.
- `PostHog-Sdk-Info: <library>/<version>`, where `<library>` is the SDK's own canonical `$lib` name (`posthog-python`, `posthog-go`, `posthog-rs`, `posthog-node`) and `<version>` is the package version actually shipped. Capture derives `$lib` and `$lib_version` from this header, so a built-in integration SHALL NOT relabel the client.
- `PostHog-Request-Id`: a UUID minted once per batch and kept across every retry of that batch.
- `PostHog-Attempt`: `1` on the first attempt, incremented by one on each retry of the same batch.
- `PostHog-Request-Timestamp`: the send time of this attempt as an RFC 3339 string with an explicit offset and at least millisecond precision, taken from the same clock as the event timestamps and stamped again on every attempt.
- `Content-Encoding` only when the body is compressed, with one of `gzip`, `deflate`, `br` or `zstd`.

Every header value SHALL be visible ASCII. The body's `created_at` SHALL be set once per batch and kept across retries. Capture uses `PostHog-Request-Timestamp` to correct for client clock skew, so a retry that resends a stale timestamp shifts every event in the request by the retry delay; the SDK SHALL NOT let an HTTP library retry a capture request on its behalf.

#### Scenario: The first attempt carries the required headers (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the first request should authenticate with bearer token "phc_test_key"
- **AND** the first request header "Content-Type" should start with "application/json"
- **AND** the first request header "PostHog-Sdk-Info" should match "<library>/<version>" for the SDK under test
- **AND** the first request header "User-Agent" should equal the "PostHog-Sdk-Info" header
- **AND** the first request header "PostHog-Request-Id" should be a valid UUID
- **AND** the first request header "PostHog-Attempt" should be integer 1
- **AND** the first request header "PostHog-Request-Timestamp" should be an RFC 3339 timestamp with an explicit offset and at least millisecond precision

#### Scenario: A retry keeps the request id and restamps the attempt and timestamp (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status | body                                   |
  | 503    | {"error":"service_unavailable"}        |
  | 200    | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** all recorded request IDs should equal the nonempty first request ID
- **AND** all recorded request attempts should be consecutive integers starting at one
- **AND** the first two request headers "PostHog-Request-Timestamp" should be nonempty and different
- **AND** the first two request bodies should have the same "created_at"

### Requirement: Per-event results drive what is resent and what is reported

An SDK that delivers events through capture v1 SHALL read the `results` object of a 2xx response, keyed by the event `uuid` in canonical lowercase hyphenated form, and treat each entry as the verdict for that event:

- `ok` and `warning` mean the event was stored; the SDK SHALL NOT resend it or report it as a failure. `details` on an `ok` or `warning` entry (for example `person_processing_disabled`) is informational.
- `drop` means capture refused the event; the SDK SHALL NOT resend it and SHALL report it through its error surface with the `details` tag as an opaque string.
- `retry` means capture could not store the event this time; the SDK SHALL resend only the `retry` events, in their original relative order, as a new attempt of the same batch, and SHALL report an event still `retry` after the last attempt as exhausted.
- An entry whose `result` value the SDK does not recognize, and an event whose uuid is absent from `results`, SHALL be treated as delivered.
- A 2xx whose body cannot be read as `{"results": {...}}` is a terminal failure of the whole batch.

The SDK SHALL NOT hard-code the set of `details` tags. When a `results` entry carries `duplicates_dropped: n`, the request repeated that uuid: the first event with that uuid in the request takes the entry's `result` and `details`, and the SDK SHALL report exactly the next `n` events with that uuid as `drop` with the reason `duplicate_event_uuid`, never retrying them. The SDK SHALL NOT guard, split, rewrite or deduplicate repeated uuids before sending.

When no error handler is registered, the SDK SHALL log one aggregate line per batch that lost events, carrying the count, the cause and the endpoint, and never event content.

Legacy capture: a 2xx meant the whole request was accepted and there was no per-event verdict.

#### Scenario: Only retry verdicts are resent (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 3
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                                                                                                    |
  | 200    | {"results":{"<uuid 0>":{"result":"ok"},"<uuid 1>":{"result":"drop","details":"event_name_too_long"},"<uuid 2>":{"result":"retry","details":"not_persisted"}}} |
  | 200    | {"results":{"<uuid 2>":{"result":"ok"}}}                                                                                                |
- **WHEN** capture is called sequentially 3 times with zero-based top-level index substitution:
  """application/json
  {"distinct_id":"user-123","event":"event-{index}"}
  """
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** the second request should retain first-response retry UUIDs and omit its terminal UUIDs
- **AND** the SDK should report event "event-1" as dropped with details "event_name_too_long"
- **AND** the SDK should not report event "event-0" or "event-2" as failed

#### Scenario: Duplicate copies are reported, not resent (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 3
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                                 |
  | 200    | {"results":{"0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04":{"result":"ok","duplicates_dropped":2}}} |
- **WHEN** capture is called sequentially 3 times with the same uuid "0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04" and events "first", "second" and "third"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the first request should contain 3 events with uuid "0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04"
- **AND** the SDK should report events "second" and "third" as dropped with details "duplicate_event_uuid"
- **AND** the SDK should not report event "first" as failed

#### Scenario: Unknown verdicts and absent uuids count as delivered (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                   |
  | 200    | {"results":{"<uuid 0>":{"result":"accepted_later"}}}   |
- **WHEN** capture is called sequentially 2 times with zero-based top-level index substitution:
  """application/json
  {"distinct_id":"user-123","event":"event-{index}"}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the SDK should not report any event as failed

### Requirement: Per-event options replace the legacy option properties

An SDK that delivers events through capture v1 SHALL accept an `options` object on every event-producing call (capture, AI capture, exception capture, identify or person-property calls, alias and group identify), SHALL send it as the event's `options` with every key and value as given, and SHALL NOT validate, convert or filter option values: capture reads them leniently and drops an event whose value it cannot read with `details: invalid_options`, which the SDK reports like any other drop. Keys the SDK does not know SHALL pass through unchanged. A non-object `options` value on a dynamically typed SDK SHALL be logged as an error and the event sent without caller options.

The legacy option properties are the `$`-prefixed properties legacy capture reads as settings: `$process_person_profile`, `$cookieless_mode`, `$ignore_sent_at` and `$product_tour_id`. In the wire builder, after the last `before_send` hook and once per event, the SDK SHALL remove each of them from `properties` and SHALL copy its value into the matching option (`process_person_profile`, `cookieless_mode`, `disable_skew_correction`, `product_tour_id`) only when that option is absent or `null`. An option set by any layer therefore wins over a legacy property set by any layer. SDK-internal code (personless defaults, built-in AI and MCP integrations) SHALL set options directly and never write a legacy option property.

An SDK with global default properties SHALL offer global default options with the same interface, and an SDK with a request-context layer for properties SHALL offer context options (for example `super_options` and `set_context_option` in posthog-python, `Config.DefaultEventOptions` and `RequestContext.Options` in posthog-go, `registerOptions()` and context `options` in posthog-node). An SDK with neither layer needs neither.

Legacy capture: SDKs validated and converted `$process_person_profile` and `$cookieless_mode` themselves and sent them as properties.

#### Scenario: A caller option is sent as given and the legacy property is removed (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$cookieless_mode":true},"options":{"process_person_profile":"no","custom_flag":7}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "process_person_profile" should equal JSON "no"
- **AND** the first received event option "custom_flag" should equal JSON 7
- **AND** the first received event option "cookieless_mode" should equal JSON true
- **AND** the first received event property "$cookieless_mode" should be absent

#### Scenario: An option beats its legacy property (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$process_person_profile":true},"options":{"process_person_profile":false}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "process_person_profile" should equal JSON false
- **AND** the first received event property "$process_person_profile" should be absent

#### Scenario: Unset options are omitted (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the first received event field "options" should be an object
- **AND** the first received event option "process_person_profile" should be absent
- **AND** the first received event option "cookieless_mode" should be absent
- **AND** the first received event option "disable_skew_correction" should be absent
- **AND** the first received event option "product_tour_id" should be absent

#### Scenario: Hoisting runs after before_send (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** before-send deletes the property "$process_person_profile"
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$process_person_profile":false}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "process_person_profile" should be absent
- **AND** the first received event property "$process_person_profile" should be absent

### Requirement: Server SDKs build every event in one layer order

An SDK that delivers events through capture v1 SHALL build each event in this order, for every event type its public API produces (capture, AI capture, exception capture, identify or person-property events, alias and group identify):

1. **Identity resolves first.** The distinct id comes from the call, then the ambient request context, then a generated personless id (or the SDK's existing error for a missing id). A context session id becomes `$session_id` unless the event has its own.
2. **The call's own values.** The call's `properties` and `options`, and typed call values (`groups`, a typed `$set` or `$set_once`), which win key by key over the same key in `properties`.
3. **Fill-only defaults**, each layer filling only what the layers above left unset: the ambient request context, then the SDK-level default properties and options, then the values the SDK adds itself (`$is_server`, `$geoip_disable` from the client setting, system context, the `$feature/<key>` and `$active_feature_flags` properties derived from a flags snapshot or `send_feature_flags`, `$release_id`, the `process_person_profile: false` option for a personless event, and `$trace_id` with `$span_id` from an active OpenTelemetry span, added as a pair only when no layer set either key). A property is unset only when its key is missing, so a `null` property blocks the fill; an option is unset when it is missing or `null`. `$set`, `$set_once`, `$groups` and `$group_set` fill one level deep when both values are objects.
4. **`before_send`** runs on an isolated copy of the assembled event, including `options`, and has the final say. The SDK SHALL NOT add or re-add any value after the hook. Where a minimized `$feature_flag_called` event is built, its allowlist SHALL be applied after step 3 and before step 4, and SHALL keep the legacy option properties, `$session_id` and `$window_id`.
5. **Hoisting**, once, in the wire builder: the legacy option properties move into `options`, `$session_id` and `$window_id` move to their top-level fields, and `$lib` and `$lib_version` are removed.

A per-call argument such as `disable_geoip` belongs to step 2, so it beats a context or global `$geoip_disable`; the client-level setting belongs to step 3, so a context or global value beats it. A built-in AI or MCP integration SHALL set `process_person_profile: false` at step 2 when it substitutes a trace or session id for a missing user id. Adding groups to an event SHALL NOT turn person processing on.

Legacy capture: posthog-python 7.x merged `super_properties` over the call's properties and posthog-go 1.x merged `DefaultEventProperties` over the call's properties; both reversed in their capture v1 majors. This requirement states the server part of the order that #145 proposes for flag properties.

#### Scenario: The call wins over context, global and SDK values (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "plan" equal to "free" and "$is_server" equal to false
- **AND** the ambient request context, where the SDK has one, carries "plan" equal to "team"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property | value |
  | plan     | pro   |
- **AND** pending captures are flushed
- **THEN** the first received event property "plan" should equal JSON "pro"
- **AND** the first received event property "$is_server" should equal JSON false

#### Scenario: Lower layers fill only unset keys and a null property blocks the fill (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "plan" equal to "free" and "region" equal to "eu"
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"plan":null}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event property "plan" should equal JSON null
- **AND** the first received event property "region" should equal JSON "eu"

#### Scenario: A global option fills an unset option and a null option does not block it (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default options carry "cookieless_mode" equal to true
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","options":{"cookieless_mode":null}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "cookieless_mode" should equal JSON true

#### Scenario: Nested person and group properties fill one level deep (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "$set" equal to JSON `{"tier":"gold","source":"default"}`
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$set":{"source":"call"}}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event property "$set" should equal JSON `{"tier":"gold","source":"call"}`

#### Scenario: before_send sees the filled event and can remove a default (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "plan" equal to "free"
- **AND** before-send records the event it receives and deletes the property "$is_server"
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the event before-send received should have property "plan" equal to "free" and property "$is_server" equal to true
- **AND** the first received event property "$is_server" should be absent
- **AND** the first received event property "plan" should equal JSON "free"

#### Scenario: Groups never force person processing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","groups":{"company":"acme"}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event property "$groups" should equal JSON `{"company":"acme"}`
- **AND** the first received event option "process_person_profile" should be absent

### Requirement: Library identity comes from the request header

An SDK that delivers events through capture v1 SHALL NOT send `$lib` or `$lib_version` in `properties`. The wire builder SHALL remove both keys after `before_send`, whoever set them, because capture derives them from `PostHog-Sdk-Info` and writes them after the event's own properties. `before_send` may still see a caller-supplied value. Built-in integrations (MCP servers, AI wrappers, framework middleware) SHALL NOT change the client's `PostHog-Sdk-Info` value.

Legacy capture: server SDKs stamped `$lib` and `$lib_version` into `properties`, and some integrations relabeled the client.

#### Scenario: A caller-set $lib never reaches the wire (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property     | value      |
  | $lib         | custom-lib |
  | $lib_version | 9.9.9      |
- **AND** pending captures are flushed
- **THEN** the first received event property "$lib" should be absent
- **AND** the first received event property "$lib_version" should be absent
- **AND** the first request header "PostHog-Sdk-Info" should match "<library>/<version>" for the SDK under test

### Requirement: Session and window ids are lifted only as strings

An SDK that delivers events through capture v1 SHALL remove `$session_id` and `$window_id` from `properties` in the wire builder. A value whose JSON form is a string, including the empty string, SHALL be sent as the top-level `session_id` or `window_id` field. A `null` value SHALL be dropped silently. Any other value SHALL be dropped with a warning that names the key and the JSON type and never the value, because capture rejects the whole request when either field is not a string.

#### Scenario: A string session id is lifted and a numeric one is dropped with a warning (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"With Session","properties":{"$session_id":"session-123"}}
  """
- **AND** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Bad Session","properties":{"$session_id":123}}
  """
- **AND** pending captures are flushed
- **THEN** the received event "With Session" should have top-level "session_id" equal to "session-123"
- **AND** the received event "With Session" should have property "$session_id" absent
- **AND** the received event "Bad Session" should have top-level "session_id" absent
- **AND** the received event "Bad Session" should have property "$session_id" absent
- **AND** the SDK should record a warning that names "$session_id" and the JSON type "number" and does not contain "123"

### Requirement: Distinct ids and identity fallbacks on capture v1

An SDK that delivers events through capture v1 SHALL treat an empty or whitespace-only caller `distinct_id` as missing. A missing id keeps the SDK's existing behavior: a generated personless id (UUIDv7, with `process_person_profile: false` set as an option) or a clear error returned to the caller. The SDK SHALL never send an event without a `distinct_id` key.

The SDK SHALL NOT shorten, hash or reject distinct ids by length or by placeholder value: capture v1 drops an event whose `distinct_id` is over 200 UTF-8 bytes (`distinct_id_too_large`) and accepts placeholder values such as `anonymous` without a person profile, and reports both per event. A `$groupidentify` event's `distinct_id` SHALL be the caller's id when given, else the request-context id where the SDK has one, else `$<group type>_<group key>`, and never a random value. An `alias` call SHALL never take its target from the request context. Global and context layers reach person-only events (`$identify`, `$create_alias`, `$merge_dangerously`, `$groupidentify`) like any other event; `$groupidentify` never takes the context session id.

Legacy capture: distinct ids over 200 characters were shortened and the event kept; posthog-python 6.x used a random id for `$groupidentify` without a caller id.

#### Scenario: A whitespace distinct id becomes a personless event (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK generates a personless id for a missing distinct id
- **WHEN** capture is called with distinct id "   " and event "Anonymous Action"
- **AND** pending captures are flushed
- **THEN** the first received event field "distinct_id" should be a nonempty string that is not "   "
- **AND** the first received event option "process_person_profile" should equal JSON false

#### Scenario: Group identify falls back to the type and key id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** group identify is called for group type "company" and key "acme" with no distinct id and properties:
  | property | value |
  | name     | Acme  |
- **AND** pending captures are flushed
- **THEN** the first received event field "event" should equal "$groupidentify"
- **AND** the first received event field "distinct_id" should equal "$company_acme"
- **AND** the first received event field "session_id" should be absent

#### Scenario: A long distinct id is sent unchanged (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with a distinct id of 250 ASCII characters and event "Long Id"
- **AND** pending captures are flushed
- **THEN** the first received event field "distinct_id" should have length 250

### Requirement: Timestamps on capture v1

An SDK that delivers events through capture v1 SHALL stamp a missing event `timestamp` once, when the event is captured or enqueued, from the same clock as `PostHog-Request-Timestamp`, and SHALL NOT change it afterwards (not on retry, not after a restart). Every timestamp on the wire (`timestamp`, `created_at`, `PostHog-Request-Timestamp`) SHALL be RFC 3339 with an explicit offset (`Z` or `±HH:MM`) and at least millisecond precision; finer precision the caller or the clock provides SHALL be kept. The SDK SHALL NOT correct clock skew locally, SHALL NOT reject or clamp a future timestamp, and SHALL NOT send an `offset` field. An unparseable caller timestamp SHALL be replaced with the current time and logged with a warning that names the rule and never the value. A naive caller timestamp follows the SDK's documented zone rule.

Legacy capture: `timestamp` was optional and some SDKs sent an `offset`; posthog-rs rejected future timestamps.

#### Scenario: A caller timestamp keeps its sub-millisecond precision and offset semantics (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Precise","timestamp":"2025-01-02T08:34:05.123456+05:30"}
  """
- **AND** pending captures are flushed
- **THEN** every event in the first capture request should have UTC timestamp "2025-01-02T03:04:05.123456Z"

#### Scenario: A generated timestamp has at least millisecond precision (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00.250Z"
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Stamped"
- **AND** pending captures are flushed
- **THEN** every event in the first capture request should have UTC timestamp "2025-01-01T00:00:00.250Z"

#### Scenario: A retry resends the original event timestamp (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status | body                                   |
  | 503    | {"error":"service_unavailable"}        |
  | 200    | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Retried"
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** the present event "timestamp" lists in requests zero and one should be identical
- **AND** the present event "uuid" lists in requests zero and one should be identical

### Requirement: Each event is serialized on its own and the body is strict JSON

An SDK that delivers events through capture v1 SHALL serialize each event independently, so that one event the encoder cannot write never costs its batch, and SHALL send a body a strict JSON parser accepts: no bare `NaN`, `Infinity` or `-Infinity` tokens and no duplicate keys. An event whose serialization fails SHALL be dropped alone and reported through the SDK's local-drop path. A non-finite number inside `properties` SHALL be sent as JSON `null` and the event kept (posthog-node, posthog-rs, posthog-python, and posthog-go from v2). The SDK SHALL NOT add a per-value check to events that hold no non-finite number: an encoder that already writes `null` needs nothing, and an encoder that rejects non-finite numbers SHALL encode each event strictly first and rewrite its non-finite numbers to `null` only when that encoding fails (posthog-python, posthog-go). A client SDK MAY drop the non-finite property instead and keep the event (posthog-ios, posthog-android).

A missing, `null`, empty or non-string event name SHALL be dropped locally and never sent, converted or raised to the caller. A non-string property or option key with a natural string form (number, boolean, symbol) MAY be converted as the language's JSON encoder does; a key the encoder cannot write drops only that key.

Legacy capture: whole-batch serialization let one bad value lose every event in the batch.

#### Scenario: An unserializable event does not cost its neighbors (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **WHEN** capture is called with distinct id "user-123", event "Bad", and a property value the SDK's JSON encoder cannot write
- **AND** capture is called with distinct id "user-123" and event "Good"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the request should contain only the event "Good"
- **AND** the request body should parse under a strict JSON parser

#### Scenario: An empty event name is dropped locally (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event ""
- **AND** pending captures are flushed
- **THEN** the capture call should not throw
- **AND** no capture request should have been received

### Requirement: The client fails open on a missing or personal API key

Constructing an SDK client SHALL never throw or fail because of the project token. An empty or whitespace-only token, or a token that starts with `phx_` (a personal API key, which capture always rejects), SHALL produce a disabled client that accepts every call, sends nothing, returns flag defaults and logs one error, so a secret key never reaches the wire. Any other malformed token SHALL be sent as given, and capture's `401` SHALL reach the error surface. The SDK SHALL offer an explicit way to build a disabled client for tests. A built-in integration SHALL NOT raise or return a constructor error over an analytics-only setup problem; it logs one error and turns its own capture off.

#### Scenario: A personal API key disables the client without throwing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **WHEN** the SDK is initialized with token "phx_secret_personal_key" and flush threshold 1
- **AND** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the initialization should not throw
- **AND** no capture request should have been received
- **AND** the SDK should record one error log about the personal API key that does not contain "phx_secret_personal_key"

#### Scenario: A blank token disables the client (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **WHEN** the SDK is initialized with token "   " and flush threshold 1
- **AND** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the initialization should not throw
- **AND** no capture request should have been received

## MODIFIED Requirements

### Requirement: Caller-supplied event properties take precedence

On client SDKs, an event's properties SHALL be merged in this order, each layer overwriting the one before:

1. Properties the SDK sets itself.
2. Registered (super) properties.
3. The properties the caller passes on the event.

`before_send` (Behavior step 6) then runs over the assembled message and can change any of them.

A registered or caller value for a key the SDK sets itself changes that event only. It SHALL NOT change the SDK's own state: a later event without that key carries the SDK's value again, and a caller `$process_person_profile` does not turn person processing on or off for the SDK.

The project token is request routing, not an event property. Where an SDK carries it on the event (posthog-js stamps `token` on every event and takes the batch `api_key` from it), the SDK SHALL set the configured token on every event, and a registered or caller `token` SHALL NOT replace it.

A group the caller passes for the event SHALL win over a registered group of the same type.

This requirement does not apply to server SDKs. Server SDKs that deliver through capture v1 follow **Server SDKs build every event in one layer order**: the call's values win, and `$lib` and `$lib_version` come from the request header. Server SDKs still on legacy capture set `$lib` and `$lib_version` after the caller's properties, and python 7.x, go 1.x, dotnet and elixir apply their SDK-level default properties after the caller's properties as well.

#### Scenario: Caller property overrides an SDK context property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property | value      |
  | $lib     | custom-lib |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property | value      |
  | $lib     | custom-lib |

#### Scenario: Registered property overrides an SDK-set property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **AND** registered properties are:
  | property       | value |
  | $is_identified | true  |
- **WHEN** capture is called with event "Signed Up"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property       | value |
  | $is_identified | true  |

#### Scenario: Caller property overrides an SDK-set property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |

#### Scenario: Caller property changes that event only (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |
- **AND** capture is called with event "Viewed Dashboard"
- **THEN** one event named "Viewed Dashboard" should be enqueued
- **AND** the enqueued "Viewed Dashboard" event properties should include:
  | property                | value |
  | $process_person_profile | false |
  | $is_identified          | false |
