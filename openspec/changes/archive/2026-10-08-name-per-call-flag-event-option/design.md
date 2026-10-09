## Context

Every flag-reading API takes some form of "do not send `$feature_flag_called` for this call". The name has been stable for years on iOS, Android, posthog-js, and the server SDKs, but the specs only ever showed it inside per-SDK signature lists. Flutter shipped `sendEvent` in #117 and nobody noticed the divergence until Flutter renamed it four years later.

## Goals

- Write down the name, so the next SDK or port does not invent a third one.
- Fix the three spec lines that posthog-flutter 6.0 made wrong.

## Decisions

**Singular on clients, plural on servers.** Client SDKs name it `sendFeatureFlagEvent` (`send_feature_flag_event`): the option governs one call's `$feature_flag_called`. Server SDKs name it `sendFeatureFlagEvents` (`send_feature_flag_events`): the option governs event sending across an evaluation that may emit several. This is the shipped split, not a preference — iOS, Android, Flutter (6.0), and posthog-js use the singular; Node, Python, Ruby, and PHP use the plural.

**Casing is platform-adapted.** Snake case on Python, Ruby, and PHP named arguments; camel case elsewhere. The spec names the concept and allows the casing, as it does for other option names.

**The Flutter `optIn`/`optOut` correction rides along.** It is part of the same release's convergence, and `opt-in` listing no Flutter variant is a gap in the same family of facts. It needs no requirement of its own: the `opt-in` spec already lists per-SDK surface variants and `optIn`/`optOut` is the canonical pair it documents.

## Open questions

None. The names are observable in each SDK's shipped public API.
