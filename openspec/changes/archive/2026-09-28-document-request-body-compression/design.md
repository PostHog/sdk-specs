## Context and sources

- [posthog-android#793](https://github.com/PostHog/posthog-android/pull/793): adds `PostHogConfig.compression`, a `PostHogCompression` enum with `GZIP` (default) and `NONE`. Motivated by an Intune-managed work profile where gzipped bodies were altered in transit and `/batch` and `/flags` answered 400. No automatic fallback after a rejected body.
- [posthog-ios#851](https://github.com/PostHog/posthog-ios/pull/851): the iOS counterpart. `PostHogCompression { gzip, none }`, `PostHogConfig.compression` defaulting to `.gzip`. With `.none`, `/batch`, `/s/`, `/i/v1/logs`, and `/api/push_subscriptions` send plain JSON with no `Content-Encoding`. Keeps the existing local fallback: if gzipping throws, the body goes out uncompressed. Notes that `content-encoding` is a reserved key, so `requestHeaders` cannot be used to opt out.
- [posthog-flutter#603](https://github.com/PostHog/posthog-flutter/pull/603): exposes the same enum in the wrapper and forwards it to both native configs. Web is untouched because it uses the host page's posthog-js instance.
- posthog-js has `disable_compression: boolean`, default `false`, documented as test-only; with compression enabled, the browser SDK declares gzip with the `compression=gzip-js` URL marker, and when `disable_compression` is true it leaves `this.compression` undefined instead of `Compression.GZipJS`.

## Decisions

1. Specify the default and the observable off-state, not the endpoint list. Android compresses `/flags` while iOS never has, and neither PR treats that as a defect to fix. Fixing an endpoint list here would invent a contract instead of recording one.
2. Allow both the mobile enum and the posthog-js boolean. Both are shipped public API; requiring one name would be a breaking rename with no behavioral gain. Recommend the enum shape for new surfaces, the rationale both mobile PRs give.
3. Require the control to be reachable through configuration. The reserved-header problem is exactly what made these apps stuck, so "there is a custom-header workaround" is not an acceptable substitute.
4. Permit a local gzip failure to fall back to an uncompressed body (iOS does this), but forbid downgrading and resending after a server rejects a compressed body. Both mobile PRs explicitly declined automatic retry-after-400, citing the lack of a reproduction.

## Validation

`openspec validate --specs --strict` and delta/canonical parity. The scenarios are contracts, not a claim that cross-SDK conformance tests have been run.

## Risks

Leaving the compressed-endpoint set unspecified means an app that opts out still cannot predict which requests changed shape, only that none of them are compressed afterwards. Whether `/flags` should be gzipped at all is a real cross-SDK divergence that this change deliberately does not settle.
