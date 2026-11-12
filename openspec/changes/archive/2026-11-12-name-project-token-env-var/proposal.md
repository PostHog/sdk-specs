## Why

The `setup` spec settles what the project credential is called on every configuration surface it
names — an options object, a provider's props, a manifest or `Info.plist` key — but it says nothing
about the environment variable an SDK reads when it is initialized without an explicit token. The
SDKs that read one diverge: posthog-php's `PostHog::init()` and its Laravel package now read
`POSTHOG_PROJECT_TOKEN` and fall back to `POSTHOG_API_KEY`
([posthog-php#311](https://github.com/PostHog/posthog-php/pull/311)), and `@posthog/mcp` reads
`POSTHOG_PROJECT_TOKEN`, while posthog-rs and the posthog-rails logs setup still read only
`POSTHOG_API_KEY`. posthog-php#311 flags this as a gap in the spec rather than a divergence from it.

An app configuring two PostHog SDKs should not need two differently named variables for the same
project token, and the name the spec already picked for the option is the name the variable should
carry.

## What Changes

- New **Project token environment variable name** requirement in `setup`: where an SDK reads the
  project token from the environment, the variable is `POSTHOG_PROJECT_TOKEN`; an SDK that already
  reads `POSTHOG_API_KEY` keeps it as a deprecated fallback under the existing alias rules; a blank
  value falls back as if unset. Reading no environment variable at all stays conformant — the
  requirement names the variable, it does not require one.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `setup`: new **Project token environment variable name** requirement.

## Impact

- **posthog-php**: already matches, as of #311 (`PostHog::ENV_PROJECT_TOKEN`, with
  `POSTHOG_API_KEY` deprecated).
- **@posthog/mcp**: already reads `POSTHOG_PROJECT_TOKEN`.
- **posthog-rs**, **posthog-ruby** (the Rails logs setup and the install generator template), and the
  `@posthog/ai` integrations read `POSTHOG_API_KEY` and would add the new name with the old one as a
  fallback. None has to drop the old name.
- SDKs that take the token only from code (posthog-js browser, the mobile SDKs) are unaffected.
