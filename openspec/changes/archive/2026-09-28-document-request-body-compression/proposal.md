## Why

The `http-client` spec mentions compression three times, always as an aside: "optional Content-Encoding (gzip)", "gzip compression for batched event uploads", and "timeout / compression / custom transport configuration" as state read. Nothing states the default, what an opt-out looks like, or what the transport does when compression is off or fails.

That gap became visible when apps behind managed networks and Android work profiles had their gzipped bodies rewritten in transit and rejected with HTTP 400, with no way to opt out because `Content-Encoding` is a reserved header. PostHog/posthog-android#793, PostHog/posthog-ios#851, and PostHog/posthog-flutter#603 added a `compression` config for this, and posthog-js has carried a boolean `disable_compression` for much longer. The shapes differ, and none of it is written down.

## What Changes

- Specify gzip as the default encoding for the request bodies an SDK compresses.
- Require a configuration surface that turns compression off, allow both the enum and boolean shapes already shipped, and recommend the extensible enum shape for new surfaces.
- Specify the observable result of opting out: a plain JSON body with no `Content-Encoding` header on every endpoint the SDK would otherwise compress.
- Require the opt-out to be reachable through configuration rather than by overriding the reserved `Content-Encoding` header.
- Permit sending an uncompressed body when compression itself fails locally, and forbid silently downgrading and resending after a server rejects a compressed body.

## Capabilities

### Modified Capabilities

- `http-client`: request body compression default, opt-out surface, and failure behavior.

## Impact

posthog-android, posthog-ios, posthog-flutter, and posthog-js satisfy the opt-out requirement today. Other SDKs that gzip request bodies without exposing a control do not; implementation belongs in their repositories.

## Non-goals

No change to which endpoints an SDK compresses, to response decompression, or to transport-level negotiation. No new encodings beyond gzip.
