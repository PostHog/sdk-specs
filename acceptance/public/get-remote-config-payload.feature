@public @canonical_behavior @acceptance @get_remote_config_payload @server
Feature: Get Remote Config Payload
  Canonical contract: openspec/specs/get-remote-config-payload/spec.md
  These scenarios require remote config payload harness bindings before integration selection.
  Scenarios tagged @flag_key_encoding_capable or @failure_status_capable apply only to an SDK that follows the matching recommendation.

  Background:
    Given an isolated SDK instance
    And the mock PostHog server is reset

  # Requirements: Public surface, Request, Authentication, One request per call

  Scenario: A plain key reaches the remote config route with the secret key in the header
    Given the SDK is initialized with token "TEST_API_KEY", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with the body {"foo":"bar"}
    When the caller reads the remote config payload of "test-flag"
    Then the mock server should receive 1 request "GET http://example.com/api/projects/@current/feature_flags/test-flag/remote_config?token=TEST_API_KEY"
    And the request header "Authorization" should equal "Bearer phs_test"
    And the request URL should not contain "phs_test"
    And the request should have no body
    And the returned payload should equal JSON {"foo":"bar"}

  # Requirement: Flag key encoding (a recommendation)

  @flag_key_encoding_capable
  Scenario Outline: A key with reserved characters stays one path segment
    Given the SDK is initialized with token "TEST_API_KEY", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with the body {}
    When the caller reads the remote config payload of <key>
    Then the mock server should receive 1 request "GET http://example.com/api/projects/@current/feature_flags/<segment>/remote_config?token=TEST_API_KEY"

    Examples:
      | key           | segment             |
      | "a/b?c#d e"   | a%2Fb%3Fc%23d%20e   |
      | "50%"         | 50%25               |
      | "a%2Fb"       | a%252Fb             |
      | "café"        | caf%C3%A9           |

  # Requirement: No distinct id

  Scenario: The request context does not reach the request
    Given the SDK is initialized with token "TEST_API_KEY", host "http://example.com" and secret key "phs_test"
    And the request context has distinct ID "context_user"
    And the mock server will answer the next remote config request with the body {}
    When the caller reads the remote config payload of "test-flag"
    Then the request URL should have no query parameter other than "token"
    And no part of the request should contain "context_user"

  # Requirement: Disabled client or missing project token

  Scenario: A disabled client sends nothing
    Given the SDK is initialized disabled with token "test-token", host "http://example.com" and secret key "phs_test"
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    And the mock server should receive no requests

  Scenario: A blank project token sends nothing
    Given the SDK is initialized with token "  ", host "http://example.com" and secret key "phs_test"
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    And the mock server should receive no requests

  Scenario: A disabled client does not report a missing secret key
    Given the SDK is initialized disabled with token "test-token" and host "http://example.com"
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    And the call should not report a missing secret key
    And the mock server should receive no requests

  # Requirement: Missing secret key

  Scenario Outline: A missing secret key sends nothing
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key <key>
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no payload
    And the mock server should receive no requests

    Examples:
      | key      |
      | not set  |
      | ""       |
      | "   "    |

  # Requirements: Payload decoding, String that is not JSON

  Scenario Outline: The body decodes to the payload
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with the body <body>
    When the caller reads the remote config payload of "test-flag"
    Then the returned payload should equal JSON <payload>

    Examples:
      | body                              | payload                 |
      | {}                                | {}                      |
      | {"foo":["bar","baz"]}             | {"foo":["bar","baz"]}   |
      | "{ \"foo\":[\"bar\",\"baz\"]}"    | {"foo":["bar","baz"]}   |
      | "[1,2]"                           | [1,2]                   |
      | "123"                             | 123                     |
      | ["{\"a\":1}"]                     | ["{\"a\":1}"]           |
      | "hello world"                     | "hello world"           |
      | "{broken"                         | "{broken"               |
      | ""                                | ""                      |

  # Requirements: Failure status (a recommendation), One request per call

  @failure_status_capable
  Scenario Outline: A failure status gives no payload
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with status <status> and body <body>
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    And the call should return no payload
    And the call should not raise an exception
    And the mock server should receive 1 remote config request

    Examples:
      | status | body                                 |
      | 401    | {"detail":"Authentication failed"}  |
      | 404    | {"detail":"Not found."}              |
      | 500    | {"detail":"Server error"}            |

  @failure_status_capable
  Scenario: A later call works after a failure status
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with status 401 and body {"detail":"Authentication failed"}
    And the mock server will answer the next remote config request with the body {"a":1}
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    When the caller reads the remote config payload of "test-flag"
    Then the returned payload should equal JSON {"a":1}

  # Requirements: Request failure, One request per call

  Scenario: An unreachable host gives no result
    Given the SDK is initialized with token "test-token", a host that refuses connections and secret key "phs_test"
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    And the call should not raise an exception

  Scenario: A failed call is not retried and a later call works
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key "phs_test"
    And the mock server will close the connection on the next remote config request
    And the mock server will answer the next remote config request with the body {"a":1}
    When the caller reads the remote config payload of "test-flag"
    Then the call should return no result
    And the mock server should receive 1 remote config request
    When the caller reads the remote config payload of "test-flag"
    Then the returned payload should equal JSON {"a":1}
    And the mock server should receive 2 remote config requests in total

  # Requirement: No caching

  Scenario: A second call sees a changed payload
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with the body {"v":1}
    And the mock server will answer the next remote config request with the body {"v":2}
    When the caller reads the remote config payload of "test-flag"
    And the caller reads the remote config payload of "test-flag"
    Then the first call should return JSON {"v":1}
    And the second call should return JSON {"v":2}
    And the mock server should receive 2 remote config requests
    And no request should have the header "If-None-Match"

  # Requirement: No events

  Scenario: A call captures no event
    Given the SDK is initialized with token "test-token", host "http://example.com" and secret key "phs_test"
    And the mock server will answer the next remote config request with the body {}
    When the caller reads the remote config payload of "test-flag"
    And the caller flushes
    Then the mock server should receive no capture requests
    And the mock server should receive no event named "$feature_flag_called"

  # Requirement: Independent of local evaluation

  Scenario: Local evaluation off
    Given the SDK is initialized with token "test-token", host "http://example.com", secret key "phs_test" and local evaluation off
    And the mock server will answer the next remote config request with the body {}
    When the caller reads the remote config payload of "test-flag"
    Then the mock server should receive 1 request
    And that request should be the remote config request for "test-flag"
