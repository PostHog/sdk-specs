## Why

Three server SDKs now stamp a deploy-time release identifier onto every event they produce, read from the `POSTHOG_RELEASE_ID` environment variable: PostHog/posthog-python#975, PostHog/posthog-php#247, and PostHog/posthog-ruby#277. The capture contract does not mention `$release_id` at all, so the property, its precedence rules, and the paths that carry it are unspecified. Only `exception-event-metadata` refers to `$release_id`, and only to require that exception builders preserve release context "where supplied" — it never says where that value comes from.

## What Changes

- Specify `POSTHOG_RELEASE_ID` as the environment input for `$release_id` on server SDKs that can read process environment: read once at client construction, trimmed, blank treated as unset.
- Specify that the property is stamped on the shared event path, so `capture`, exception capture, `identify`, `alias`, and `group_identify` events all carry it.
- Specify precedence: an explicit `$release_id` from caller properties, super/registered properties, or a request context wins over the environment value.
- Specify that the value is a plain event property and is never copied into `$set`, `$set_once`, or `$group_set`, and that `before_send` observes and may remove it.
- Leave low-level passthrough APIs that bypass the shared event path (for example PHP's `raw()`) out of the requirement.

## Capabilities

### Modified Capabilities

- `capture`: environment-sourced `$release_id` enrichment and its precedence.

## Impact

Three server SDKs implement this today. Browser bundles get `$release_id` injected by `posthog-cli` rather than from the SDK, so this requirement is scoped to server SDKs with process-environment access. Other server SDKs (Node, Go, Java, .NET, Elixir, Rust) do not read the variable yet; implementation belongs in those repositories.

## Non-goals

No change to release creation, symbol upload, or server-side release resolution. This change does not standardize whether minimized `$feature_flag_called` events carry `$release_id` — the SDKs currently disagree and the existing allowlist requirement already states the allowlist at the category level.
