## Why

External flag definition cache providers are now documented across several server-side SDKs, but the canonical SDK spec only mentions them generically. Implementers adding this to another language need a clear cross-SDK contract for provider methods, sync/async support, fallback behavior, and shutdown lifecycle.

## What Changes

- Define the canonical external flag definition cache provider contract under `flag-definition-loader`.
- Specify the shared cache data shape (`flags`, group-type mapping, and cohorts), allowing platform-idiomatic casing.
- Specify the distributed refresh flow: `shouldFetch` gates direct API fetches, `get` serves shared cached definitions, and `onReceived` stores successful API results.
- Specify that synchronous and asynchronous provider implementations are both valid where the runtime supports them, with async results awaited/bounded before continuing.
- Specify defensive error handling and shutdown cleanup behavior.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `flag-definition-loader`: Adds a canonical requirement for external/shared flag definition cache providers used by local evaluation in distributed or stateless environments.

## Impact

- Server-side SDKs implementing local evaluation in distributed environments.
- Public/internal SDK configuration that accepts an external flag definition cache provider.
- Acceptance coverage for cache-provider read, write, sync/async, error fallback, and shutdown behavior.
