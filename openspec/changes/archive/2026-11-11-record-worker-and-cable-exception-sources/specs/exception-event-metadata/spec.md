## MODIFIED Requirements

### Requirement: Capture category and concrete capture source

`mechanism.type` identifies the semantic mechanism by which an exception entry entered the event. On the outermost exception it identifies the capture-boundary category. Public or manual capture SHALL use `generic` unless a more specific integration category is known. Common outermost categories include `logger`, `onconsole`, `onuncaughtexception`, `onunhandledrejection`, `middleware`, `task`, `panic`, `signal`, and `crash_reporter`. Every nested exception reached through another entry SHALL use `chained`; `mechanism.source` then preserves the specific relationship. The vocabulary for outermost capture categories is extensible, and builders MUST preserve unknown non-empty typed integration values.

Event-level `$exception_source` identifies the concrete SDK integration or runtime hook that captured the event. Examples include `django.middleware`, `fastapi.exception_handler`, `celery.task_failure`, `python.sys_excepthook`, `browser.window_onerror`, and `php.exception_handler`. First-party values SHALL be stable lowercase identifiers, SHALL qualify the technology with the relevant hook, and MUST NOT contain versions, routes, exception classes, source-file paths, or user-controlled values.

A producer SHALL set `$exception_source` only from capture-boundary knowledge. It MUST NOT infer it merely from installed dependencies or stack frames. Generic manual capture SHALL omit `$exception_source` unless a concrete integration owns the call. Technology-specific integration identity belongs in `$exception_source`, not in `mechanism.type`, when a common semantic category describes the boundary.

First-party integrations SHALL use the following canonical sources where applicable:

| Capture integration or hook | `$exception_source` |
| --- | --- |
| Browser global error handler | `browser.window_onerror` |
| Browser unhandled rejection | `browser.unhandledrejection` |
| Browser console | `browser.console` |
| Node uncaught exception | `node.process_uncaught_exception` |
| Node unhandled rejection | `node.process_unhandled_rejection` |
| Python process exception hook | `python.sys_excepthook` |
| Python thread exception hook | `python.threading_excepthook` |
| Django request middleware | `django.middleware` |
| FastAPI exception handler | `fastapi.exception_handler` |
| Celery task failure | `celery.task_failure` |
| Rails request middleware | `rails.middleware` |
| Rails error reporter | `rails.error_reporter` |
| Rails Active Job | `rails.active_job` |
| Rails Action Cable | `rails.action_cable` |
| Rails runner terminal exit hook | `rails.runner` |
| Sidekiq error handler | `sidekiq.error_handler` |
| Sidekiq death handler | `sidekiq.death_handler` |
| PHP exception handler | `php.exception_handler` |
| PHP error handler | `php.error_handler` |
| PHP shutdown handler | `php.shutdown_handler` |
| Go HTTP recovery middleware | `go.http_recover_middleware` |
| Go slog handler | `go.slog` |
| iOS native crash reporter | `ios.crash_reporter` |
| Android uncaught exception handler | `android.uncaught_exception_handler` |
| Unity log callback | `unity.log_callback` |
| Roblox ScriptContext error handler | `roblox.script_context` |

A maintained integration not listed here SHALL use the same lowercase `<technology>.<stable_hook>` convention. KMP and other forwarding facades SHALL preserve the source emitted by the underlying wire-producing SDK rather than replace it with the facade name.

#### Scenario: Framework boundary separates category from integration (@both)
- **GIVEN** Django middleware observes an exception escaping a request boundary
- **WHEN** the middleware captures the exception
- **THEN** the outermost exception should have `mechanism.type` equal to `middleware`
- **AND** `$exception_source` should equal `django.middleware`

#### Scenario: Generic manual capture omits a concrete source (@both)
- **WHEN** the public exception API captures a caught exception without integration context
- **THEN** the outermost exception should have `mechanism.type` equal to `generic`
- **AND** the event should omit `$exception_source`

#### Scenario: Worker terminal failure handler keeps the category separate from the hook (@server)
- **GIVEN** a background worker's terminal failure callback observes a job failure that escaped the job
- **WHEN** the integration captures the exception
- **THEN** the outermost exception should have `mechanism.type` equal to `task`
- **AND** the outermost exception should have `mechanism.handled` equal to `false`
- **AND** `$exception_source` should name the concrete worker hook

#### Scenario: Unknown integration type is preserved (@both)
- **GIVEN** a typed integration supplies an unknown non-empty mechanism type
- **WHEN** a low-level builder creates the exception event
- **THEN** the builder should preserve that type instead of replacing it with `generic`
