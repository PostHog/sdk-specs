## Overview

The server owner is the only one who knows which failures are expected. The SDK asks them once per
failed tool call, through a callback, and records the answer as data. It does not decide what is
expected, and it does not change what the client receives.

## Key Decisions

- **A flag, not a new outcome.** An expected failure keeps `$mcp_is_error: true`. Hiding the failure
  (the `beforeSend` workaround in the issue, which sets `$mcp_is_error` to `false`) loses the fact that
  the client received an error. A separate property keeps both facts, so anyone reading the data can
  count failures with or without expected ones.
- **The callback always gets the type and message, and the failure when the SDK holds it.** The type
  and message `$mcp_error_type` and `$mcp_error_message` would carry exist for every failed call in
  every SDK, so a classifier keyed on them works the same everywhere. The failure itself is richer: a
  thrown error's own type is the most reliable thing to classify on (`instanceof RateLimitError`). It
  is the tool's own error, past the same wrappers `$mcp_error_type` looks past, because Python's
  FastMCP re-raises every tool error as a `ToolError` and a classifier would never match the tool's
  type. On frameworks that turn a throw into an `isError` result before the SDK sees it, the result is
  all there is, and some manual APIs keep only a type name and message. The result is the one the tool
  produced, before the SDK appends a conversation handle, the same rule `$mcp_error_message` follows.
- **One object argument.** Platforms pass these as one value (an object, a struct, a dataclass) so it
  can gain fields later without breaking callbacks.
- **Only failures the tool produced.** A failed or cancelled task and an `input_required` sequence the
  framework ends are failures the SDK observes and types itself, with no thrown error or `isError`
  result to hand over. The classifier is not called for them, so their fixed types stand in every SDK.
- **Automatic instrumentation only.** A manual API caller already holds the failure and passes the
  type and the expected flag itself, so a callback adds nothing there. It would also run on different
  paths in different SDKs, because not every SDK's manual result step sends events.
- **Explicit types are data like any other.** A classifier can derive its label from the raw failure,
  so an explicit type is sanitized as free text, and an empty or blank one counts as no type. Without
  that rule, today's SDKs send a blank type in some cases and drop the property in others.
- **Explicit values win.** The classifier's type wins over the type the SDK assigns and the thrown type,
  the same precedence explicit types already have.
  The classifier's type never renames the `$exception` type, so error tracking still groups by real
  types.
- **`$exception` is unchanged.** Whether an expected failure should still emit `$exception` is open
  (see below). This change keeps today's behavior, which the host can already change with the
  exception autocapture option or the before-send hook.
- **`not_found` joins the vocabulary.** It was the third-largest expected bucket in the reported data
  and had no shared label. An ambiguous argument the agent must fix is `validation`.
- **Tool calls only.** Resource reads and listings keep today's rules. Nothing has asked for more.
- **`$mcp_error_expected` is sent only when known.** It is set when the classifier or the caller says
  whether the failure is expected, and absent otherwise. Absent reads as not expected.

## Alternatives Considered

- **Readers classify by message text.** Possible today, and what the reporting team does. Every reader
  has to repeat it for every server, and message text is sanitized and truncated before capture.
- **The host marks expected failures in the before-send hook.** Works without a spec change, but the
  hook sees only the sanitized message, never the thrown error or the result, and it runs once per
  payload, so the host classifies the `$exception` a second time.
- **Mark the failure inside the tool result (a `_meta` key) or on the thrown error.** The result is
  what the client receives, so analytics metadata would leak to it, and on frameworks that flatten a
  throw into a result the error's fields are lost.
- **Three-way fault attribution (agent, server, upstream).** More informative, but no reader has asked
  for it, and a boolean covers the reported need.

## Open Questions

- Should an expected failure skip the `$exception` event? Expected failures are not defects, and each
  one creates an error-tracking event the host pays for. Skipping it is a behavior change for every
  host that sets a classifier, so it is left out of this change.
