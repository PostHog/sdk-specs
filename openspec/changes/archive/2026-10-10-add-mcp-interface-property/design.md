## Overview

`$mcp_interface` names how the tool call reached the instrumented code, not which SDK sent it. Two
values exist today: a tool call made over the MCP protocol against a server, and a tool call made by
an agent against a page's in-browser WebMCP tools.

## Key Decisions

- **One property, fixed values, required.** The value is a constant per instrumentation, so making it
  required costs an SDK one line and gives the server owner a breakdown that always has every event in
  it. An optional property would leave a null bucket whose meaning depends on which SDK version sent
  the event.
- **`$lib` is not a substitute.** `$lib` already ends in `-mcp` for server instrumentation ("Library
  identity"), but it also names the runtime, so separating interfaces through it means enumerating
  every runtime and keeping that list current. WebMCP events also come from the browser SDK's own
  `$lib`, which has no MCP marker at all.
- **Reserve `"webmcp"` rather than specify it.** This spec covers server instrumentation
  (`Applicability: server`). Naming the browser value keeps a server from taking it, without this spec
  claiming to define browser WebMCP capture, which has its own event shape and configuration.
- **The `$exception` sibling carries it too.** A failed call's exception is routed to error tracking,
  where the same interface breakdown is useful, and `@posthog/mcp` already sets it there.

## Alternatives Considered

- **Leave it as a permitted extra property.** Rejected: the value would drift between SDKs, which is
  exactly what this repo exists to prevent.
- **Derive the interface from `$lib` at query time.** Rejected: it pushes a list of runtimes into
  every query and breaks whenever an SDK is added.

## Open Questions

None.
