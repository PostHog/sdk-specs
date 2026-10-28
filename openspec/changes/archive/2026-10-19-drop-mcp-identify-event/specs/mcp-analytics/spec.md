## MODIFIED Requirements

### Requirement: Person identity

The event `distinct_id` SHALL be the identity the server resolves for the request, else `$session_id`.
Without a resolved identity every event, `$exception` included, SHALL set `$process_person_profile:
false`, so anonymous calls create no person profiles. With one, the SDK SHALL NOT set it, and SHALL
send identity properties as `$set` and groups as `$groups` on every event. The SDK SHALL NOT send a
standalone `$identify` event, for any MCP revision or session mode. It would carry no
`$anon_distinct_id`, so ingestion would merge no person, and every event already carries the identity.

#### Scenario: An anonymous call does not create a person
- **GIVEN** an MCP server instrumented by the SDK with no identify option
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's distinct_id should equal its "$session_id"
- **AND** its property "$process_person_profile" should be the boolean false

#### Scenario: An identified call sends no $identify
- **GIVEN** an MCP server instrumented by the SDK whose identify option resolves distinct id "user-123" with properties {"plan":"pro"}
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's distinct_id should be "user-123"
- **AND** its property "$set" should equal {"plan":"pro"}
- **AND** no "$identify" event should be sent
