# sdk-specs

**Platform-agnostic specifications for PostHog SDK capabilities** — the canonical contract every
SDK must satisfy so behavior stays on par across platforms (Android, iOS, React Native,
JavaScript/Web, Flutter, …).

This repo holds **specs and proposals only — no SDK code.** Implementations live in their own
repos (`posthog-android`, `posthog-ios`, `posthog-js`, `posthog-flutter`, …). Each spec here is
the canonical behavior derived from the shipped implementations plus the relevant backend
service, stating the **winner** wherever SDKs currently diverge.

## Acceptance specs

The `acceptance/` directory contains Gherkin feature files for cross-SDK acceptance tests.
`acceptance/public/` covers public SDK API behavior, while `acceptance/private/` covers
shared internal SDK behavior such as batching, storage, feature flags, sessions, and replay.
Tags on each feature indicate whether scenarios apply to client SDKs, server SDKs, or both.

## Capabilities

| Capability | Spec | Scope | Status |
|------------|------|-------|--------|
| Logs | [`openspec/specs/logs/spec.md`](openspec/specs/logs/spec.md) | product | Canonical |
| Tracing Headers | [`openspec/specs/tracing-headers/spec.md`](openspec/specs/tracing-headers/spec.md) | cross-SDK correlation | Canonical |
| Alias | [`openspec/specs/alias/spec.md`](openspec/specs/alias/spec.md) | public API | Canonical |
| Capture | [`openspec/specs/capture/spec.md`](openspec/specs/capture/spec.md) | public API | Canonical |
| Capture Exception | [`openspec/specs/capture-exception/spec.md`](openspec/specs/capture-exception/spec.md) | public API | Canonical |
| Create Person Profile | [`openspec/specs/create-person-profile/spec.md`](openspec/specs/create-person-profile/spec.md) | public API | Canonical |
| Debug | [`openspec/specs/debug/spec.md`](openspec/specs/debug/spec.md) | public API | Canonical |
| Flush | [`openspec/specs/flush/spec.md`](openspec/specs/flush/spec.md) | public API | Canonical |
| Get Anonymous ID | [`openspec/specs/get-anonymous-id/spec.md`](openspec/specs/get-anonymous-id/spec.md) | public API | Canonical |
| Get Distinct ID | [`openspec/specs/get-distinct-id/spec.md`](openspec/specs/get-distinct-id/spec.md) | public API | Canonical |
| Get Feature Flag | [`openspec/specs/get-feature-flag/spec.md`](openspec/specs/get-feature-flag/spec.md) | public API | Canonical |
| Get Feature Flag Payload | [`openspec/specs/get-feature-flag-payload/spec.md`](openspec/specs/get-feature-flag-payload/spec.md) | public API | Canonical |
| Get Feature Flag Result | [`openspec/specs/get-feature-flag-result/spec.md`](openspec/specs/get-feature-flag-result/spec.md) | public API | Canonical |
| Get Feature Flags | [`openspec/specs/get-feature-flags/spec.md`](openspec/specs/get-feature-flags/spec.md) | public API | Canonical |
| Get Feature Flags And Payloads | [`openspec/specs/get-feature-flags-and-payloads/spec.md`](openspec/specs/get-feature-flags-and-payloads/spec.md) | public API | Canonical |
| Get Session ID | [`openspec/specs/get-session-id/spec.md`](openspec/specs/get-session-id/spec.md) | public API | Canonical |
| Group | [`openspec/specs/group/spec.md`](openspec/specs/group/spec.md) | public API | Canonical |
| Group Identify | [`openspec/specs/group-identify/spec.md`](openspec/specs/group-identify/spec.md) | public API | Canonical |
| Identify | [`openspec/specs/identify/spec.md`](openspec/specs/identify/spec.md) | public API | Canonical |
| Is Feature Enabled | [`openspec/specs/is-feature-enabled/spec.md`](openspec/specs/is-feature-enabled/spec.md) | public API | Canonical |
| Is Opt Out | [`openspec/specs/is-opt-out/spec.md`](openspec/specs/is-opt-out/spec.md) | public API | Canonical |
| Is Session Replay Active | [`openspec/specs/is-session-replay-active/spec.md`](openspec/specs/is-session-replay-active/spec.md) | public API | Canonical |
| On Feature Flags | [`openspec/specs/on-feature-flags/spec.md`](openspec/specs/on-feature-flags/spec.md) | public API | Canonical |
| Opt In | [`openspec/specs/opt-in/spec.md`](openspec/specs/opt-in/spec.md) | public API | Canonical |
| Register | [`openspec/specs/register/spec.md`](openspec/specs/register/spec.md) | public API | Canonical |
| Reload Feature Flags | [`openspec/specs/reload-feature-flags/spec.md`](openspec/specs/reload-feature-flags/spec.md) | public API | Canonical |
| Reset | [`openspec/specs/reset/spec.md`](openspec/specs/reset/spec.md) | public API | Canonical |
| Reset Group Properties For Flags | [`openspec/specs/reset-group-properties-for-flags/spec.md`](openspec/specs/reset-group-properties-for-flags/spec.md) | public API | Canonical |
| Reset Person Properties For Flags | [`openspec/specs/reset-person-properties-for-flags/spec.md`](openspec/specs/reset-person-properties-for-flags/spec.md) | public API | Canonical |
| Screen | [`openspec/specs/screen/spec.md`](openspec/specs/screen/spec.md) | public API | Canonical |
| Set Group Properties For Flags | [`openspec/specs/set-group-properties-for-flags/spec.md`](openspec/specs/set-group-properties-for-flags/spec.md) | public API | Canonical |
| Set Person Properties | [`openspec/specs/set-person-properties/spec.md`](openspec/specs/set-person-properties/spec.md) | public API | Canonical |
| Set Person Properties For Flags | [`openspec/specs/set-person-properties-for-flags/spec.md`](openspec/specs/set-person-properties-for-flags/spec.md) | public API | Canonical |
| Setup | [`openspec/specs/setup/spec.md`](openspec/specs/setup/spec.md) | public API | Canonical |
| Shutdown | [`openspec/specs/shutdown/spec.md`](openspec/specs/shutdown/spec.md) | public API | Canonical |
| Start Session Recording | [`openspec/specs/start-session-recording/spec.md`](openspec/specs/start-session-recording/spec.md) | public API | Canonical |
| Stop Session Recording | [`openspec/specs/stop-session-recording/spec.md`](openspec/specs/stop-session-recording/spec.md) | public API | Canonical |
| Unregister | [`openspec/specs/unregister/spec.md`](openspec/specs/unregister/spec.md) | public API | Canonical |
| Application Lifecycle | [`openspec/specs/application-lifecycle/spec.md`](openspec/specs/application-lifecycle/spec.md) | internal behavior | Canonical |
| Autocapture | [`openspec/specs/autocapture/spec.md`](openspec/specs/autocapture/spec.md) | internal behavior | Canonical |
| Before Send Hook | [`openspec/specs/before-send-hook/spec.md`](openspec/specs/before-send-hook/spec.md) | internal behavior | Canonical |
| Consent Gating | [`openspec/specs/consent-gating/spec.md`](openspec/specs/consent-gating/spec.md) | internal behavior | Canonical |
| Device ID Generator | [`openspec/specs/device-id-generator/spec.md`](openspec/specs/device-id-generator/spec.md) | internal behavior | Canonical |
| Event Batcher | [`openspec/specs/event-batcher/spec.md`](openspec/specs/event-batcher/spec.md) | internal behavior | Canonical |
| Feature Flag Cache | [`openspec/specs/feature-flag-cache/spec.md`](openspec/specs/feature-flag-cache/spec.md) | internal behavior | Canonical |
| Feature Flag Called Tracker | [`openspec/specs/feature-flag-called-tracker/spec.md`](openspec/specs/feature-flag-called-tracker/spec.md) | internal behavior | Canonical |
| Flag Definition Loader | [`openspec/specs/flag-definition-loader/spec.md`](openspec/specs/flag-definition-loader/spec.md) | internal behavior | Canonical |
| HTTP Client | [`openspec/specs/http-client/spec.md`](openspec/specs/http-client/spec.md) | internal behavior | Canonical |
| Local Feature Flag Evaluator | [`openspec/specs/local-feature-flag-evaluator/spec.md`](openspec/specs/local-feature-flag-evaluator/spec.md) | internal behavior | Canonical |
| Persistent Storage | [`openspec/specs/persistent-storage/spec.md`](openspec/specs/persistent-storage/spec.md) | internal behavior | Canonical |
| Remote Config | [`openspec/specs/remote-config/spec.md`](openspec/specs/remote-config/spec.md) | internal behavior | Canonical |
| Retry Queue | [`openspec/specs/retry-queue/spec.md`](openspec/specs/retry-queue/spec.md) | internal behavior | Canonical |
| Session Manager | [`openspec/specs/session-manager/spec.md`](openspec/specs/session-manager/spec.md) | internal behavior | Canonical |
| Session Replay Ingestion Controls | [`openspec/specs/session-replay-ingestion-controls/spec.md`](openspec/specs/session-replay-ingestion-controls/spec.md) | internal behavior | Canonical |
| Session Replay Privacy | [`openspec/specs/session-replay-privacy/spec.md`](openspec/specs/session-replay-privacy/spec.md) | internal behavior | Canonical |
| Surveys | [`openspec/specs/surveys/spec.md`](openspec/specs/surveys/spec.md) | internal behavior | Canonical |

Each capability is one folder under `openspec/specs/<capability>/`. A new capability is a new
sibling folder — never folded into an existing spec.

## How this repo works (OpenSpec)

This repo uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) for spec-driven development.
Install the CLI to propose and validate changes:

```bash
npm install -g @fission-ai/openspec   # provides the `openspec` command + /opsx slash commands
```

The source of truth is `openspec/specs/<capability>/spec.md`. You never hand-edit it — you
propose a **change**, implement it, and archiving syncs the change into the spec.

```
openspec/
├── project.md                 project context + conventions
├── specs/<capability>/spec.md current truth (one folder per capability)
└── changes/                   in-flight proposals; archive/ holds finished ones
```

Workflow (OpenSpec CLI + `/opsx` slash commands):

1. **Propose** — `/opsx:propose add-<capability>` (or `openspec new change "<name>"`).
   Creates `changes/<name>/` with `proposal.md`, `design.md`, `tasks.md`, and a **delta** spec
   under `changes/<name>/specs/<capability>/spec.md`.
2. **Apply** — `/opsx:apply` to work through `tasks.md`.
3. **Archive** — `/opsx:archive` syncs the delta into `specs/<capability>/spec.md` and moves the
   change to `changes/archive/YYYY-MM-DD-<name>/`.

Two kinds of change:
- **New capability** → `add-<capability>` (e.g. `add-feature-flags`) creates a new spec folder.
- **Porting a capability to a new SDK** → `add-<capability>-<platform>` (e.g. `add-logs-android`),
  a delta measured against the existing contract.

## Spec format

```markdown
### Requirement: Public capture API
The SDK SHALL expose ...

#### Scenario: missing level defaults to info
- **WHEN** the app calls `captureLog({ body: "hello" })` with no level
- **THEN** the record has severityNumber 9 (`INFO`)
```

Every requirement needs at least one scenario. Validate with:

```bash
openspec validate --specs --strict
```

## Status

> Conformance matrix (per-SDK parity against each spec) — TODO. Track which SDKs satisfy each
> requirement and where they currently diverge.
