## ADDED Requirements

### Requirement: Event options

An MCP SDK SHALL name event options apart from its MCP configuration, and on capture v1 SHOULD let the
host set them (`capture`, **Per-event options replace the legacy option properties**) on MCP events:
per request, through a callback that receives the request like the event properties callback, and per
call, on its custom-event and manual capture methods. Its MCP configuration is also called options, so
the SDK uses names such as `event_options` in posthog-python and posthog-rs, `eventOptions` in
`@posthog/mcp`, and `EventOptions` with `WithEventOptions` in posthog-go. A method that is the core client's own capture keeps the core
`options` argument. A failed tool call's `$exception` SHALL carry the options of its `$mcp_tool_call`.

Options merge key by key, each layer winning over the one before it: the request-level callback, then
the per-call value, then the anonymous `process_person_profile: false` of "Person identity", except
where an SDK takes the divergence that requirement allows. Event options are the event's own, so
request-context and global options fill only the keys they leave unset. Before-send hooks see the
merged options and can change them. A callback that fails SHALL NOT fail the request; the event is
sent without its options.

#### Scenario: A callback option reaches an anonymous call, which stays personless
- **GIVEN** an MCP server instrumented by the SDK with no identify option, on capture v1
- **AND** an event options callback that returns {"cookieless_mode":true}
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's event option "cookieless_mode" should be the boolean true
- **AND** its event option "process_person_profile" should be the boolean false

## MODIFIED Requirements

### Requirement: Person identity

The event `distinct_id` SHALL be the identity the server resolves for the request, else `$session_id`.
Without a resolved identity every event, `$exception` included, SHALL turn person processing off, so
anonymous calls create no person profiles. On capture v1 the SDK SHALL set the `process_person_profile:
false` event option and SHALL NOT write the legacy `$process_person_profile` property (`capture`,
**Per-event options replace the legacy option properties**); on legacy capture it SHALL set the
`$process_person_profile: false` property. This anonymous default wins over every other source of the
option (see "Event options"); a before-send hook can still change it. An SDK MAY instead let an explicit
`process_person_profile` the caller supplies win over the anonymous default, and SHALL document that it
does; posthog-node's `@posthog/mcp` does. With a resolved identity, the SDK SHALL NOT set it, and SHALL
send identity properties as `$set` and groups as `$groups` on every event. The SDK SHALL NOT send a
standalone `$identify` event, for any MCP revision or session mode. It would carry no
`$anon_distinct_id`, so ingestion would merge no person, and every event already carries the identity.

#### Scenario: An anonymous call does not create a person
- **GIVEN** an MCP server instrumented by the SDK on capture v1 with no identify option
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's distinct_id should equal its "$session_id"
- **AND** its event option "process_person_profile" should be the boolean false
- **AND** its property "$process_person_profile" should be absent

#### Scenario: An identified call sends no $identify
- **GIVEN** an MCP server instrumented by the SDK whose identify option resolves distinct id "user-123" with properties {"plan":"pro"}
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's distinct_id should be "user-123"
- **AND** its property "$set" should equal {"plan":"pro"}
- **AND** no "$identify" event should be sent

### Requirement: Library identity

MCP events SHALL be identified by their `$mcp_` event name prefix and `$mcp_source`, and SHALL carry `$lib`
as `posthog-<runtime>-mcp` (such as `posthog-node-mcp`, `posthog-python-mcp`, `posthog-rs-mcp`,
`posthog-go-mcp`) with `$lib_version` the version of the installed package that ships the instrumentation.
The SDK SHOULD label MCP events one by one, as an integration label (`capture`, **Events name their own
library**), so events the host application captures through the same client keep the SDK's own `$lib`. Where
the platform can only label the whole client, the SDK MAY label a dedicated client `posthog-<runtime>-mcp`
and SHALL document that MCP analytics needs a dedicated client. A `$lib` in the call's `properties`, and
`before_send`, win over the label.

#### Scenario: Events name the MCP instrumentation
- **GIVEN** an MCP server instrumented by the SDK
- **WHEN** an MCP client calls tool "search_docs"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_source" should be the string "posthog_mcp_analytics"
- **AND** the "$mcp_tool_call" event's property "$lib" should end with "-mcp"

### Requirement: Event size bounds

Every MCP event's properties, `$set` and `$groups` included, SHALL serialize to at most 102,400 bytes
of compact UTF-8 JSON, without ever dropping the event or a required property of "Tool call event". The
bound covers the properties the MCP instrumentation builds; values the client adds afterwards from its
global or context layers (`capture`) are outside it, and capture's own event size limit applies to them. The
SDK SHALL shrink `$mcp_response` and `$mcp_parameters` first and other optional properties after them.
To shrink is to truncate string values to a smaller cap of the SDK's choosing, keeping their start, and
to drop the property only when it still does not fit; the order is normative, the caps are not;
`$mcp_error_message` is truncated, never dropped. The SDK SHOULD bound them in one pass (apply the
limits of "Property reference" first, then measure) rather than re-serializing repeatedly.

#### Scenario: A very large response still produces a bounded event
- **GIVEN** an MCP server instrumented by the SDK with a tool "export" that returns a 2 MB text block
- **WHEN** an MCP client calls tool "export"
- **AND** the SDK is flushed
- **THEN** exactly one event named "$mcp_tool_call" should be sent
- **AND** its serialized properties should be at most 102400 bytes
- **AND** it should have properties "$mcp_tool_name", "$mcp_is_error", "$mcp_duration_ms", and "$session_id"
