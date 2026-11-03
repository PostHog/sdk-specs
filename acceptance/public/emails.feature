@public @canonical_behavior @acceptance @emails @server
Feature: Emails
  Canonical contract: openspec/specs/emails/spec.md
  These scenarios require email harness bindings before integration selection.

  Background:
    Given an isolated SDK instance
    And the mock PostHog server is reset

  # Requirement: Send request

  Scenario: A send posts the template and its data to the app host
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will accept the next email send with message ID "msg_1"
    When the caller sends to "user@example.com" with template ID "0190F6D2-7C1E-7B3A-9F5E-1C2D3E4F5A6B", template data {"name":"Ada"} and distinct ID "user_123"
    Then the mock server should receive 1 email send request to "https://us.posthog.com/api/projects/@current/messaging/send/email/"
    And the request header "Authorization" should equal "Bearer phs_test"
    And the request body should equal JSON {"template_id":"0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b","to":"user@example.com","message_data":{"name":"Ada"},"distinct_id":"user_123"}
    And the send result should have ID "msg_1" and replayed false

  # Requirement: Custom host refusal

  Scenario: A custom host without an app host never receives the secret key
    Given the SDK is initialized with token "test-token", host "https://proxy.example.com" and secret key "phs_test"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the send should fail with error code "missing_app_host"
    And the mock server should receive no requests

  # Requirement: Secret key

  Scenario: A client without a secret key sends nothing
    Given the SDK is initialized with token "test-token" and host "https://us.i.posthog.com"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the send should fail with error code "missing_secret_key"
    And the mock server should receive no requests

  # Requirements: Idempotency key, Retryable responses

  Scenario: Retries reuse the generated idempotency key
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will fail the next email send with status 503
    And the mock server will accept the next email send with message ID "msg_1"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the mock server should receive 2 email send requests
    And both requests should carry the same "Idempotency-Key", which is a UUID v4
    And the send result should have ID "msg_1"

  Scenario Outline: Only responses that waiting can fix are retried
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will fail the next email send with status <status> and code "<code>"
    And the mock server will accept the next email send with message ID "msg_1"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the mock server should receive <requests> email send requests

    Examples:
      | status | code                      | requests |
      | 503    | delivery_unavailable      | 2        |
      | 429    | throttled                 | 2        |
      | 409    | idempotency_key_in_flight | 2        |
      | 429    | quota_limited             | 1        |
      | 422    | recipient_suppressed      | 1        |

  # Requirement: Send response without a message ID

  Scenario: An acceptance without a message ID is an error and is not retried
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will answer the next email send with status 202 and body {}
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the mock server should receive 1 email send request
    And the send should fail with error code "api_error" and status 202

  # Requirement: Retry timing

  Scenario: A Retry-After over 30 seconds fails at once
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will fail the next email send with status 429, code "throttled" and header "Retry-After: 60"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the mock server should receive 1 email send request
    And the send should fail with error code "throttled" and a retry-after of 60 seconds

  # Requirements: Error fields, Error names

  Scenario Outline: Errors keep PostHog's code and carry a category name
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will fail the next email send with status <status> and code "<code>"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b" and a per-send retry limit of 0
    Then the send should fail with error code "<code>", name "<name>" and status <status>

    Examples:
      | status | code                   | name                       |
      | 401    | authentication_failed  | missing_api_key            |
      | 404    | not_found              | not_found                  |
      | 422    | idempotency_key_reused | invalid_idempotent_request |
      | 422    | recipient_suppressed   | validation_error           |
      | 429    | quota_limited          | monthly_quota_exceeded     |

  # Requirements: Status read request, Status record

  Scenario: A status read returns the email's status
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will return the email status {"id":"01a18356-c56c-0001-e494-7666bc915188","status":"bounced","created_at":"2026-10-28T16:27:44.364000Z","status_at":"2026-10-28T16:30:02.100000Z","reason":"hard"}
    When the caller reads the status of message ID "01A18356-C56C-0001-E494-7666BC915188"
    Then the mock server should receive 1 request "GET https://us.posthog.com/api/projects/@current/messaging/emails/01a18356-c56c-0001-e494-7666bc915188/"
    And the status record should have status "bounced", reason "hard" and both times

  Scenario: An unknown message ID is not retried
    Given the SDK is initialized with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    And the mock server will fail the next email status read with status 404 and code "not_found"
    When the caller reads the status of message ID "01a18356-c56c-0001-e494-7666bc915188"
    Then the mock server should receive 1 email status request
    And the status read should fail with error code "not_found"

  # Requirement: Disabled client

  Scenario: A disabled client sends nothing
    Given the SDK is initialized disabled with token "test-token", host "https://us.i.posthog.com" and secret key "phs_test"
    When the caller sends to "user@example.com" with template ID "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"
    Then the send should fail with error code "client_disabled"
    And the mock server should receive no requests
