## Overview

The option replaces the failure's text with the fallback SDKs already send when a failure has no
text. It is a switch on where the message comes from, not a change to what counts as a failure.

## Key Decisions

- Default on. The text is the most useful part of a failure, and most hosts want it.
- A separate option, not part of response capture. A thrown error is not a response, and the
  `isError` content is already governed twice (in `$mcp_response` and `$mcp_error_message`). One
  option for "error text" covers both failure shapes the same way.
- The replacement is `Tool <name> returned an error`, the string the JavaScript, Python, and Go
  SDKs already use for a failure without text, so error tracking sees one message per tool.
- `$mcp_error_type` and the exception's type stay. They are type names or labels from the shared
  vocabulary, not data from the call, and they are what groups failures.
- The SDK does not read the message at all with the option off, so an error whose message
  formatting fails or panics cannot fail the capture.

## Alternatives Considered

- **Redact personal data from error messages like free text.** Rejected because argument values are
  not limited to personal-data shapes (resource names, IDs, variable values), and free-text
  redaction would still let them through.
- **Drop `$mcp_error_message` with the option off.** Rejected because the property is listed for
  failed calls, and dashboards and error tracking expect a message.

## Open Questions

None.
