## Why

**Payload privacy** cuts a long string to its limit plus a 1,024-character margin, redacts it, then cuts it to the redacted length minus 1,024. Object keys use the same rule with their 256 limit, so any redaction inside the margin is taken off the kept text too. An S3 presigned link made with temporary credentials carries an `X-Amz-Security-Token` of about 1,000 characters, so as an object key (a link check keyed by link) it comes out as `""`, and every such key in one object collides on `""`.

## What Changes

- **Payload privacy**: after the margin scan, keep only the text that came from the string's first limit characters (a redaction counts where its match started), then cut to the limit. A redaction inside the margin no longer shortens what is kept. Nothing that was redacted before is kept now.
- New scenario: a long signed link used as an object key keeps its start.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Payload privacy** requirement.

## Impact

- **posthog-rs**: `bounded_text` cuts by the redacted length minus the margin and needs the new cut.
- Other SDKs that scan with the margin need the same change.
