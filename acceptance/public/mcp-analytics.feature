@public @canonical_behavior @acceptance @mcp-analytics
Feature: MCP analytics
  Acceptance tests for the canonical MCP analytics behavior across PostHog server SDKs.
  The SDK adapter hosts a small MCP server instrumented by the SDK and acts as its MCP client.
  Unless a scenario says otherwise, the adapter's MCP transport carries no session.
  Scenarios tagged @mcp_input_required_capable, @mcp_unknown_tool_capable, @mcp_tools_list_capable, @mcp_task_store_capable,
  or tagged @mcp_missing_capability_capable or @mcp_feedback_capable cover optional behavior;
  they apply only to an SDK that declares the matching capability.

  Background:
    Given an isolated SDK instance
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token" and flush threshold 20

  @server
  Scenario: A successful tool call produces one event with the required properties
    Given an instrumented MCP server with a tool "search_docs" that returns the text "Found 3 results"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_tool_call"
    And the "$mcp_tool_call" event property "$mcp_tool_name" should equal "search_docs"
    And the "$mcp_tool_call" event property "$mcp_is_error" should equal JSON false
    And the "$mcp_tool_call" event property "$mcp_duration_ms" should be a number
    And the "$mcp_tool_call" event property "$mcp_source" should equal "posthog_mcp_analytics"
    And the "$mcp_tool_call" event property "$session_id" should be a non-empty string
    And the "$mcp_tool_call" event property "$lib" should end with "-mcp"

  @server
  Scenario: A tool result reaches the client unchanged
    Given an instrumented MCP server with conversation anchoring disabled and a tool "search_docs" that returns the text "Found 3 results"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    Then the MCP client should receive a result with exactly one text block "Found 3 results" and isError false

  @server
  Scenario: An unreachable PostHog endpoint does not affect the tool call
    Given an instrumented MCP server with a tool "search_docs" that returns the text "Found 3 results"
    And the mock PostHog server rejects all requests
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then the MCP client should receive a result that includes the text block "Found 3 results"

  @server
  Scenario: A result that asks for more input is counted once, when the call completes
    Given an instrumented MCP server with a tool "deploy" that first returns a result with resultType "input_required" carrying one "elicitation/create" request
    When the MCP client calls tool "deploy" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then no received event should be named "$mcp_tool_call"
    When the MCP client retries the call to "deploy" with the requested input
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_tool_call"

  @server @mcp_input_required_capable
  Scenario: A round that asks for more input is recorded
    Given an instrumented MCP server with a tool "deploy" that first returns a result with resultType "input_required" carrying one "elicitation/create" request
    When the MCP client calls tool "deploy" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_input_required"
    And the "$mcp_input_required" event property "$mcp_tool_name" should equal "deploy"
    And the "$mcp_input_required" event property "$mcp_input_request_methods" should equal JSON ["elicitation/create"]
    And the "$mcp_input_required" event property "$mcp_duration_ms" should be a number

  @server
  Scenario: A task handle is never counted as a successful call
    Given an instrumented MCP server with a tool "export_report" that returns a task and completes it later
    When the MCP client calls tool "export_report" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then no received event should be named "$mcp_tool_call"

  @server @mcp_task_store_capable
  Scenario: A task-backed call is counted once, when the task finishes
    Given an instrumented MCP server with a tool "export_report" that returns a task and completes it later
    When the MCP client calls tool "export_report" with JSON arguments:
      """application/json
      {}
      """
    And the task for "export_report" reaches status "completed"
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_tool_call"
    And the "$mcp_tool_call" event property "$mcp_is_error" should equal JSON false

  @server
  Scenario: Tool metadata from the server's tools is attached to calls, without a prior listing
    Given an instrumented MCP server with a tool "search_docs" described as "Search the docs" with _meta category "docs"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_tool_description" should equal "Search the docs"
    And the "$mcp_tool_call" event property "$mcp_tool_category" should equal "docs"

  @server @case:acceptance:server:mcp-analytics:failure:<case_id>
  Scenario Outline: A failed tool call is captured as an error
    Given an instrumented MCP server with a tool "fetch_page" that <failure>
    When the MCP client calls tool "fetch_page" with JSON arguments:
      """application/json
      {"url":"https://example.com"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_is_error" should equal JSON true
    And the "$mcp_tool_call" event property "$mcp_error_message" should equal "<message>"
    And the "$mcp_tool_call" event property "$mcp_error_type" should be a non-empty string

    Examples:
      | case_id      | failure                                                         | message            |
      | is_error     | returns a result with isError true and the text "403 Forbidden" | 403 Forbidden      |
      | thrown_error | throws an error with message "upstream timed out"               | upstream timed out |

  @server
  Scenario: A thrown error's type names the failure
    Given an instrumented MCP server with a tool "query" whose handler throws an error of a custom type named "UpstreamTimeout" with message "upstream timed out"
    When the MCP client calls tool "query" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_error_type" should name the type "UpstreamTimeout"
    And exactly 1 received event should be named "$exception"
    And the "$exception" event's first exception type should name the type "UpstreamTimeout"
    And the "$exception" event property "$exception_level" should equal "error"
    And the "$exception" event property "$mcp_tool_name" should equal "query"
    And the "$exception" event property "$session_id" should equal the "$mcp_tool_call" event property "$session_id"

  @server
  Scenario: An explicit error type labels the call but not the exception
    Given the SDK's manual MCP capture API records a failed call to tool "query" with error type "validation" and a thrown error of a custom type named "UpstreamTimeout"
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_error_type" should equal "validation"
    And the "$exception" event's first exception type should name the type "UpstreamTimeout"

  @server
  Scenario: A call to a tool that does not exist is not counted as a call
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "no_such_tool" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then no received event should be named "$mcp_tool_call"

  @server @mcp_unknown_tool_capable
  Scenario: A call to a tool that does not exist is recorded as unknown
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "no_such_tool" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_unknown_tool"
    And the "$mcp_unknown_tool" event property "$mcp_tool_name" should equal "no_such_tool"

  @server
  Scenario: The context argument is advertised, captured as intent, and removed
    Given an instrumented MCP server with a tool "search_docs" whose schema declares only "query"
    When the MCP client lists tools
    Then the advertised schema for tool "search_docs" should declare a string property "context"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags","context":"find the flags docs"}
      """
    And pending captures are flushed
    Then the tool handler for "search_docs" should have received JSON arguments {"query":"flags"}
    And the "$mcp_tool_call" event property "$mcp_intent" should equal "find the flags docs"
    And the "$mcp_tool_call" event property "$mcp_intent_source" should equal "context_parameter"

  @server
  Scenario: A tool that declares its own context keeps it as data, not intent
    Given an instrumented MCP server with a tool "summarize" whose schema declares a string property "context"
    When the MCP client calls tool "summarize" with JSON arguments:
      """application/json
      {"context":"the meeting notes"}
      """
    And pending captures are flushed
    Then the tool handler for "summarize" should have received JSON arguments {"context":"the meeting notes"}
    And the "$mcp_tool_call" event should not have property "$mcp_intent"
    And the "$mcp_tool_call" event property "$mcp_parameters" should include JSON {"request":{"params":{"arguments":{"context":"the meeting notes"}}}}

  @server
  Scenario: Personal data in the intent is redacted
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"orders","context":"find orders for alice@example.com"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_intent" should equal "find orders for [redacted]"

  @server
  Scenario: Clients without a session or handle never share a session
    Given an instrumented MCP server with conversation anchoring disabled and a tool "search_docs" that returns the text "ok"
    When MCP client "A" calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And MCP client "B" calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then exactly 2 received events should be named "$mcp_tool_call"
    And the two "$mcp_tool_call" events should have different "$session_id" values

  @server
  Scenario: A conversation handle keeps a stateless client's calls in one session
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    Then the MCP client result should end with a conversation_id text block
    When the MCP client calls tool "search_docs" again with the returned conversation_id
    And pending captures are flushed
    Then exactly 2 received events should be named "$mcp_tool_call"
    And both "$mcp_tool_call" events should have the same "$session_id"
    And both "$mcp_tool_call" events should have property "$mcp_conversation_id" equal to the returned conversation_id

  @server
  Scenario: A malformed conversation handle is replaced and never reaches the tool
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags","conversation_id":"not-a-uuid"}
      """
    Then the MCP client result should end with a conversation_id text block
    And the tool handler for "search_docs" should have received JSON arguments {"query":"flags"}

  @server
  Scenario: A conversation handle derives the canonical session id
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags","conversation_id":"0190f0e8-7a6b-7c3d-9e4f-5a6b7c8d9e0f"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$session_id" should equal "ses_6df45f0102a182bcd5e8dd5dad6c65a0"

  @server
  Scenario: An anonymous call does not create a person
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event's distinct_id should equal its property "$session_id"
    And the "$mcp_tool_call" event property "$process_person_profile" should equal JSON false

  @server
  Scenario: An identified call processes the person
    Given an instrumented MCP server whose identify callback returns distinct id "user-123" with properties {"plan":"pro"}
    And the instrumented MCP server has a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event field "distinct_id" should equal "user-123"
    And the "$mcp_tool_call" event property "$set" should equal JSON {"plan":"pro"}
    And the "$mcp_tool_call" event property "$process_person_profile" should not equal JSON false

  @server
  Scenario: A 2026-07-28 request identifies its client from _meta
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client on protocol revision "2026-07-28" with clientInfo name "claude-code" version "2.1.0" calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_client_name" should equal "claude-code"
    And the "$mcp_tool_call" event property "$mcp_client_version" should equal "2.1.0"
    And the "$mcp_tool_call" event property "$mcp_protocol_version" should equal "2026-07-28"

  @server
  Scenario: Arguments are captured in the request shape with injected arguments removed
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags","context":"find docs"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_parameters" should include JSON {"request":{"method":"tools/call","params":{"name":"search_docs","arguments":{"query":"flags"}}}}

  @server
  Scenario: Credentials in arguments and error text are redacted
    Given an instrumented MCP server with a tool "fetch_page" that fails with message "GET https://svc:hunter2@internal.test/doc?token=abc failed"
    When the MCP client calls tool "fetch_page" with JSON arguments:
      """application/json
      {"url":"https://svc:hunter2@internal.test/doc?token=abc","api_key":"sk-live-123"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_parameters" should not contain "hunter2"
    And the "$mcp_tool_call" event property "$mcp_parameters" should not contain "sk-live-123"
    And the "$mcp_tool_call" event property "$mcp_parameters" should not contain "token=abc"
    And the "$mcp_tool_call" event property "$mcp_error_message" should not contain "hunter2"
    And the "$mcp_tool_call" event property "$mcp_error_message" should not contain "token=abc"

  @server
  Scenario: A credential in a result's JSON text copy is redacted
    Given an instrumented MCP server with a tool "get_user" that returns structured content and a text block, both:
      """application/json
      {"user":"ada","password":"hunter2"}
      """
    When the MCP client calls tool "get_user" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then the first text block in the "$mcp_tool_call" event property "$mcp_response" should be:
      """application/json
      {"user":"ada","password":"[redacted]"}
      """
    And the "$mcp_tool_call" event property "$mcp_response" should not contain "hunter2"

  @server
  Scenario: A successful call's response is captured by default
    Given an instrumented MCP server with a tool "search_docs" that returns the text "Found 3 results"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_response" should contain "Found 3 results"

  @server
  Scenario: A failing before-send hook drops the event
    Given an instrumented MCP server with a before-send hook that throws
    And the instrumented MCP server has a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" with JSON arguments:
      """application/json
      {"query":"flags"}
      """
    And pending captures are flushed
    Then no received event should be named "$mcp_tool_call"
    And the MCP client should receive a result that includes the text block "ok"

  @server
  Scenario: Media in a result is never sent
    Given an instrumented MCP server with a tool "screenshot" that returns the text "done" and a 200 KB image
    When the MCP client calls tool "screenshot" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then the "$mcp_tool_call" event property "$mcp_response" should contain "done"
    And the "$mcp_tool_call" event property "$mcp_response" should not contain image data

  @server
  Scenario: A very large response still produces a bounded event
    Given an instrumented MCP server with a tool "export" that returns a 2 MB text block
    When the MCP client calls tool "export" with JSON arguments:
      """application/json
      {}
      """
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_tool_call"
    And the "$mcp_tool_call" event's serialized properties should be at most 102400 bytes
    And the "$mcp_tool_call" event property "$mcp_tool_name" should equal "export"

  @server @mcp_tools_list_capable
  Scenario: A tool listing records names and only the result envelope
    Given an instrumented MCP server with 101 tools and a page size of 100
    When the MCP client lists tools
    And pending captures are flushed
    Then the first "$mcp_tools_list" event property "$mcp_listed_tool_names" should be a JSON array of 100 strings
    And the first "$mcp_tools_list" event property "$mcp_response" should contain "nextCursor"
    And the first "$mcp_tools_list" event property "$mcp_response" should not contain "tools"

  @server @mcp_missing_capability_capable
  Scenario: A missing capability report carries its text as intent
    Given an instrumented MCP server with missing-capability reporting enabled
    When the MCP client calls the missing-capability tool with context "export a dashboard to PDF"
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_missing_capability"
    And the "$mcp_missing_capability" event property "$mcp_intent" should equal "export a dashboard to PDF"
    And no received event should be named "$mcp_tool_call"

  @server
  Scenario: The virtual tools are not advertised by default
    Given an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client lists tools
    Then the MCP client should not see a tool named "send_feedback"
    And the MCP client should not see a tool named "get_more_tools"

  @server @mcp_feedback_capable
  Scenario: A feedback report becomes one feedback event
    Given an instrumented MCP server with feedback reporting enabled
    And the identify option resolves the user "user-1"
    When the MCP client calls tool "send_feedback" with JSON arguments:
      """application/json
      {"feedback_type":"issue","summary":"search_docs ignored my filter; reach me at ada@example.com","tool_name":"search_docs","sentiment":"negative"}
      """
    And pending captures are flushed
    Then exactly 1 received event should be named "$mcp_feedback"
    And the "$mcp_feedback" event property "$mcp_feedback_type" should equal "issue"
    And the "$mcp_feedback" event property "$mcp_feedback_tool" should equal "search_docs"
    And the "$mcp_feedback" event property "$mcp_feedback_sentiment" should equal "negative"
    And the "$mcp_feedback" event property "$mcp_feedback_summary" should contain "search_docs ignored my filter"
    And the "$mcp_feedback" event should not have property "$mcp_parameters"
    And the "$mcp_feedback" event property "$session_id" should be a non-empty string
    And no received event should contain "ada@example.com"
    And no received event should be named "$mcp_tool_call"

  @server @mcp_feedback_capable
  Scenario: Only declared extra report arguments are captured
    Given an instrumented MCP server with feedback reporting enabled and a declared report argument "severity" of type integer
    When the MCP client calls tool "send_feedback" with JSON arguments:
      """application/json
      {"feedback_type":"issue","summary":"search is slow","severity":3,"invented":"x"}
      """
    And pending captures are flushed
    Then the "$mcp_feedback" event property "$mcp_feedback_severity" should equal 3
    And the "$mcp_feedback" event should not have property "$mcp_feedback_invented"

  @server
  Scenario: A resource's contents never reach PostHog
    Given an instrumented MCP server with a resource "docs://guide" whose text is "RESOURCE-BODY-7f3a"
    When the MCP client reads resource "docs://guide"
    And pending captures are flushed
    Then the MCP client should receive a resource whose text is "RESOURCE-BODY-7f3a"
    And no received event should contain "RESOURCE-BODY-7f3a"

  @server
  Scenario: A manually captured call matches the automatic one
    Given an MCP server that dispatches tool "search_docs" itself through the SDK's manual API
    And an instrumented MCP server with a tool "search_docs" that returns the text "ok"
    When the MCP client calls tool "search_docs" on each server with JSON arguments:
      """application/json
      {"query":"flags","context":"find the flags docs"}
      """
    And pending captures are flushed
    Then exactly 2 received events should be named "$mcp_tool_call"
    And both "$mcp_tool_call" events should have equal properties "$mcp_tool_name", "$mcp_intent", "$mcp_parameters", and "$mcp_is_error"
    And both "$mcp_tool_call" events should have property "$session_id" as a non-empty string
