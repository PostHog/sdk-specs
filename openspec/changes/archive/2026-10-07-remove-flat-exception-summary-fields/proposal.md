## Why

The capture-exception acceptance scenario currently requires SDKs to emit legacy top-level `$exception_type` and `$exception_message` properties. That no longer matches the canonical event shape used by the standard posthog-js capture path, where the exception type and message live on `$exception_list[0].type` and `$exception_list[0].value`.

Keeping the flat fields as a requirement causes SDK compliance work to add deprecated duplicate data instead of aligning SDKs on the structured `$exception_list` envelope.

## What Changes

- Update the public capture-exception scenario to assert the primary exception's type and message through `$exception_list` rather than top-level flat fields.
- Clarify that `$exception_list` is the source of truth for standard capture paths, while legacy flat fields may remain for compatibility.
- Mark `$exception_type` and `$exception_message` as legacy, non-authoritative metadata in the exception-event-metadata ownership table.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture-exception`: make `$exception_list[0].type` / `$exception_list[0].value` canonical for the primary exception summary.
- `exception-event-metadata`: document `$exception_type` / `$exception_message` as legacy compatibility fields, not producer-owned canonical metadata.

## Impact

SDKs that only emit `$exception_list` no longer fail capture-exception conformance solely for omitting the deprecated flat fields. SDKs that already emit the flat fields do not need to remove them immediately, but conformance is measured against `$exception_list` as the canonical source of truth.
