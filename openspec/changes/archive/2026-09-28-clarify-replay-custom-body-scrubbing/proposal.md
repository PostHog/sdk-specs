## Why

The replay privacy spec incorrectly requires default body scrubbing before a custom network masking callback. [posthog-js #1085](https://github.com/PostHog/posthog-js/pull/1085) deliberately made the callback replace that heuristic scrubber because substring matches can redact harmless bodies (`author` matches `auth`); [review of #5129](https://github.com/PostHog/posthog-js/pull/5129#discussion_r4119504513) identified the resulting compatibility regression.

## What Changes

- Correct the canonical contract: mandatory header redaction, payload-size limiting, and ingestion-path filtering run before either body-scrubbing strategy.
- A custom `maskCapturedNetworkRequestFn` replaces default body-content scrubbing, rather than running before or after it. Without a custom callback, default scrubbing remains enabled.
- Add scenarios for default scrubbing, callback ownership of bodies, mandatory protections, deprecated-hook compatibility, and callback-requested drops.
- Define modern callback nullish returns and per-record exception isolation: retain only timing metadata for nullish initial entries, but drop throwing records and their derived server timings without affecting unrelated records. Exception isolation requires a separate posthog-js fix; it is not a claim about existing SDK conformance.
- Withdraw the corresponding compliance finding and its incorrect claim that unconditional pre-hook body scrubbing is backward-compatible.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-replay-privacy`: distinguish mandatory network cleaning from replaceable body-content scrubbing.

## Impact

Canonical specification correction, not a new SDK API or opt-out. Existing browser SDK behavior is preserved; no SDK implementation changes are required for this ordering. No mobile masking rules, capture eligibility rules, harness bindings, or dependencies change. The proposed behavior in posthog-js #5129 would conflict with this corrected contract.
