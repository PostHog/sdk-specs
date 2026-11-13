## Why

A server can read the payload of a remote config feature flag with one request that needs no distinct id: `GET {host}/api/projects/@current/feature_flags/{key}/remote_config?token={project token}` with a secret key as a Bearer token. Five server SDKs wrap it: posthog-node (`getRemoteConfigPayload`), posthog-python, posthog-ruby, posthog-go and posthog-dotnet. posthog-android (`posthog-server`), posthog-php, posthog-elixir and posthog-rs do not. The request is tracked for Java in PostHog/posthog-android#577, and that issue asks which name, which behavior without a key, and which error channel to use.

The five SDKs differ. They differ when the secret key is missing, in the return type, in how they escape the flag key, in how a failure reaches the caller, and in the result for a non-2xx status. No spec says which behavior is right. `sdk-specs` has no contract for this method. The `remote-config` capability covers the client `/config` bootstrap, which is a different feature, and the weekly compliance files already mark this method as unrelated to it.

This change records a contract for reading a remote config flag payload on the server, at the strength the posthog-node implementation and its tests support. Where the evidence does not decide a point, the change leaves the point out of the requirements and lists it as an open decision in `design.md`. Three points are recommendations (`SHOULD`) that posthog-node does not follow: the encoding of the flag key, the failure of a non-2xx response, and no result for a 2xx response with an empty body. posthog-node has none of these behaviors, so the spec does not make them mandatory.

## What Changes

- New capability spec `get-remote-config-payload` for server SDKs, covering: the public surface, the request, authentication, no distinct id, disabled clients and a missing project token, a missing secret key, flag key encoding, payload decoding (including the second parse of a string body and the fallback), an empty body, request failure, failure status, one request per call, no caching, no events, and independence from local evaluation.
- New acceptance feature `acceptance/public/get-remote-config-payload.feature`.
- Not in the requirements, and listed as open decisions in `design.md`: the channel for a missing secret key (and whether a thrown error is allowed), the result for a 2xx response whose body is not JSON, the request timeout, which host a port uses when the SDK has more than one, and a flag key that is empty, `.` or `..`.
- Recommended although posthog-node differs: the SDK should percent-encode the flag key as one path segment, a response with a status outside 200 to 299 should fail the call, and a 2xx response with an empty body should give no result and no failure report. `design.md` lists which shipped SDKs follow each recommendation.
- Out of scope: caching, background sync and ETag use (PostHog/posthog#69808 tracks them), the client `/config` bootstrap, and changes to the five SDKs that already have the method. `design.md` lists where each of them differs from the contract.

## Capabilities

### New Capabilities

- `get-remote-config-payload`: server-side read of one remote config flag payload by flag key, with a secret key, no distinct id, no cache and no event.

### Modified Capabilities

None. The `remote-config` capability is not changed. Open PR PostHog/sdk-specs#210 changes only that capability.
