## Why

The personal data pass (emails, IP addresses, card numbers, US social security numbers, phone numbers) runs only on `$mcp_intent` and free-text properties today. Tool arguments and results get the credential passes only. A customer lookup tool therefore sends the customer's email in `$mcp_parameters` and `$mcp_response`. OpenAI's plugin directory review asked what directory submissions capture by default. We told them the SDKs apply the intent-level personal data redaction to arguments and results too. This change specifies that.

## What Changes

- **Payload privacy.** A narrower payload personal data pass runs, by default, on:
  - every string value and object key at any depth of `$mcp_parameters` and `$mcp_response`, JSON text copies included
  - numbers that are Luhn-valid card numbers, written as the string `"[redacted]"` so a JSON text copy stays valid JSON
  - `$mcp_error_message`, and `$mcp_resource_name` on a resource read (the URI)
  - each `$exception` value and the stack-frame source lines it sends, each cut to 2,048 characters first
- **The narrower pass.** Email addresses, Luhn-valid card numbers, US SSNs and IPv6 as the intent pass does. IPv4 only when it isn't loopback, private, link-local or `0.0.0.0`, and isn't glued to a letter, digit, `.`, `:` or `@` (so `node:22.11.0.3` and `pkg@1.2.3.4` survive). Phone numbers only with a `+` country code or a parenthesized area code, so `415-555-0142` order numbers survive. Intent and free-text properties keep the full pass.
- **Kept.** Other numbers and booleans. Colliding keys follow the existing rule, which keeps the entry whose key sorts first.
- **Order and cost.** The pass runs before the URL pass, which percent-encodes `@`, and inside the existing margin cut, so its cost follows the property limits.
- **`$mcp_input_keys`** treats a name the pass would change as not recorded.
- **Opt-out.** A new option, payload personal data, default on. Off turns the pass off for payloads, error text, resource URIs and exception values only. Intent and free-text properties keep it, and the credential passes still apply everywhere. The before-send hook can drop a payload but can't restore a redacted value, so servers whose tools return personal data on purpose need the option.
- **Smaller fixes.** `$mcp_feedback_<name>` JSON text is marked sanitized, and the stale reason in "Optional events" ("only the free-text pass sanitizes for personal data") is replaced.
- **Four scenarios**, in the spec and the acceptance feature: default redaction in arguments and results, a personal key and a card number with valid JSON, error text and exceptions, and the opt-out.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Payload privacy** requirement, and the Configuration table (a new row).

## Impact

- Every SDK runs its existing intent personal data pass over payload strings and keys. Each SDK needs the new option.
- Event schema stability: no name, type or emission changes. Only captured values change, which the stability rule allows.
- Measured on every SDK's current personal data patterns, the full pass redacts ordinary identifiers: all `ddd-ddd-dddd` references, all four-part versions, all private and loopback IPs, and about 10% of 13 to 19 digit ids (Luhn). The narrower payload pass keeps `ddd-ddd-dddd` references, private and loopback IPs, and versions glued to a letter, `:` or `@`. It still redacts:

  | Value | Redacted |
  | --- | --- |
  | `ddd-dd-dddd` references (read as US SSNs) | 100% |
  | a four-part version after a space (`version 1.2.3.4`) | 100% |
  | 13 to 19 digit numeric ids and epoch-ms strings (Luhn) | about 10% |

  ISO timestamps, UUIDs and hex hashes are not affected. Servers that depend on these values turn the option off. The privacy docs list these classes.
- A percent-encoded or JSON-escaped address isn't recognized. The spec says so.
