## Scope of "build-invariant"

The rule keys off a property's value changing only with a rebuild of the app binary, not off a list
of property names. That covers the wrapper runtime version (`$flutter_version`,
`$react_native_version`) and the build toolchain (`$app_build_xcode`, `$app_build_sdk`), and it
keeps covering whatever the next SDK adds in the same shape.

A name list was the alternative. It was rejected because the three SDK changes this records all
introduced names that no spec had anticipated, so a list would have been written after the fact each
time — which is the drift the requirement exists to stop.

## Why `$lib_version` and `$app_version` are carved out

They are build-invariant by the same test, but they are not interchangeable with the properties
above. `$lib` / `$lib_version` are read during ingestion and in SDK debugging on arbitrary events,
and `$app_version` / `$app_build` back version-adoption insights and person properties across all
events. Moving either would be a far larger break than the one these SDK changes made, so the
requirement names them as exceptions rather than leaving the boundary to interpretation.

## No fallback on lifecycle-less runtimes

posthog-flutter dropped `$flutter_version` entirely on web rather than keeping it per-event there,
because posthog-js has no install/update event to carry it. The requirement follows that choice:
absent a lifecycle event, the property is not sent. The alternative — per-event on web, lifecycle
elsewhere — would make the same property mean different things per platform.

## Acceptance coverage

No Gherkin scenario is added. The executable scenarios bind to concrete property names, and the
property differs per SDK (`$flutter_version`, `$react_native_version`, `$app_build_xcode`), with no
harness step today for "the platform's build-invariant property". The spec scenarios state the rule
in prose over a worked example instead. Giving the harness a step that resolves the property name
per adapter would be a reasonable follow-up.
