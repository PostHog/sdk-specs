## Why

PostHog SDKs do not share one explicit contract for the metadata surrounding `$exception` events. Equivalent capture boundaries may disagree on severity, handled state, mechanism category, integration source, synthetic provenance, nested-exception relationships, and native symbolication context. Similar property names such as `$exception_source`, `$exception_sources`, and `mechanism.source` also carry distinct meanings that are not documented together.

A shared producer envelope and ownership model lets SDKs converge without requiring consumers to infer behavior from a specific implementation.

## What Changes

- Add an internal `exception-event-metadata` capability for client and server SDKs.
- Define the canonical `$exception` envelope and common `$exception_list[].mechanism` fields.
- Separate semantic capture category (`mechanism.type`), concrete integration (`$exception_source`), nested relationship (`mechanism.source`), and processor-derived source files (`$exception_sources`).
- Define handled, synthetic, and exception-level semantics at the capture boundary.
- Define metadata precedence and omission for context-free builders.
- Define optional native `$debug_images` and frame-to-image linkage.
- Record explicit custom fingerprint and release-context ownership without defining grouping or release policy.
- Distinguish SDK-produced fields from Cymbal-derived fields.
- Add private client/server acceptance scenarios for manual, framework, logger, terminating, nested, and native paths.

## Capabilities

### New Capabilities

- `exception-event-metadata`: standardizes producer and processor metadata ownership for SDK-generated `$exception` events.

### Modified Capabilities

None. The public `capture-exception` API, stack ordering, and `$exception_steps` remain in their existing capabilities.

## Impact

Audit basis: maintained first-party SDK repositories and Cymbal's current raw and processed exception models.

- **All SDKs:** use one capture-boundary model for level, source, category, handled state, and synthetic provenance; preserve supplied metadata and omit unknown values.
- **Framework integrations:** emit a semantic mechanism category plus a concrete namespaced `$exception_source` such as `django.middleware` or `fastapi.exception_handler`.
- **Cause and aggregate builders:** reserve `mechanism.source` for nested relationships such as `cause`, `context`, `unwrap`, or `member`.
- **Native-capable SDKs:** emit authoritative `$debug_images` linked to native frame addresses when available.
- **Cymbal:** remains authoritative for `$exception_sources`, `$exception_functions`, `$exception_types`, `$exception_values`, handled denormalization, grouping outputs, issue linkage, and resolved release metadata.
- **Spec artifacts:** add `openspec/specs/exception-event-metadata/spec.md` and `acceptance/private/exception-event-metadata.feature`; implementation changes remain in each SDK and Cymbal repository.
