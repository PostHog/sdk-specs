## Why

Tool errors often repeat their arguments: `workspace 'prod' not found in org 'acme'`, or
`strconv.Atoi: parsing "<value>"`. "Payload privacy" redacts only credentials from `$mcp_error_message`, not
personal data, workspace names, identifiers, or configuration values, so those reach PostHog in failures. A host
that turns parameter and response capture off to keep arguments out still sends them this way, and
has no option to stop it. The Terraform MCP server hit this: its Terraform variable values reached
PostHog through error messages with both payload options off.

## What Changes

- Add an error message capture option, on by default, to the Configuration table.
- Modify the **Failure capture** requirement: with the option off, `$mcp_error_message` and the
  `$exception` value are `Tool <name> returned an error`, and nothing else about the failure changes.
- Add a scenario: with the option off, a thrown error is still a failed call with its type, and its
  text appears in no event.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Failure capture** requirement and the Configuration table.

## Impact

Nothing changes for a host that keeps the default. A host that turns the option off still sees
failure rates and error types, but not why each call failed. SDKs that do not offer the option yet
fall short of "every option of a feature the SDK implements is configurable" until they add it.
