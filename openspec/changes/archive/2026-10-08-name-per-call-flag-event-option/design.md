## Context

Every flag-reading API takes some form of "do not send `$feature_flag_called` for this call". The name has been stable for years on iOS, Android, and the server SDKs, but the specs only ever showed it inside per-SDK signature lists. posthog-js names the per-call option `sendEvent` (core, react-native) and `send_event` (browser); its `sendFeatureFlagEvent` in core and react-native is the instance-level client option. Flutter shipped `sendEvent` with `getFeatureFlagResult` in #279; the rename to `sendFeatureFlagEvent` is merged for Flutter 6.0 (unreleased).

## Goals

- Write down the name, so the next SDK or port does not invent a third one.
- State the Flutter facts precisely in three spec lines: released 5.x names versus the unreleased 6.0 renames.

## Decisions

**Singular on clients, plural on servers.** Client SDKs name it `sendFeatureFlagEvent` (`send_feature_flag_event`): the option governs one call's `$feature_flag_called`. Server SDKs name it `sendFeatureFlagEvents` (`send_feature_flag_events`): the option governs event sending across an evaluation that may emit several. This is the shipped split, not a preference — iOS and Android use the singular, as does Flutter 6.0 (unreleased); Node, Python, Ruby, and PHP use the plural.

**Shipped divergences are recorded, not renamed.** posthog-js (`sendEvent` in core and react-native, `send_event` in browser) and released Flutter 5.x (`sendEvent`) ship different per-call names. The requirement lists them as known divergences so it does not make those SDKs non-compliant without saying so.

**Casing is platform-adapted.** Snake case on Python, Ruby, and PHP named arguments; camel case elsewhere. The spec names the concept and allows the casing, as it does for other option names.

**The Flutter `optIn`/`optOut` correction rides along.** `optIn()`/`optOut()` shipped in 5.51.0 and the removal of `enable()`/`disable()` is part of the same unreleased 6.0 convergence, and `opt-in` listing no Flutter variant is a gap in the same family of facts. It needs no requirement of its own: the `opt-in` spec already lists per-SDK surface variants and `optIn`/`optOut` is the canonical pair it documents.

## Open questions

None. The names are observable in each SDK's shipped public API.
