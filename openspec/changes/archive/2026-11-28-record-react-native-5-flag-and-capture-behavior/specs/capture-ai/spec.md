## MODIFIED Requirements

### Requirement: AI events travel on their own lane to the capture v1 AI endpoint

An SDK that delivers events through capture v1 and supports AI capture SHALL send events captured through its AI method with `POST {host}/i/v1/ai/events`, using the request body, headers, per-event results and retry rules defined for analytics capture in `capture` and `retry-queue`. The AI method SHALL send the event as given, with the same event-building order as `capture`, and SHALL NOT reroute by event name: a non-`$ai_` event captured through the AI method is sent to the AI endpoint, where capture drops it with `details: misrouted_event`, and an `$ai_*` event captured through `capture` is sent to the analytics endpoint. The SDK MAY log at debug level when the AI method receives a non-`$ai_` name.

The AI lane SHALL have its own queue, flush cycle, retry state and in-flight request, started lazily on the first AI event on server SDKs, so that a slow or failing AI lane never delays, drops or resends analytics events, and the reverse. `flush()` and `shutdown()` SHALL signal both lanes before waiting on either, under one deadline. Client SDKs: the AI queue is durable (on disk), starts at launch so events left from an earlier launch are sent, and `flush()` and `close()` signal both lanes without blocking. Allowed variation: a client SDK whose storage backends can't hold large events MAY keep the AI queue in memory on those backends. posthog-react-native 5.0 keeps it on disk, in the app's cache directory, only when it uses Expo's file system; with `persistence: 'memory'`, `customStorage` or AsyncStorage the queue is kept in memory and is lost when the app exits.

Every platform of an SDK that delivers events through capture v1 SHALL ship this lane and the AI method; a wrapper SDK SHALL NOT leave a capture v1 platform without them. On a platform still on legacy capture (for example a wrapper's web platform that sends through posthog-js), the AI method SHALL send nothing, log that AI capture is unsupported there, and return the SDK's not-admitted value, and SHALL NOT fall back to `capture`.

Capture also accepts `$ai_*` events on the analytics endpoint and forwards them to the AI pipeline, but only temporarily; the SDK and its built-in integrations SHALL NOT rely on it.

Legacy capture: the AI route was `/i/v0/ai/batch/`, which rejected a whole batch containing a non-AI event.

#### Scenario: AI capture uses the capture v1 AI endpoint (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture_ai is called with JSON arguments:
  """application/json
  {"distinct_id":"test_user","event":"$ai_generation","properties":{"$ai_model":"gpt"}}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be one of:
  | path             |
  | /i/v1/ai/events  |
- **AND** the first received event field "event" should equal "$ai_generation"
- **AND** the first request should authenticate with bearer token "phc_test_key"

#### Scenario: Ordinary capture does not reroute AI-named events (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"test_user","event":"$ai_generation"}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be one of:
  | path                   |
  | /i/v1/analytics/events |
- **AND** no capture request should use "/i/v1/ai/events"

#### Scenario: A non-AI event on the AI method is sent and its misroute is reported (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered AI responses:
  | status | body                                                          |
  | 200    | {"results":{"*":{"result":"drop","details":"misrouted_event"}}} |
- **WHEN** capture_ai is called with JSON arguments:
  """application/json
  {"distinct_id":"test_user","event":"button_clicked"}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be one of:
  | path             |
  | /i/v1/ai/events  |
- **AND** the SDK should report the event "button_clicked" as dropped with details "misrouted_event"

#### Scenario: A failing AI lane does not delay analytics delivery (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock delays every request to "/i/v1/ai/events" until released
- **WHEN** capture_ai is called with distinct id "test_user" and event "$ai_generation"
- **AND** capture is called with distinct id "test_user" and event "button_clicked"
- **AND** 2000 milliseconds elapse without a public SDK call
- **THEN** the analytics batch endpoint should have received "button_clicked"
- **WHEN** the delayed AI request is released and succeeds
- **AND** pending captures are flushed
- **THEN** the AI batch endpoint should have received "$ai_generation"
