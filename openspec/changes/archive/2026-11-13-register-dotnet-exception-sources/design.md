## Context

`$exception_source` names the concrete integration that captured an event; `mechanism.type` names the semantic boundary category. The table of first-party values is the registry that keeps the two from drifting apart across SDKs. It carried no .NET entry, and posthog-dotnet now captures at three boundaries: the ASP.NET Core request-context middleware and the two process-wide CLR hooks.

## Goals / Non-Goals

**Goals:** Register the three shipped values.

**Non-Goals:** Requiring any SDK to add runtime unhandled-exception capture, adding configuration, extending the mechanism category vocabulary, or changing how `$exception_source` is derived.

## Decisions

- Two runtime values, not one. `AppDomain.UnhandledException` and `TaskScheduler.UnobservedTaskException` are distinct CLR hooks with different handled/level outcomes (the first is usually terminating, the second is not), so collapsing them would lose a distinction the wire already carries.
- The middleware value is `aspnetcore.*`, not `dotnet.*`. It names the framework integration, matching `django.middleware` and `rails.middleware`; the `dotnet.*` prefix is reserved for runtime hooks that exist without a web framework.
- One middleware value covers both the escaping failure and the one a downstream error handler consumed. The capture-boundary table already separates those two cases by `mechanism.handled`, so a second source value would duplicate that distinction.
- No new scenario. Level, category and handled state for these boundaries are already fixed by the capture-boundary metadata table; this change only extends the source registry.

## Risks / Trade-offs

- Another SDK may later capture at a CLR hook that is neither of these. The convention clause still covers that case and the table can grow again.

## Migration Plan

Sync and archive this change in the same PR. The .NET SDK already emits these values, so no SDK migration follows.

## Open Questions

None for this registry extension.
