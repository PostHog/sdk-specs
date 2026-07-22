## Why

The JavaScript SDK family shipped a caller-supplied default for the boolean flag check
(PostHog/posthog-js#4222, from the discussion on PostHog/posthog-js#3930): `isFeatureEnabled`
now accepts a default value returned whenever the flag has no value — flags not loaded yet, a
failed flags request, or no flag with that key. The spec is behind this reality in two ways:

- The **client-side canonical signature** has no `defaultValue`, while the **server-side**
  canonical signature already includes `defaultValue?: boolean` in its options, and Android
  (`defaultValue: Boolean = false`) and Unity (`bool defaultValue = false`) have long exposed it.
- The **missing-flag scenario** mandates a bare `false` for missing flags, which the JS family
  deliberately does not do: its bare call is three-state (`boolean | undefined`) and collapsing
  `undefined` to `false` is a breaking change deferred to the next major (maintainer decision on
  PostHog/posthog-js#3930). The spec's own prose already admits "SDKs vary between `undefined`
  and `false`" — the requirement and scenario should name that variation explicitly instead of
  contradicting it.

## What Changes

- **Requirement prose** (`Canonical is-feature-enabled behavior`): adds the caller-supplied
  default contract — the default applies to *any* no-value case (not loaded, failed load, key
  absent from loaded flags, matching Android's `getFeatureFlagResult(key)?.value ?: defaultValue`
  and Unity's `if (!flag.Value.HasValue) return defaultValue`); a flag that has a value always
  wins over the default. Names the allowed variation: three-state SDKs (the posthog-js family)
  keep returning `undefined` when no default is supplied, until their next major; SDKs with a
  built-in `false` default (Android, Unity) or hard-coded `false` (iOS, Flutter) satisfy the
  missing-flag behavior by construction.
- **Missing-flag scenario** is re-anchored on the default: missing flags resolve to the
  caller-supplied (or signature built-in) default rather than an unconditional bare `false`.
- **New scenarios**: a caller default of `true` is returned for a missing flag; a flag that has a
  value (including `false` and variant values) beats the caller default.
- **Prose alignment at archive** (outside the requirement delta): the client-side canonical
  signature gains `defaultValue?: boolean`; the surface-variants list records the uniform JS
  family form (`isFeatureEnabled(key, { defaultValue })` in posthog-js, posthog-js-lite, and
  react-native); the client/server comparison table row and behavior-flow bullet for unknown
  flags mention the caller-supplied default.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `is-feature-enabled`: the single `Canonical is-feature-enabled behavior` requirement — prose
  gains the default-value contract and the named three-state variation; the missing-flag scenario
  changes; two scenarios are added. The value-mapping and tracking-suppression scenarios are
  unchanged.

## Impact

- `openspec/specs/is-feature-enabled/spec.md` — source of truth, updated via this change's delta
  on archive.
- Implementations: posthog-js, posthog-js-lite, and posthog-react-native already conform
  (PostHog/posthog-js#4222); Android, Unity, iOS, and Flutter already conform by construction.
  Node/Python/PHP/Ruby server SDKs expose the server-side signature, which already includes
  `defaultValue` in this spec; no server-side contract changes here.
- No acceptance-harness changes in this proposal; the harness gains coverage when per-platform
  port changes pick up the new scenarios.
