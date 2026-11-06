## MODIFIED Requirements

### Requirement: Capture v1 request headers

An SDK that delivers events through capture v1 SHALL send these headers on every capture request:

- `Authorization: Bearer <project token>`. The token is never placed in the body.
- `Content-Type: application/json`.
- `User-Agent`, equal to the `PostHog-Sdk-Info` value.
- `PostHog-Sdk-Info: <library>/<version>`, where `<library>` is the SDK's own canonical `$lib` name (`posthog-python`, `posthog-go`, `posthog-rs`, `posthog-node`, `posthog-ios`, `posthog-android`, `posthog-flutter`) and `<version>` is the package version actually shipped. Capture derives `$lib` and `$lib_version` from this header, so a built-in integration SHALL NOT relabel the client. A wrapper SDK whose events a native SDK delivers (posthog-flutter on iOS, macOS and Android, KMP, and the React Native plugin, which uses `posthog-react-native`) configures the native SDK with its own library name and version, as `$lib` did on legacy capture. posthog-flutter on Windows and Linux has its own transport and sends `posthog-flutter` directly.
- `PostHog-Request-Id`: a UUID minted once per batch and kept across every retry of that batch.
- `PostHog-Attempt`: `1` on the first attempt, incremented by one on each retry of the same batch.
- `PostHog-Request-Timestamp`: the send time of this attempt as an RFC 3339 string with an explicit offset and at least three fractional-second digits (see **Timestamps on capture v1**), taken from the same clock as the event timestamps and stamped again on every attempt.
- `Content-Encoding` only when the body is compressed, with one of `gzip`, `deflate`, `br` or `zstd`.

Every header value SHALL be visible ASCII. The body's `created_at` SHALL be set once per batch and kept across retries. Capture uses `PostHog-Request-Timestamp` to correct for client clock skew, so a retry that resends a stale timestamp shifts every event in the request by the retry delay; the SDK SHALL NOT let an HTTP library retry a capture request on its behalf.

A retry SHALL resend exactly the events it retries: every event of a batch that failed as a whole with a retryable status or a network error, or only the `retry` events of a 2xx `results` map. Events captured after the batch was first sent SHALL NOT join the retry, even when they are queued before it goes out. The retry keeps the batch's `PostHog-Request-Id` and `created_at` and increments `PostHog-Attempt`. The newer events go in a later batch with a new `PostHog-Request-Id` and `PostHog-Attempt: 1`. A server SDK retries inside one send, so the set it resends only shrinks and new events cannot join it. Events a server SDK puts back on its queue after a last attempt with no HTTP response (see `retry-queue`) go out in a new batch. A client SDK with a durable disk queue keeps the retry identity (request ID, attempt number and `created_at`) in memory with the queue entries it retries. When one of those entries is no longer in the queue (capacity eviction or a clear removed it), after the app restarts, or when the SDK halves a batch after a `413`, the SDK SHALL build its next batch from the queue as usual, with a new `PostHog-Request-Id` and `PostHog-Attempt: 1`. Capture uses the request ID and attempt number only for its logs and metrics, so starting over costs nothing but the attempt count.

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
- **AND** the first request header "PostHog-Request-Timestamp" should be an RFC 3339 timestamp with an explicit offset and at least 3 fractional-second digits

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

#### Scenario: Events captured during a retry wait go in their own request (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the mock serves these ordered analytics responses:
  | status | headers             |
  | 503    | {"Retry-After":"5"} |
  | 200    | {}                  |
  | 200    | {}                  |
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 10
- **WHEN** capture is called with distinct id "test_user" and event "first_event"
- **AND** pending captures are flushed
- **AND** 1000 milliseconds elapse without a public SDK call
- **AND** capture is called with distinct id "test_user" and event "new_event"
- **AND** pending captures are flushed
- **AND** 8000 milliseconds elapse without a public SDK call
- **THEN** the analytics capture requests should be, in order:
  | events          | posthog-attempt | posthog-request-id | created_at |
  | ["first_event"] | 1               | A                  | A          |
  | ["first_event"] | 2               | A                  | A          |
  | ["new_event"]   | 1               | B                  | B          |
- **AND** the present event "uuid" lists in requests zero and one should be identical

#### Scenario: Events captured during a per-event retry wait go in their own request (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the mock serves these ordered analytics responses:
  | status | headers             | event_results    |
  | 200    | {"Retry-After":"5"} | ["ok","retry"]   |
  | 200    | {}                  | null             |
  | 200    | {}                  | null             |
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 10
- **WHEN** capture is called with distinct id "test_user" and event "first_event_0"
- **AND** capture is called with distinct id "test_user" and event "first_event_1"
- **AND** pending captures are flushed
- **AND** 1000 milliseconds elapse without a public SDK call
- **AND** capture is called with distinct id "test_user" and event "new_event"
- **AND** pending captures are flushed
- **AND** 8000 milliseconds elapse without a public SDK call
- **THEN** the analytics capture requests should be, in order:
  | events                            | posthog-attempt | posthog-request-id | created_at |
  | ["first_event_0","first_event_1"] | 1               | A                  | A          |
  | ["first_event_1"]                 | 2               | A                  | A          |
  | ["new_event"]                     | 1               | B                  | B          |

#### Scenario: A retry whose events left the queue starts a new request (@client)
- **GIVEN** a client SDK with a durable disk queue whose request with id "R" and attempt 1 failed with HTTP 503
- **AND** capacity eviction removed one of that request's events from the queue
- **WHEN** the SDK sends its next capture request
- **THEN** that request has a `PostHog-Request-Id` other than "R"
- **AND** its `PostHog-Attempt` is 1
