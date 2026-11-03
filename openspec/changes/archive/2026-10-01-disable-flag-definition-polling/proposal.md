## Why

`flag-definition-loader` assumes a server SDK that loads local-evaluation definitions also runs a recurring refresh timer: "Once enabled, the loader periodically refreshes definitions in the background", and the only polling scenario fixes the interval at 30 seconds. Nothing in the contract describes a loader that loads definitions once and refreshes only when the caller asks.

PostHog/posthog-js#5140 (`posthog-node`) added exactly that: `featureFlagsPollingInterval: null` keeps the initial definition load and local evaluation but schedules no recurring timer, so a hibernating serverless worker is not kept awake by a pending timer. An omitted value still selects the 30-second default and a numeric value still polls as before. The spec has no place for this, so an SDK reading it would conclude the timer is mandatory.

## What Changes

- Add a requirement for an explicit "no automatic polling" setting on the definition-loader polling interval: manual refresh and local evaluation keep working, definitions stay put until refreshed, and no recurring timer is scheduled.
- Keep the setting optional (`MAY` expose, `SHALL` behave this way when exposed), because only `posthog-node` ships it today.
- Touch up the two narrative lines that currently imply the poll loop is unconditional.

## Capabilities

### Modified Capabilities

- `flag-definition-loader`: an explicit opt-out of automatic definition polling.

## Impact

Spec only. No existing requirement changes meaning for an SDK that always polls; the default and numeric-interval behavior are unchanged.

## Non-goals

Does not name a configuration key or a disabled sentinel value that every SDK must use, does not make the setting mandatory, and does not touch event-flush or request-timeout timers.
