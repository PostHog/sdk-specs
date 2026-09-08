@public @canonical_behavior @acceptance @capture @both
Feature: Capture
  Acceptance tests for the canonical capture behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client capture enriches an event with ambient context
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "user-123"
    And the current session id is "session-123"
    And registered properties are:
      | property | value |
      | plan     | pro   |
    When capture is called with event "Signed Up" and properties:
      | property | value |
      | source   | ad    |
    Then one event named "Signed Up" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event properties should include:
      | property    | value       |
      | source      | ad          |
      | plan        | pro         |
      | $session_id | session-123 |
    And the enqueued event should include a timestamp and uuid

  @server
  Scenario: Server capture requires an explicit distinct id
    Given the SDK is initialized with token "test-token"
    When capture is called with distinct id "user-123", event "Signed Up", and properties:
      | property | value |
      | source   | api   |
    Then one event named "Signed Up" should be enqueued
    And the enqueued event distinct id should be "user-123"
    And the enqueued event properties should include:
      | property | value |
      | source   | api   |
      | $lib     | any   |
    And the enqueued event should include an event uuid

  @both
  Scenario: Queued capture drops null-valued properties and preserves array positions
    Given the SDK is initialized with token "test-token"
    And capture has a valid distinct id and no property-changing hooks or filters
    When capture is called with event "Nullable Properties" and custom properties represented by JSON:
      """json
      {"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null},[null]],"empty":"","zero":0,"enabled":false,"literal":"null","emptyArray":[]}
      """
    And the SDK is flushed
    Then one event named "Nullable Properties" should be received
    And its custom properties should equal JSON:
      """json
      {"nested":{},"items":["1",null,2,{},[null]],"empty":"","zero":0,"enabled":false,"literal":"null","emptyArray":[]}
      """
    And the absent custom property "missing" should remain absent

  @both
  Scenario: Immediate capture drops null-valued properties and preserves array positions
    Given the SDK is initialized with token "test-token"
    And the SDK supports immediate delivery
    And capture has a valid distinct id and no property-changing hooks or filters
    And capture is configured for immediate delivery
    When capture is called with event "Nullable Properties" and custom properties represented by JSON:
      """json
      {"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null},[null]]}
      """
    And the immediate send completes
    Then one event named "Nullable Properties" should be received
    And its custom properties should equal JSON:
      """json
      {"nested":{},"items":["1",null,2,{},[null]]}
      """

  @both
  Scenario: All-null custom properties do not drop the event
    Given the SDK is initialized with token "test-token"
    And capture has a valid distinct id and no property-changing hooks or filters
    When capture is called with event "Only Null Properties" and custom properties represented by JSON:
      """json
      {"test":null}
      """
    And the SDK is flushed
    Then one event named "Only Null Properties" should be received
    And its custom properties should equal JSON:
      """json
      {}
      """
    And it should retain its normal SDK metadata

  @both
  Scenario: Null object properties introduced by before-send are omitted
    Given the SDK is initialized with token "test-token"
    And the SDK supports before-send with a valid distinct id
    And before-send adds custom properties represented by JSON:
      """json
      {"hookNull":null,"hookItems":[null,{"drop":null}]}
      """
    When capture is called with event "Hook Properties" and no custom properties
    And the SDK is flushed
    Then one event named "Hook Properties" should be received
    And its custom properties should equal JSON:
      """json
      {"hookItems":[null,{}]}
      """

  @both
  Scenario: JavaScript null and undefined object properties are omitted
    Given a JavaScript SDK is initialized with token "test-token"
    And capture has a valid distinct id and no property-changing hooks or filters
    When capture is called with event "Null And Undefined" and JavaScript properties:
      """javascript
      { test: null, missing: undefined, items: ["1", null, 2] }
      """
    And the SDK is flushed
    Then one event named "Null And Undefined" should be received
    And its custom properties should equal JSON:
      """json
      {"items":["1",null,2]}
      """

  @both
  Scenario: Existing nullable capture inputs remain supported
    Given the SDK's existing public capture API accepts null or undefined property values
    And an existing caller supplies those values using the supported public property types
    When the SDK adopts the serialization cleanup rule
    Then the same caller code should remain accepted by the public API, including compilation/type-checking where enforced
    And capture should not reject the call or require caller-side filtering solely because of those values
    And serializing the captured event should omit null/undefined-valued object members while preserving array positions

  @both
  Scenario: Disk-backed event serialization omits null object properties
    Given the SDK is initialized with token "test-token"
    And the SDK has disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
    And network delivery is paused
    When capture is called with event "Persisted Properties" and custom properties represented by JSON:
      """json
      {"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null}]}
      """
    And the SDK serializes the queued event to disk
    Then the persisted event's decoded custom properties should equal JSON:
      """json
      {"nested":{},"items":["1",null,2,{}]}
      """
    And no network request should have been sent
    When the persisted event is restored and delivered
    Then the received event's custom properties should equal JSON:
      """json
      {"nested":{},"items":["1",null,2,{}]}
      """

  @both
  Scenario: JavaScript disk serialization omits undefined object members without compacting arrays
    Given a JavaScript SDK is initialized with token "test-token"
    And the SDK has disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
    And network delivery is paused
    When capture is called with event "Persisted Undefined" and JavaScript properties:
      """javascript
      { test: null, missing: undefined, nested: { missing: undefined }, items: ["1", undefined, null, 2], literal: "undefined" }
      """
    And the SDK serializes the queued event to disk
    Then the persisted event's decoded custom properties should equal JSON:
      """json
      {"nested":{},"items":["1",null,null,2],"literal":"undefined"}
      """
    And no network request should have been sent
    When the persisted event is restored and delivered
    Then the received event's custom properties should equal JSON:
      """json
      {"nested":{},"items":["1",null,null,2],"literal":"undefined"}
      """

  @both
  Scenario: Capture honors opt-out state
    Given the SDK is initialized with token "test-token"
    And analytics capture is opted out
    When capture is called with event "Ignored Event"
    Then no event should be enqueued
    And no network request should be sent

  @both
  Scenario: Capture can be modified or dropped by before-send
    Given the SDK is initialized with token "test-token"
    And before-send adds property "filtered" with value "yes"
    When capture is called with event "Filtered Event"
    Then one event named "Filtered Event" should be enqueued
    And the enqueued event property "filtered" should equal "yes"
    When before-send is changed to drop every event
    And capture is called with event "Dropped Event"
    Then no event named "Dropped Event" should be enqueued

  @both
  Scenario: Capture drops an immediately delivered event when before-send throws
    Given the SDK is initialized with token "test-token"
    And capture is configured for immediate delivery
    And before-send throws an exception
    When capture is called with event "Sensitive Event"
    Then the capture call should not throw
    And no event named "Sensitive Event" should be enqueued
    And no network request should be sent
    And the SDK should record a before-send warning
