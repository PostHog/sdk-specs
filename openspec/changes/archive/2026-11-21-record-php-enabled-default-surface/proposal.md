## Why

`is-feature-enabled` requires every SDK to accept a caller-supplied boolean default and names where
that parameter sits on each platform. PHP is missing from that list, and the spec's "Surface
variants" section still shows only the deprecated `Client::isFeatureEnabled(...)` facade, which has
no default parameter.

posthog-php closed that gap in
[posthog-php#324](https://github.com/PostHog/posthog-php/pull/324): the compliant surface is the
`FeatureFlagEvaluations` snapshot accessor, `evaluateFlags(...)->isEnabled(string $key, bool
$defaultValue = false)`, with the deprecated facade deliberately left alone. That PR explicitly
leaves the spec untouched and flags the stale row as worth refreshing here.

So the spec now describes a PHP surface that no longer represents how PHP satisfies the
requirement, and a reader checking PHP against the contract would read the deprecated facade as the
answer.

## What Changes

- `is-feature-enabled`: name PHP's parameter placement in the **Canonical is-feature-enabled
  behavior** requirement, alongside the posthog-js family, Android, Unity, iOS, and Flutter.
- `is-feature-enabled`: replace the stale PHP "Surface variants" bullet with the snapshot accessor
  that carries the default, keeping the deprecated facade visible as the surface without one.

No scenario changes: the behavior the scenarios pin is unchanged, and PHP already matches it.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `is-feature-enabled`: the caller-default sentence of **Canonical is-feature-enabled behavior**
  names PHP's placement.

## Impact

- **posthog-php**: already matches, as of #324.
- Other SDKs: unaffected. This records an existing surface; it adds no requirement.
- The same caller-default gap that #324 fixed for PHP is still open in posthog-go, posthog-ruby and
  posthog-dotnet (per that PR's follow-ups). Those are SDK work, not spec work — the requirement
  already covers them.
