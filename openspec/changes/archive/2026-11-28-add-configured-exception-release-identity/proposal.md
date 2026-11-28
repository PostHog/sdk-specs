## Why

Client applications that ship one immutable build and configure it at startup need to name the
release their exceptions belong to without rebuilding that artifact, and without first resolving
a PostHog release UUID in their deployment pipeline.

posthog-js now accepts that identity at runtime through an `error_tracking.release` init option
(PostHog/posthog-js#5888). No spec described this configuration, so the contract other client
SDKs would follow — the accepted forms, the property mapping, and where it sits against caller,
session, super-property and build-injected release identity — is unrecorded.

## What changes

- Record the exception-scoped runtime release configuration: the two mutually exclusive forms,
  trimming and rejection of incomplete input, the mapping onto `$release_id` and the
  `$app_namespace`/`$app_version`/`$app_build` triple, and its precedence against explicitly
  supplied release identity and a build-injected release id.
- Keep the configuration exception-scoped: it does not register properties on other events and
  the SDK still does not create releases.

## Capabilities

### Modified capabilities

- `exception-event-metadata`

## Impact

Applies to client SDKs that expose an error-tracking release option. posthog-js is the only SDK
that ships one today; the requirement states the contract the others follow if they add it.
Server SDKs keep resolving `$release_id` from the environment under the `capture` capability's
**Environment-sourced release identifier**, which is unchanged.
