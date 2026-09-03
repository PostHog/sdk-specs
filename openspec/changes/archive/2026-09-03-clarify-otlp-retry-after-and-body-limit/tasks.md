## 1. Spec delta

- [x] 1.1 Confirm the `traces` delta modifies exactly two requirements — Error handling and retries, Batch assembly and concurrency — each as a full copied-and-edited block
- [x] 1.2 Verify the `traces` Error handling requirement states the floor rule, both wire forms, the fallback-not-zero rule, the clamp, and the retry-budget exemption for caller-driven flushes
- [x] 1.3 Verify the `traces` Batch assembly requirement keeps the reactive 413 path mandatory and makes proactive measurement optional, uncompressed, and byte-measured
- [x] 1.4 Confirm the `logs` delta modifies exactly one requirement — Error handling and retries — and that its `Retry-After` sentence now reads as a floor rather than a replacement
- [x] 1.5 Check the two capabilities state the same rule in the same words, since divergent wording is what produced the SDK split

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Correct the `traces` **Server-side contract** requirement: posthog/posthog#75090 is described as "in flight" but was closed as stale in August 2026 without merging, and nothing has replaced it
- [x] 2.2 In the same place, record that with quota enforcement at capture abandoned, the realistic source of a `429` + `Retry-After` is a proxy, CDN or load balancer in front of capture — which is also why the clamp exists
- [x] 2.3 Check whether the `logs` **Server-side contract** requirement carries the same stale claim and correct it if so — it does not; logs already says "any 429 a client sees comes from shared infra"

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into `specs/traces/spec.md` and `specs/logs/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 **posthog-android** — `PostHogQueue.calculateDelay` lets `retryAfterSeconds` replace the backoff and applies no clamp. Migrate to the floor rule and add a documented maximum
- [ ] 4.2 **posthog-ios** and **posthog-go** — both already floor (`max(backoffDelay, retryAfter)`, `backoffV1`) but apply no clamp; add one to each
- [ ] 4.3 **posthog-python** and **posthog-rs** — `capture_v1._backoff` and `retry::backoff_duration` already implement both halves; confirm no change is needed
- [ ] 4.4 **posthog-js** — PostHog/posthog-js#4726 implements the clarified rule; its single 5-minute clamp diverges from the recommended per-queue-ceiling default and should be revisited once the archived text lands
- [ ] 4.5 Consider whether `metrics` needs a spec of its own, or whether it stays covered by the `logs` policy by reference
