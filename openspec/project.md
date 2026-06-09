# Project Context

> Project-level context OpenSpec injects into every proposal/apply/archive run.
> Keep it short and durable — conventions and constraints, not change history.

## Purpose

`sdk-specs` is the home for **platform-agnostic contracts** for PostHog SDK capabilities. Each
spec states the **canonical** behavior every SDK MUST converge on so all SDKs stay on par across
platforms (Android, iOS, React Native, JavaScript/Web, Flutter, …). Specs are derived from the
shipped implementations plus the relevant backend service; where SDKs diverge today, the spec
names the winner.

This repo holds specs and proposals only — **no SDK code lives here.** Implementations live in
their own repos (`posthog-android`, `posthog-ios`, `posthog-js`, `posthog-flutter`, …).

## Capabilities

- `logs` — structured log records emitted through the SDK, enriched with context, batched, and
  shipped to PostHog as OpenTelemetry Logs (OTLP/HTTP JSON) at `POST {host}/i/v1/logs`.

<!-- Add a new sibling under specs/<capability>/ for each genuinely distinct capability
     (e.g. feature flags, session replay, surveys). One capability per folder. -->

## Conventions

- **Source of truth:** `openspec/specs/<capability>/spec.md`. Never hand-edit it — change it
  through a proposal in `openspec/changes/` and let `openspec archive` sync the delta in.
- **One capability per spec folder.** A new capability is a new sibling, never folded into an
  existing spec.
- **Spec format:** `### Requirement:` (SHALL/MUST) → one or more `#### Scenario:` with
  **WHEN/THEN** (optional **GIVEN**). Every requirement needs at least one scenario.
- **Change names:** kebab-case, verb-prefixed. New capability → `add-<capability>`
  (e.g. `add-feature-flags`). SDK port → `add-<capability>-<platform>` (e.g. `add-logs-android`).
- **SDK ports are changes, not new specs:** `/opsx:propose add-<capability>-<platform>` → delta
  spec measured against `specs/<capability>/spec.md` → archive.
- Run `openspec validate --specs --strict` before committing spec changes.

## Constraints

- Specs are **descriptive of a canonical target**, not aspirational invention — every
  requirement traces to real behavior in at least one shipped SDK or the relevant backend
  service.
- Where SDKs legitimately must deviate (lifecycle model, storage primitives, platform APIs), the
  requirement notes the allowed variation explicitly rather than forcing false uniformity.

## Tooling

- OpenSpec CLI (v1.3.1) with `/opsx:propose | apply | archive` slash commands and the
  agent skills under `.claude/skills/`.
