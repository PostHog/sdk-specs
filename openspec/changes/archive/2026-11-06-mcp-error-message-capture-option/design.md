## Overview

The option replaces the failure's text with the fallback SDKs already send when a failure has no
text. It is a switch on where the message comes from, not a change to what counts as a failure.

## Key Decisions

- Default on. The text is the most useful part of a failure, and most hosts want it.
- A separate option, not part of response capture. A thrown error is not a response, and the
  `isError` content is already governed twice (in `$mcp_response` and `$mcp_error_message`). One
  option for "error text" covers both failure shapes the same way.
- The option does not touch `$mcp_response`. An `isError` result is a response, and some
  frameworks put a handler's error or their own validation text in it, so a host that wants no
  failure text turns response capture off too.
- The replacement is `Tool <name> returned an error`, the string the JavaScript, Python, and Go
  SDKs already use for a failure without text, so error tracking sees one message per tool.
- `$mcp_error_type` and the exception's type stay. They are type names or labels from the shared
  vocabulary, not data from the call, and they are what groups failures.
- The SDK does not read the message at all with the option off, so an error whose message
  formatting fails or panics cannot fail the capture.

## Alternatives Considered

- **Rely on the payload personal data pass.** It already runs on `$mcp_error_message` by default,
  but argument values are not limited to personal data shapes (resource names, IDs, variable
  values), and that pass lets them through.
- **Drop `$mcp_error_message` with the option off.** Rejected because the property is listed for
  failed calls, and dashboards and error tracking expect a message.

## Open Questions

None.
