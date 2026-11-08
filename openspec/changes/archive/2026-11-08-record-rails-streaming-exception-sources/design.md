## Context

`$exception_source` separates the concrete integration that captured an event from `mechanism.type`, which names the semantic boundary category. The table of first-party values is the registry that keeps two SDKs from naming the same boundary differently. Rails streaming has two distinct boundaries — `ActionController::Live` and a streaming template body — and posthog-ruby captures them separately, so they need two values rather than one.

## Goals / Non-Goals

**Goals:** Register the two shipped Rails streaming sources and state the capture category they carry.

**Non-Goals:** Require streaming capture from any SDK, add configuration, change the mechanism vocabulary, or alter how `$exception_source` is derived.

## Decisions

- Two values, not one. The Live controller path and the streaming template path fail under different conditions and carry different metadata availability, so collapsing them would lose the distinction the Ruby integration already draws.
- Category stays `middleware` with `handled` false. The failure escaped application work at a request boundary; the only difference from ordinary middleware capture is that the response had already started. Coining a new category for "after headers" would fragment the vocabulary for no analytical gain.
- Descriptive scenario only. The acceptance harness has no Rails streaming binding, so the scenario is tagged `@both` and is not opted into the integration suite.

## Risks / Trade-offs

- A later SDK may capture streaming failures at a boundary that is neither of these. The convention clause still covers that case, and the table can grow again.
- Deferred streaming template errors may lack request metadata and identity. That is an implementation property of the Ruby integration, not a contract this change makes, so it is left unspecified.
