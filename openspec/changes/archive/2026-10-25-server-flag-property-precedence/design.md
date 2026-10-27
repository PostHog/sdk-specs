## Context

`capture`'s Behavior step 4 describes the server merge as "request-context properties, then
caller-supplied `properties`, then SDK-stamped properties", and lists `$lib`, `$lib_version` and
the SDK-level default properties as the SDK-stamped ones. The feature flag properties are a
fourth source that the step never mentions, even though every server SDK that supports
`send_feature_flags` or a flags snapshot produces them on the same path.

## Decisions

**Flag properties are SDK values, not caller values.** posthog-python and posthog-go both
arrived at this framing in the same week: the flag snapshot is something the SDK resolved on the
caller's behalf, so it is a default that fills gaps, not an override. Writing it as "fill only
the keys left unset" states the behavior without having to enumerate each SDK's layer names.

**The layers are named conditionally.** Not every server SDK has all three layers above the SDK
values: posthog-node has no context or default-property layer at this point in the merge, and
Ruby and PHP have no ambient context. The requirement says "where the SDK has them" so an SDK
without a layer is not made non-conforming by its absence.

**`$active_feature_flags` behaves like `$feature/<key>`.** Both SDKs treat the whole snapshot as
one layer, so a caller-supplied `$active_feature_flags` replaces the SDK's list rather than
merging with it.

**Scenarios stay descriptive.** They follow the `@server` scenarios already in this spec
(the release-identifier requirement), which assert on the enqueued event rather than binding to
the draft2 harness. They are not tagged `@sdk:server`, because no adapter-backed run has
verified them end to end.

## Open questions

Whether an SDK-level default property (`super_properties`, `DefaultEventProperties`,
`SuperProperties`, `global_properties`) should win over the caller's event properties. The spec
says it does today; posthog-python 8.0 and posthog-go v2 reverse it, while posthog-dotnet and
posthog-elixir still match the spec. That is a separate contract change and is deliberately left
out of this one.
