## Why

`flag-definition-loader` names a manual refresh surface (for example `reloadFeatureFlags()`) but says nothing about what completing one means. Server SDKs have now converged on an observable completion, and the contract they converged on is unwritten.

- posthog-go `b17c59b1` (PostHog/posthog-go#458) adds `ReloadFeatureFlagsWithContext(ctx) error` behind a `FlagReloader` interface: it fetches definitions and returns once they are in use, with the fetch error on a non-success status, a quota-limited response (`ErrFlagDefinitionsQuotaLimited`) or a decode failure, or the context error if the caller's deadline ends first. The existing `ReloadFeatureFlags()` keeps signalling the poller and returning.
- posthog-rs `3188466a` (PostHog/posthog-rs#380) adds `Client::reload_feature_flags` (async and blocking) with the same shape: it returns once the fresh definitions are in use, or `Error::Connection` / `Error::Serialization` on failure, and leaves the background poll on its schedule.
- posthog-node's `reloadFeatureFlags()` already awaits a forced definition load (`packages/node/src/client.ts`), and posthog-python's `load_feature_flags()` loads synchronously before returning (`posthog/client.py`), so the completion rule matches the SDKs that shipped it earlier.

Both PRs cite the same driver: the shared harness's local evaluation suite needs a refresh that returns only when the fresh snapshot is usable.

## What Changes

- **`flag-definition-loader`**: add an **Awaiting a manual definition refresh** requirement. An observable completion resolves only once the fetched definitions are the ones local evaluation reads; scheduling and returning does not count. A surface that reports an outcome reports the fetch failure and preserves existing definitions, except where existing quota or auth policy clears them, and does not stop or reschedule the background poll. A refresh that takes a caller deadline or cancellation returns on it rather than reporting success. An SDK may keep a separate schedule-and-return surface.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `flag-definition-loader`: one added requirement. Existing requirements, including **Automatic definition polling can be disabled**, are unchanged.

## Impact

- Descriptive of shipped behavior in posthog-go, posthog-rs, posthog-node and posthog-python. No SDK behavior change is required by this spec change.
- Deliberately unspecified: what a refresh does when local evaluation is not configured. posthog-go refuses without a secret key, posthog-rs returns `Error::InvalidArgument`, and posthog-python logs a warning, clears definitions and returns. The SDKs diverge, so the requirement marks it SDK-specific rather than picking a winner.
