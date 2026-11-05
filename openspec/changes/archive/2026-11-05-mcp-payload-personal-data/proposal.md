## Why

The personal data pass (emails, IP addresses, card numbers, US social security numbers, phone numbers) runs only on `$mcp_intent` and free-text properties today. Tool arguments and results get the credential passes only. A customer lookup tool therefore sends the customer's email in `$mcp_parameters` and `$mcp_response`. OpenAI's plugin directory review asked what directory submissions capture by default. We told them the SDKs apply the intent-level personal data redaction to arguments and results too. This change specifies that.

## What Changes

- **Payload privacy.** The personal data pass also runs, by default, on:
  - every string value at any depth of `$mcp_parameters` and `$mcp_response`, text blocks and their JSON text copies included
  - `$mcp_error_message`
  - each exception's `value` in the `$exception` sibling
- **What is kept.** Object keys, JSON numbers and booleans, so a payload keeps its shape. A key names a field, and redacting keys would merge an object's entries.
- **Cost.** The pass is one of the remaining passes of the existing cut, so it costs in proportion to the property limits, and a match that crosses a string's limit is redacted whole.
- **Opt-out.** A new option, payload personal data, default on. Off turns the pass off for payloads, error text and exception values only. Intent and free-text properties keep it, and the credential passes still apply everywhere. The before-send hook still drops or edits whole payloads, but it can't restore a redacted value, so servers whose tools return personal data on purpose need the option.
- **Three scenarios** in the spec and the acceptance feature: default redaction in arguments and results, in error text and exceptions, and the opt-out.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Payload privacy** requirement, and the Configuration table (a new row).

## Impact

- Every SDK runs its existing intent personal data pass over payload strings. Each SDK needs the new option and the acceptance step for it.
- Event schema stability: no name, type or emission changes. Captured string values change, which the stability rule allows.
- Data loss risk: tools whose results are personal data on purpose (CRM, support, directory tools) lose those values by default. Data shaped like a phone number, such as an order number, can be redacted. The opt-out is the escape hatch, and the privacy docs should say so.
