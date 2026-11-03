## Context

The credential a client SDK is configured with is a PostHog **project token** (`phc_…`), not an API key. The old `apiKey` name is easy to confuse with a personal API key, which is a different credential with different scope. Five SDKs have now renamed the public option; the spec has no opinion on the name.

## Goals

- Record `projectToken` as the canonical option name so a new SDK, or a port of an existing one, does not reintroduce `apiKey`.
- Record the deprecation shape the renamed SDKs converged on, so the alias is not dropped inconsistently.
- Keep the requirement to the public configuration surface, where the SDKs actually agree.

## Decisions

**Canonical name is `projectToken`, in platform casing.** Shipped as `projectToken` (iOS, Android, Flutter, KMP), `ProjectToken` (.NET), and `com.posthog.posthog.PROJECT_TOKEN` for Flutter's native auto-init manifest and `Info.plist` keys. The spec names the concept and allows the casing, matching how it treats other option names.

**The old name is a deprecated alias, not a removal.** Every renamed SDK kept `apiKey` (`ProjectApiKey` on .NET, `com.posthog.posthog.API_KEY` for auto-init) resolving to the same value and deprecated in favor of `projectToken`, slated for removal in the next major. Requiring the alias is what makes the rename a minor release everywhere, including for the SDKs that have not renamed yet: they add `projectToken` and the alias together, and only dropping the alias waits for a major.

**Deprecation signal is compile-time or runtime.** iOS, .NET, and Flutter's native auto-init keys log a runtime warning. Android, KMP, and Flutter's Dart `apiKey` getter rely on `@Deprecated` alone. The requirement accepts either, so the acceptance scenario checks the resolved value rather than a log line.

**"projectToken wins" applies only where both names can be supplied.** iOS, Android, KMP, and Flutter's Dart config take the token through separate constructors, so a caller cannot pass both. The precedence rule and its scenario (`@both_token_names_capable`) apply to options objects, provider props, and manifest or `Info.plist` keys.

**The rename stops at the public config surface.** Wire payload fields (`api_key`, `token`), stored queue and preference paths, and the server-side builder parameter names are unchanged, so stored queues and in-flight payloads carry over. Positional constructors — browser `init(token, …)`, React Native `new PostHog(apiKey, …)`, `PostHogAndroidConfig("phc_…")` — were never affected, because the parameter name is not part of the call.

**Trimming is narrative, not a requirement.** iOS, Flutter, Android, and React Native all trim the configured value, but trimming predates the rename and is not what this change is about. It is recorded in the narrative rather than asserted as a scenario.

## Open questions

When React Native (`PostHogProvider`'s `apiKey` prop) and Unity (`PostHogConfig.ApiKey`, `PostHogSettings.ApiKey`) add `projectToken`. The spec now requires it; the release is tracked in those repos.
