## Why

[posthog-js#4287](https://github.com/PostHog/posthog-js/pull/4287) ("keep session-attribution
props on minimal `$feature_flag_called` events") fixed a web-analytics data-correctness bug: the
minimal-event allowlist introduced by [posthog-js#4172] (and documented in this repo by
[sdk-specs#16](https://github.com/PostHog/sdk-specs/pull/16), "minimize-feature-flag-called-events")
stripped every referrer and campaign/click-id super property (`utm_source`, `gclid`, `$referring_domain`,
etc.) from a minimized event. Web-analytics session-initial UTM attribution and channel-type grouping
are read from the **first event in a session** — and a minimized `$feature_flag_called` event can be
that first event. A flag call landing first in a session, on a project using minimal events, silently
nulled out the whole session's attribution.

`openspec/specs/feature-flag-called-tracker/spec.md`'s "Minimal event mode for non-experiment flags"
requirement (added by sdk-specs#16) already lists the allowlist categories at a category level
("Session/SDK linkage", "Group and person-processing context", etc.) but never mentions referrer or
campaign/UTM properties anywhere — not in the category list, the posthog-python reference literal, or
the "everything else... SHALL be stripped" closing clause. That's a real spec gap: an SDK implementing
minimal-event-mode strictly per the current spec text would (correctly, per the spec) strip these
properties and reproduce the same attribution bug. The spec needs a category for this, not just the
one SDK's bug fix.

## What Changes

- **Modified requirement** `Minimal event mode for non-experiment flags`: adds a
  "Session-attribution properties" category to the minimal-event allowlist — `$referring_domain` and
  the canonical campaign/click-id super properties (`utm_source`, `utm_medium`, `utm_campaign`,
  `utm_content`, `utm_term`, `gad_source`, `mc_cid`, `gclid`/`fbclid`-style click ids) — with a note
  that the full `$referrer` property remains excluded (only `$referring_domain` and the bare
  campaign-param keys survive minimization, preserving the minimal event's privacy/payload-size intent).
- Adds one new `@client` scenario asserting session-attribution properties are retained while
  `$referrer` itself is still stripped.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `feature-flag-called-tracker`: the "Minimal event mode for non-experiment flags" requirement gains
  one new allowlist category and one new scenario. All other requirements and scenarios are unchanged.

## Impact

- `openspec/specs/feature-flag-called-tracker/spec.md` — source of truth, updated via this change's
  delta.
- Implementations: posthog-js (browser) and posthog-node already conform after posthog-js#4287 (the
  fix lives in `@posthog/core`'s shared `minimizeFlagCalledEventProperties`, used by both). No other
  SDK in scope currently ships a minimal-event mode per sdk-specs#16's own audit — this is a
  documentation-only correction for the shared JS/TS implementation, not a cross-platform parity gap.
- No acceptance-harness changes in this proposal; the new scenario follows the same
  registered-super-property style as the existing minimal-event scenario in this spec.
