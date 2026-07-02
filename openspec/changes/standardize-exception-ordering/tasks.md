# Tasks: Standardize Exception Ordering

## 1. Acceptance tests

- [ ] 1.1 Add the frame-ordering scenarios ("Frames are ordered entry point first, crash site
      last", "Crash-first runtime stacks are reversed before sending") to
      `acceptance/public/capture-exception.feature`, tagged `@both`
- [ ] 1.2 Add the exception-list scenarios ("Chained exceptions are listed caught-first, root
      cause last", "Platforms without exception chaining send a single-element list") to
      `acceptance/public/capture-exception.feature`, tagged `@both`
- [ ] 1.3 Add the source-context scenarios ("Context arrays are in ascending file order",
      "Frames without source context are valid") to
      `acceptance/public/capture-exception.feature`, tagged `@both`

## 2. Validation & sync

- [ ] 2.1 Run `openspec validate --strict` and fix any findings
- [ ] 2.2 Archive the change (`openspec archive`) so the delta syncs into
      `openspec/specs/capture-exception/spec.md`

## 3. Downstream coordination (tracked in other repos)

- [ ] 3.1 posthog (cymbal): semver-gated normalization of legacy payloads per
      (`$lib`, `$lib_version`) plus fingerprint aliasing paired with each SDK's flip release
- [ ] 3.2 Frame reversal in a minor release: posthog-android (`ThrowableCoercer.kt`),
      posthog-flutter (`dart_exception_processor.dart`), posthog-php
      (`ExceptionPayloadBuilder.php`), posthog-go (`error_tracking_stack_trace.go`),
      posthog-rs (`error_tracking.rs`, invert the crash-first test)
- [ ] 3.3 posthog-python: flip `$exception_list` to outermost-first
      (`exception_utils.py:719`) in a minor release
