## 1. Canonical acceptance contract

- [ ] 1.1 Add manual and uncaught handled-state scenarios to `acceptance/public/capture-exception.feature`, including propagation across cause chains
- [ ] 1.2 Add canonical level normalization and unknown-level omission scenarios to `acceptance/public/capture-exception.feature`
- [ ] 1.3 Add manual, logger-derived, non-fatal uncaught, and terminating-failure signal-pair scenarios to `acceptance/public/capture-exception.feature`
- [ ] 1.4 Add an unknown-handled-state scenario that verifies omission instead of a `false` fallback

## 2. JavaScript SDK family

- [ ] 2.1 posthog-js browser: mark console-derived captures handled while keeping uncaught errors and unhandled rejections unhandled
- [ ] 2.2 posthog-node: set `fatal` only when the uncaught-exception path will terminate the process and retain `error` for non-fatal unhandled boundaries
- [ ] 2.3 posthog-react-native: normalize native console levels such as `warn` to the canonical exception-level vocabulary
- [ ] 2.4 Add final emitted-payload tests for manual, console, unhandled, and fatal JavaScript-family capture paths

## 3. Python and Go SDKs

- [ ] 3.1 posthog-python: emit `error` plus handled state for the public manual capture path
- [ ] 3.2 posthog-python: pass explicit boundary metadata through context, `sys.excepthook`, thread, Django, and Celery integrations
- [ ] 3.3 posthog-python: emit `fatal` only for a terminating process boundary and add emitted-payload tests for each integration class
- [ ] 3.4 posthog-go: add typed exception level and mechanism fields without forcing values on low-level manually built payloads
- [ ] 3.5 posthog-go: set `error` and handled state in `NewDefaultException`, and derive normalized level plus `handled: true` in the slog adapter
- [ ] 3.6 Add Go serialization and external-consumer tests for explicit values and unknown-signal omission

## 4. Ruby, PHP, and Elixir SDKs

- [ ] 4.1 posthog-ruby: emit `error` for manual capture and distinguish Rails-handled reports from unhandled middleware and job failures
- [ ] 4.2 posthog-php: emit `error` for manual capture, normalize PHP error severities, and emit `fatal` for uncaught or shutdown failures that terminate execution
- [ ] 4.3 posthog-elixir: normalize Logger levels into `$exception_level` while preserving crash-derived handled state
- [ ] 4.4 Add final emitted-payload tests in Ruby, PHP, and Elixir for each changed boundary

## 5. Conformance checks for aligned SDKs

- [ ] 5.1 posthog-android and posthog-server: verify manual, uncaught, JVM crash, and NDK crash paths emit the required signal pairs
- [ ] 5.2 posthog-ios: verify manual Error/NSException capture and crash-report capture emit the required signal pairs
- [ ] 5.3 posthog-flutter: verify manual capture and each autocapture integration emit explicit handled state with `error`
- [ ] 5.4 posthog-rs: verify manual capture, explicit level override, and panic capture emit canonical levels and handled state
- [ ] 5.5 Change only aligned SDK paths that fail conformance; do not add fallback metadata where the producer lacks confidence

## 6. Validation and archive

- [ ] 6.1 Run `openspec validate --strict` and fix all findings
- [ ] 6.2 Archive the change so the delta syncs into `openspec/specs/capture-exception/spec.md`
- [ ] 6.3 Re-run `openspec validate --specs --strict` after archive
