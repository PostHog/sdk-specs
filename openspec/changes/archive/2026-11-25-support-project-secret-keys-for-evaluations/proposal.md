## Why

Teams can now use one scoped project secret API key to manage datasets, scorers, and offline experiments. The existing SDK contract still tells them to use a personal key for management.

## What changes

Document the scopes accepted by the project API, including the extra read scopes for stored composite inputs and the personal-key requirement for dataset exports. Specify how server SDKs send a project credential through their existing evaluations clients.

## Impact

- Capabilities: AI datasets, AI scorers, and offline evaluations
- SDKs: Python, Node.js, and Go
- Backend: [Project secret API key support](https://github.com/PostHog/posthog/pull/140720)
