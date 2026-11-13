## Why

The canonical `$exception_source` table fixes the first-party value for each capture boundary, so two SDKs cannot name the same boundary differently. The table lists no .NET value at all, and posthog-dotnet now ships three:

- [posthog-dotnet#356](https://github.com/PostHog/posthog-dotnet/pull/356) adds opt-in runtime capture (`PostHogOptions.CaptureUnhandledExceptions`, default false) and emits `dotnet.appdomain_unhandled_exception` for `AppDomain.UnhandledException` and `dotnet.task_scheduler_unobserved_task_exception` for `TaskScheduler.UnobservedTaskException`.
- The same PR has the ASP.NET Core request-context middleware emit `aspnetcore.request_context_middleware`, both for a failure escaping the request boundary and for one a downstream error handler consumed.

The convention clause already permits an unlisted integration to coin a `<technology>.<stable_hook>` value, so none of these violates the contract. The registry is nonetheless out of date, and the next SDK that captures at a runtime unhandled-exception hook has no .NET precedent to copy.

## What Changes

- Record `aspnetcore.request_context_middleware`, `dotnet.appdomain_unhandled_exception`, and `dotnet.task_scheduler_unobserved_task_exception` as canonical first-party `$exception_source` values.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: extend the canonical first-party capture-source table with the ASP.NET Core request-context middleware and the two .NET runtime hooks.

## Impact

Only `openspec/specs/exception-event-metadata/spec.md` changes. No public SDK API, event shape, mechanism vocabulary, level vocabulary, or acceptance-harness change. The .NET implementation already ships these values; no other SDK is required to add runtime unhandled-exception capture, and an SDK without those boundaries stays conformant.
