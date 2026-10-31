## Why

Four server SDKs are moving event delivery to capture v1 in their next majors: posthog-python 8.0, posthog-go v2, posthog-rs 1.0 and posthog-node 6.0. Their `v1` branches already agree on one wire contract and one event-building order, but the canonical `capture`, `retry-queue`, `http-client` and `event-batcher` specs still describe the legacy wire (`/batch/`, `api_key` in the body, `$lib` stamped into properties, global defaults overwriting the call, 429 retried, batches shrunk on 413). The next SDK to port has no contract to copy, and the harness cannot tell a v1 SDK from a legacy one for these rules.

## What Changes

- Add the capture v1 wire contract to `capture`: the two endpoints, the required headers and which of them change on a retry, the request body, strict field types, the per-event `results` map and what each verdict means for the SDK.
- Add per-event `options` to `capture`: the four legacy option properties and how they are hoisted after `before_send`, no value conversion, unknown keys passed through, global and context options where the SDK has global and context properties.
- Add the canonical event-building order for server SDKs to `capture`: the call wins, context and global values fill only unset keys, SDK values fill last, `before_send` has the final say, hoisting runs once at the end. **BREAKING** for posthog-python and posthog-go, where global defaults used to overwrite the call. Folds in the flag-property rule proposed in #145.
- Add the identity, timestamp, uuid, event-name and size rules capture v1 makes observable: blank distinct ids, the `$groupidentify` fallback id, canonical uuids and `duplicates_dropped`, RFC 3339 timestamps with sub-second precision, per-event serialization, `$lib` owned by the header, fail-open on a missing or personal API key.
- Modify `capture`'s client precedence requirement so its server note no longer says server SDKs stamp `$lib` or apply defaults after the caller's properties.
- Add the capture v1 status and retry rules to `retry-queue` (404/408/429/500/502/503/504 and network errors retried; 402/413 terminal; four attempts with 100 ms doubling waits and jitter; `Retry-After` as a clamped floor; no HTTP-library retries), and mark "shrink on 413" as legacy behavior.
- Add the capture v1 transport rules to `http-client`: bearer token, the required header set, same-origin 307/308 redirects only, the accepted `Content-Encoding` values.
- Add byte-aware batching for capture v1 to `event-batcher`: check before append against a target of at most 5 MiB, an oversize event ships alone, order is kept, no per-event analytics cap below capture's, 413 is terminal.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: capture v1 wire contract, per-event options, server event-building order, identity and validation rules, per-event results; the server note in **Caller-supplied event properties take precedence**.
- `retry-queue`: status classification, attempt budget, backoff and `Retry-After` on capture v1; 429 and 413 handling.
- `http-client`: capture v1 request headers, authentication, redirects and encodings.
- `event-batcher`: byte-aware batching and the end of 413 batch shrinking on capture v1.

## Impact

- posthog-python `v1`, posthog-go `v1`, posthog-rs `v1` and the posthog-node capture v1 series conform, with the variations each requirement records (named in `design.md`). The legacy SDKs (browser, React Native, Android, Flutter on non-Apple platforms, Ruby, PHP, .NET, Elixir, Java) stay on the legacy requirements until their own capture v1 major; the new requirements are scoped to SDKs that deliver through capture v1, and the `capture_v0*` harness features are untouched.
- Open sdk-specs PRs that touch the same ground: #145 (server flag properties; folded in here), #140 (non-finite numbers; this change requires `null`, as #140 does), #81 (gzip by default; the v1 server SDKs default to no compression). These need one decision each before merge.
- `migration/yaml-parity-v1` already carries `capture_v1` cases for the wire, outcomes and retries; this change gives them a canonical home and adds no harness cases.
