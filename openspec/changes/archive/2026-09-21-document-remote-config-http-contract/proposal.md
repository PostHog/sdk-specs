## Why

The remote-config spec describes fetching project settings but omits the HTTP contract. SDK implementers cannot derive the route, method, credentials, asset-host selection, or wire field names from it.

## What Changes

- Document `GET /array/{projectKey}/config`, request-body and authentication expectations, regional asset hosts, and custom-host preservation.
- Describe the JSON response envelope and representative wire fields without duplicating product-specific schemas.
- Preserve browser preloaded/script configuration as a supported alternative to the JSON request.
- Add concrete HTTP acceptance scenarios after proposal review.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `remote-config`: Add the missing HTTP transport and response contract. Scope applicability to all client and server SDKs that implement project remote configuration, with feature-specific configuration applied only where supported.

## Impact

Specs and acceptance scenarios only; no SDK implementation changes or new dependencies. Affects `remote-config` documentation and `acceptance/private/remote-config.feature`. SDKs without this capability are not newly required to implement it.
