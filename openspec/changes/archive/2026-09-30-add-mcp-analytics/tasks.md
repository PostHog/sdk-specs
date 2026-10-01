## 1. Verification

- [x] 1.1 Inventory `@posthog/mcp` and `posthog.mcp` behavior from source (events, properties,
  sessions, intent, sanitization, truncation, errors, options) and list their differences
- [x] 1.2 Map which `$mcp_*` properties the PostHog product reads, the semantics it assumes, and
  which properties no surface reads
- [x] 1.3 Check the contract against MCP revision 2026-07-28 (stateless requests, per-request `_meta`
  identity, multi-round-trip tool calls, error model) and open SEPs 2817 and 2145
- [x] 1.4 Verify the property shapes end to end: a go-sdk server instrumented with posthog-go sent
  events to a PostHog project, and the stored properties and the MCP tool-stats query were checked
- [x] 1.5 Probe `@posthog/mcp` and `posthog.mcp` on real servers across 2025-11-25 (stateful,
  stateless, stdio) and 2026-07-28 with a per-event checker; the findings are in design.md

## 2. Spec delta

- [x] 2.1 Write the `mcp-analytics` delta: observer-only instrumentation, tool call event, failure
  capture, session identity, person identity, client and server identity, arguments the SDK injects,
  payload capture, manual capture, payload privacy, event size bounds, library identity, optional events
- [x] 2.2 Review the delta: every requirement has at least one scenario, and scenarios use WHEN/THEN

## 3. Acceptance feature

- [x] 3.1 Add `acceptance/public/mcp-analytics.feature` with `@sdk:server` scenarios for the tool call
  event, failures, observer behavior, intent, sessions, payload privacy, and size bounds

## 4. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 4.1 Add Purpose, Applicability, Public signatures, Terminology, Configuration, and Property
  reference sections to `openspec/specs/mcp-analytics/spec.md` (the delta's requirements point to the
  Property reference for types and limits), and keep the snapshot sections (Conformance, Verifying an
  installation) in design.md
- [x] 4.2 Add the capability to the root `README.md` Capabilities table (`product` scope) and to
  `openspec/project.md`

## 5. Validation

- [x] 5.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 5.2 Archive to create `openspec/specs/mcp-analytics/spec.md`

## 6. Downstream follow-ups (separate changes, not this one)

- [ ] 6.1 posthog-sdk-test-harness: an MCP driver route (the adapter hosts an instrumented MCP server
  and acts as its client) and step bindings for `mcp-analytics.feature`; move the per-event checker
  used to probe the SDKs into the harness. Run each scenario across these axes, where the SDK version
  supports the combination:
  - capture path: automatic instrumentation, and a custom dispatcher on the manual API;
  - every supported MCP SDK major version, with its high- and low-level servers;
  - transport: stdio, and HTTP with and without a transport session;
  - protocol revision: 2025-11-25 and 2026-07-28, varied separately from the SDK version
- [ ] 6.2 posthog-js and posthog-python: build `instrument()` on the manual API's list, call, and result
  steps, so the code around a tool call is written once, not once for each path, then resolve the remaining divergences in design.md's
  Conformance section
- [ ] 6.3 PostHog/posthog: join discovery rates (`intent_clustering.py`) on the server's catalogue
  instead of `$session_id`; base the dashboard's client and session tiles on `$mcp_tool_call` instead of
  `$mcp_initialize`; parse `$mcp_duration_ms` as a float in the session detail (`logic.py`); read
  `$mcp_input_required` and `$mcp_unknown_tool`
- [ ] 6.4 posthog-go (PostHog/posthog-go#337, #338): conversation anchoring; `$lib` as `posthog-go-mcp`,
  which the core client currently overwrites, and usage reporting for it; error types from
  `CallToolResult.GetError()`; bounded stateless session state on go-sdk v1.8.0; `User-Agent` and
  `X-Anthropic-Client` properties; manual-API prepare steps; go-sdk v1.8.0 for 2026-07-28
- [ ] 6.5 posthog-ruby: adopt this spec in the in-progress MCP port
- [ ] 6.6 posthog.com: document the manual API's steps for servers without an MCP SDK, and publish the
  installation checks in design.md for customers
