## Context

The credential a client SDK is configured with is a PostHog **project token** (`phc_…`), not an API key. The old `apiKey` name is easy to confuse with a personal API key, which is a different credential with different scope. Five SDKs have now renamed the public option; the spec has no opinion on the name.

## Goals

- Record `projectToken` as the canonical option name so a new SDK, or a port of an existing one, does not reintroduce `apiKey`.
- Record the deprecation shape the renamed SDKs converged on, so the alias is not dropped inconsistently.
- Keep the requirement to the public configuration surface, where the SDKs actually agree.

## Decisions

**Canonical name is `projectToken`, in platform casing.** Shipped as `projectToken` (iOS, Android, Flutter, KMP), `ProjectToken` (.NET), and `com.posthog.posthog.PROJECT_TOKEN` for Flutter's native auto-init manifest and `Info.plist` keys. The spec names the concept and allows the casing, matching how it treats other option names.

**The old name is a deprecated alias, not a removal.** Every renamed SDK kept `apiKey` (`ProjectApiKey` on .NET, `com.posthog.posthog.API_KEY` for auto-init) reading and writing the same value, emitting a deprecation warning that names `projectToken`, slated for removal in the next major. Requiring the alias is what makes the rename a minor release everywhere.

**The rename stops at the public config surface.** Wire payload fields (`api_key`, `token`), stored queue and preference paths, and the server-side builder parameter names are unchanged, so stored queues and in-flight payloads carry over. Positional constructors — browser `init(token, …)`, `PostHogAndroidConfig("phc_…")` — were never affected, because the parameter name is not part of the call.

**Trimming is narrative, not a requirement.** iOS, Flutter, and Android all trim the configured value, but trimming predates the rename and is not what this change is about. It is recorded in the narrative rather than asserted as a scenario.

## Open questions

Whether posthog-js adopts `projectToken` for the browser and React Native surfaces, and on what release. That is tracked in posthog-js; this spec records the name the other SDKs settled on.
