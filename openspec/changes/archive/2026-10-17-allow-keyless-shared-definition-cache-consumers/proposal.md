# Proposal

## Why

`flag-definition-loader` presents privileged local-evaluation auth as effectively mandatory
("Local-evaluation definition loading usually requires a personal/admin API key or equivalent
privileged auth") and requires the provider decision step unconditionally: "On each loader refresh
with a provider configured, the SDK SHALL call the provider's fetch-decision operation before
making a direct flag-definition API request."

A worker whose only job is to *read* a shared definition cache has no key and cannot act on a
positive fetch decision. Five SDKs have now shipped the keyless cache-consumer path, and each
change explicitly records that it diverges from the spec's decision-first provider step:

| SDK | PR | Merged |
|---|---|---|
| posthog-js (`packages/node`) | PostHog/posthog-js#5263 | 2026-10-16 |
| posthog-android (`posthog-server`) | PostHog/posthog-android#851 | 2026-10-16 |
| posthog-go | PostHog/posthog-go#366 | 2026-10-16 |
| posthog-ruby | PostHog/posthog-ruby#300 | 2026-10-16 |
| posthog-php | PostHog/posthog-php#259 | 2026-10-16 |

The originating report is PostHog/posthog-python#1039: a process configured with a definition
cache provider and no secret key never evaluated locally, so every flag call became a remote
request.

## What Changes

- A configured external flag definition cache provider becomes a recognized alternative to
  privileged auth for local evaluation. Local evaluation SHALL NOT be refused solely because no
  personal/secret key is configured when a provider is configured.
- A keyless consumer SHALL read definitions directly from the provider cache and SHALL NOT call
  the fetch-decision operation, SHALL NOT publish definitions through the store operation, and
  SHALL NOT issue a direct definition API request.
- With privileged auth configured, the decision-first flow is unchanged: a negative decision reads
  the cache, a positive decision fetches and then publishes, and direct definition requests stay
  authenticated.
- A keyless cache miss or provider read failure SHALL NOT be reported as an auth or HTTP failure.
  Genuine provider errors remain warnings, and previously loaded definitions survive.
- Existing explicit opt-outs (for example a disabled local-evaluation toggle or a disabled client)
  remain effective; a provider does not enable local evaluation on its own.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `flag-definition-loader`: the **External flag definition cache providers** requirement.

## Impact

Descriptive of behavior five SDKs already ship. posthog-python's equivalent fix
(PostHog/posthog-python#1039) is still open, so posthog-python remains the known gap.

- **Acceptance**: two scenarios added to `acceptance/private/flag-definition-loader.feature`,
  written with the same provider step vocabulary as the existing unmigrated provider scenarios in
  that feature. They are not opted in with `@sdk:` tags, because the harness has no bindings for
  the external-cache-provider steps.
