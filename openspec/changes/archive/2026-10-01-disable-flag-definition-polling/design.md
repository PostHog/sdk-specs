## Context

The polling lifecycle in `flag-definition-loader` is written as a single mode: load, then poll. `posthog-node` now has a second mode where the caller owns refresh timing. The two modes differ only in whether a recurring timer exists, so this is an added requirement rather than a rewrite of the canonical behavior.

## Goals / Non-Goals

Goals: say what an SDK must preserve when automatic polling is off, so the opt-out cannot quietly turn into "local evaluation off" or "fall back to remote evaluation".

Non-goals: mandate the option, its name, or its sentinel value across SDKs.

## Decisions

- **`MAY` expose, `SHALL` behave.** One SDK implements it. Requiring it everywhere would make every other server SDK non-conformant today, the same reasoning the `evaluate-flags` runtime filter used.
- **Sentinel value left to the platform.** `posthog-node` uses `null` because `undefined` already means "use the default" in its config object. A language without that distinction needs a different spelling (`0`, a dedicated boolean), so the spec requires an explicit disabled setting distinct from "omitted" rather than a literal value.
- **Initial load stays.** Disabling the timer must not mean an empty definition set; otherwise the first local evaluation would silently fall back to remote evaluation.
- **Failure behavior stays scoped.** A failed refresh still preserves definitions and any SDK-specific backoff behavior for the refresh paths where that SDK already applies it. It does not get to schedule the recurring timer the caller just turned off, and force-refresh APIs may keep bypassing backoff when that is their existing behavior.

## Risks / Trade-offs

- A caller that disables polling and never refreshes evaluates against definitions frozen at startup. That is the point of the setting, but it makes stale local evaluation a caller responsibility; the requirement says so explicitly.

## Validation

`openspec validate --specs --strict`.
