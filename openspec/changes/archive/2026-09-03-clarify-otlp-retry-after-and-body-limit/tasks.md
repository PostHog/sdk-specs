## 1. Spec delta

- [x] 1.1 Confirm the `traces` delta modifies exactly two requirements — Error handling and retries, Batch assembly and concurrency — each as a full copied-and-edited block
- [x] 1.2 Verify the `traces` Error handling requirement states the floor rule and the order it composes with the clamp (`max(ownBackoff, min(parsedRetryAfter, documentedMaximum))`), both wire forms, the fallback-not-zero rule (unparseable, past HTTP-date, non-positive delta), the clamp, the reconnect rule, and the retry-budget exemption for caller-driven flushes
- [x] 1.3 Verify the `traces` Batch assembly requirement keeps the reactive 413 path mandatory and makes proactive measurement optional, uncompressed, and byte-measured
- [x] 1.4 Confirm the `logs` delta modifies exactly one requirement — Error handling and retries — and that its `Retry-After` sentence now reads as a floor rather than a replacement
- [x] 1.5 Check the two capabilities state the same *complete* rule in the same words — no clause present in one and absent from the other — since divergent wording is what produced the SDK split

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Correct the `traces` **Server-side contract** requirement: posthog/posthog#75090 is described as "in flight" but was closed unmerged on 2026-08-17. Its token-shape half was salvaged as posthog/posthog#76501 and merged 2026-08-04, so the capture-logs authorizer now 401s a token that cannot be a project API key on the traces, logs and metrics endpoints; only the quota half is unreplaced
- [x] 2.2 In the same place, record that with quota enforcement at capture abandoned, the realistic source of a `429` + `Retry-After` is a proxy, CDN or load balancer in front of capture — which is also why the clamp exists
- [x] 2.3 Check whether the `logs` **Server-side contract** requirement carries the same stale claim and correct it if so — it does not; logs already says "any 429 a client sees comes from shared infra"

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into `specs/traces/spec.md` and `specs/logs/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 **posthog-android** — `PostHogQueue.calculateDelay` lets `retryAfterSeconds` replace the backoff and applies no clamp, and `PostHogApi` parses the header with `toIntOrNull()`, so only delta-seconds. Migrate to the floor rule, add a documented maximum, and add HTTP-date parsing
- [ ] 4.2 **posthog-ios** — already floors (`max(backoffDelay, retryAfter)`) and parses both wire forms (`parseRetryAfter`), but applies no clamp; add one
- [ ] 4.3 **posthog-go** — `retryDelayV1` clamps to `defaultMaxBackoff` (30s) since [#255](https://github.com/PostHog/posthog-go/pull/255), but the legacy `/batch/` send in `sendBatch` still floors with no clamp, and `CaptureModeLegacy` is the default; apply the same clamp there
- [ ] 4.4 **`metrics` capability** — posthog-python's public-alpha `client.metrics` ([#739](https://github.com/PostHog/posthog-python/pull/739)) retries `429`/`5xx` without reading `Retry-After`, while posthog-js applies the `logs` policy to its metrics queue. Two shipped implementations already disagree, so write the canonical `metrics` retry policy rather than deferring it
