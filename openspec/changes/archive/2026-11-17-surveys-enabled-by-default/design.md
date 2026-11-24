## Context

`openspec/specs/surveys/spec.md:39` says the subsystem is installed "during SDK setup when
surveys are enabled by local config and/or remote config", and the scenarios all start from
"surveys enabled". Nothing states the default of the local switch, so a new SDK — or a new
target of an existing one — has no answer.

Sources read on 2026-11-17:

| SDK | Local switch | Default | Evidence |
|---|---|---|---|
| posthog-android (4.0 branch) | `PostHogConfig.surveys` | `true` | PostHog/posthog-android#984, merged 2026-11-16 as `36253029f` into `chore/v4-remove-deprecated` |
| posthog-android 3.x (`main`) | `PostHogConfig.surveys` | `false` | `posthog/src/main/java/com/posthog/PostHogConfig.kt` |
| posthog-kmp | `PostHogConfig.surveys` | `true` | PostHog/posthog-kmp#125, merged 2026-11-16 |
| posthog-ios | `PostHogConfig.surveys` | `true` | `PostHog/PostHogConfig.swift`, `_surveys = true` |
| posthog-flutter | `PostHogConfig.surveys` | `true` | `posthog_flutter/lib/src/posthog_config.dart`, "Defaults to true" |
| posthog-js browser | `disable_surveys` | `false` | browser config defaults |
| posthog-js core / react-native | `disableSurveys` | `false` | `packages/core/src/types.ts`, `@default false` |

## Goals / Non-Goals

**Goals:** One written answer for the default of the local surveys switch, matching what every
audited SDK ships.

**Non-Goals:**

- The name of the switch. SDKs use `surveys` and an inverted `disableSurveys`; both stay.
- Remote gating. Which surveys a project delivers is already remote config's job, and this
  change does not touch it.
- The browser's `disable_surveys_automatic_display` and the mobile delegate APIs.
- posthog-unity and posthog-godot, which were not audited.

## Decisions

**State the default on the local switch, not on the subsystem.** "Surveys are on by default"
would read as a promise that an app shows surveys, which is untrue for a project with none. The
requirement says the local switch defaults to enabled and leaves delivery to remote config.

**Record the no-renderer rule in the same requirement.** It is the reason defaulting on is safe
where the renderer is a separate module: posthog-android#984 relies on the integration skipping
matching when only the logging default delegate is installed (`bb699a9`), so a flag-linked
survey nobody can see does not emit `$feature_flag_called` or run property-filter regexes on
`capture()`. Splitting it into its own requirement would separate the default from its
safeguard.

## Open questions

- The no-renderer rule is verified on posthog-android only. posthog-ios, posthog-flutter and
  the browser render surveys themselves, so it is vacuous there, but posthog-kmp,
  posthog-react-native and any future wrapper that installs its own renderer should be checked
  against it. **Low confidence, flagged for human review** rather than narrowed to Android,
  because the behavior it describes is what makes the default safe on any SDK with a pluggable
  renderer.
- posthog-android `main` (3.x) still defaults the switch off and will conform when 4.0 ships.
  The spec records the 4.0 behavior, matching how the mobile 4.0 majors were recorded in the
  wireframe-removal and empty-variant changes.
