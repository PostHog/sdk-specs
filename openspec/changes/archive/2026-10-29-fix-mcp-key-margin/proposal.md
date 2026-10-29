## Why

**Payload privacy** cuts a long string to its limit plus a 1,024-character margin, redacts it, then cuts it to the redacted length minus 1,024. Object keys use the same rule with their 256 limit, so any redaction inside the margin is taken off the kept text too. A link whose `token` query field is longer than the key limit comes out as `""` when used as an object key (a link check keyed by link), and every such key in one object collides on `""`. SDKs that also redact `X-Amz-Security-Token` (posthog-python, posthog-rs) hit this with S3 presigned links made with temporary credentials, whose session token is about 1,000 characters.

## What Changes

- **Payload privacy**: when the margin cut removed text, the SDK also runs the passes on the string cut to its limit and keeps only the start the two results share, cut to the limit. A redaction inside the margin no longer shortens what is kept, and a match split by either cut is still dropped. The passes themselves don't change.
- New scenario: a long signed link used as an object key keeps its start.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: **Payload privacy** requirement.

## Impact

- **posthog-rs**: `bounded_text` cuts by the redacted length minus the margin and needs the second pass and shared-start cut.
- Other SDKs that scan with the margin need the same change.
