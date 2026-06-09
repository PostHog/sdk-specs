# sdk-specs

**Platform-agnostic specifications for PostHog SDK capabilities** — the canonical contract every
SDK must satisfy so behavior stays on par across platforms (Android, iOS, React Native,
JavaScript/Web, Flutter, …).

This repo holds **specs and proposals only — no SDK code.** Implementations live in their own
repos (`posthog-android`, `posthog-ios`, `posthog-js`, `posthog-flutter`, …). Each spec here is
the canonical behavior derived from the shipped implementations plus the relevant backend
service, stating the **winner** wherever SDKs currently diverge.

## Capabilities

| Capability | Spec | Status |
|------------|------|--------|
| Logs       | [`openspec/specs/logs/spec.md`](openspec/specs/logs/spec.md) | Canonical |

<!-- Add a row per capability as specs land (feature flags, session replay, surveys, …). -->

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
