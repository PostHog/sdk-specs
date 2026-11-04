## ADDED Requirements

### Requirement: Device language and app display language

A client SDK that reports the user's language SHALL report it as two distinct event properties, each carried on every event the SDK enriches with ambient context:

- **`$locale`** — the first language in the *device's own* language preferences, as a full IETF BCP 47 language tag carrying every subtag the platform reports: script and region included (`de-CH`, `zh-Hant-TW`), never reduced to the bare language subtag. Unicode extension subtags, such as the `-u-fw-mon` first-day-of-week preference, SHALL be stripped.
- **`$app_language`** — the language the app's user interface is actually displayed in, named the way the platform names that localization, which MAY itself carry a region or script (`de`, `pt-BR`, `zh-Hans`).

Neither property SHALL be read from a process-global locale default the app can set on itself — `Locale.getDefault()` on the JVM, `Locale.setDefault` anywhere — because such a default reports the app's own choice back as the device's preference. `$locale` SHALL be read from the platform's device-language API (iOS `Locale.preferredLanguages`, Android `LocaleManager.getSystemLocales()`), and `$app_language` from the app's own resolved localization.

Each property SHALL be omitted, not sent empty and not guessed, when the SDK has no value for it:

- `$locale` is omitted when the platform reports no language, or only a placeholder naming none (`und`, `C`, `POSIX`).
- `$app_language` is omitted when the SDK cannot determine the displayed language. Detection MAY be limited to the platform versions that expose it (posthog-android detects it on Android 13+ only), and an SDK that cannot determine it on a given platform version SHALL omit it rather than fall back to `$locale`.

Both properties SHALL be re-read, not captured once at setup, so a language changed while the app runs is reflected on later events. Reading them SHALL NOT block the setup or capture path on a system call that can be slow.

The SDK SHALL expose a public method that overrides `$app_language` — `setAppLanguage(_:)` on posthog-ios, `setAppLanguage()` on posthog-android — for an app that translates through its own mechanism rather than platform localizations. The method:

- SHALL accept the language as a string, and the platform's null or an empty/whitespace-only string to clear the override and return to detection;
- SHALL trim surrounding whitespace and normalize the value to language-tag form (`" pt_BR "` is sent as `pt-BR`);
- SHALL hold the override in memory only: it is not persisted, and `reset()` does not clear it, because it describes the app rather than the user.

A caller-supplied or registered `$app_language` property on an event SHALL win over both the override and detection, under the existing property-precedence requirement.

Neither property SHALL be sent on feature flag evaluation requests. An app that wants to target on language SHALL set it as a person property itself.

**Unresolved divergence — the per-app language.** Both platforms let a user pick a language for one app. iOS surfaces that choice as the first entry of `Locale.preferredLanguages`, so posthog-ios 4.0's `$locale` follows it; posthog-android 4.0's `$locale` stays the device-wide language and the per-app choice reaches `$app_language` only. For a user who has set a per-app language, `$locale` therefore means different things on the two platforms. This spec records the divergence and names no winner.

#### Scenario: The device language is sent as a full language tag (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the device's first preferred language is "de-CH"
- **WHEN** an event is captured
- **THEN** the event properties should include `$locale` with value "de-CH"

#### Scenario: A regional preference extension is left out of the device language (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the device's first preferred language is "en-US-u-fw-mon"
- **WHEN** an event is captured
- **THEN** the event properties should include `$locale` with value "en-US"

#### Scenario: A locale default the app set on itself is not reported as the device language (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the device's first preferred language is "de-CH"
- **AND** the app has set its own process-global locale default to "es-ES"
- **WHEN** an event is captured
- **THEN** the event properties should include `$locale` with value "de-CH"

#### Scenario: A platform naming no language sends no device language (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the platform reports the locale "und"
- **WHEN** an event is captured
- **THEN** the event properties should not include `$locale`

#### Scenario: The displayed language is sent separately from the device language (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the device's first preferred language is "de-CH"
- **AND** the app is displayed in its "de" localization
- **WHEN** an event is captured
- **THEN** the event properties should include `$locale` with value "de-CH"
- **AND** the event properties should include `$app_language` with value "de"

#### Scenario: An undetectable displayed language is omitted rather than filled from the device language (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the device's first preferred language is "fr-FR"
- **AND** the SDK cannot determine the language the app displays
- **WHEN** an event is captured
- **THEN** the event properties should include `$locale` with value "fr-FR"
- **AND** the event properties should not include `$app_language`

#### Scenario: A language changed while the app runs reaches later events (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the device's first preferred language is "de-CH"
- **WHEN** an event is captured
- **AND** the device's first preferred language changes to "es-ES"
- **AND** a second event is captured
- **THEN** the first event properties should include `$locale` with value "de-CH"
- **AND** the second event properties should include `$locale` with value "es-ES"

#### Scenario: The app language override is trimmed and normalized (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the app is displayed in its "en" localization
- **WHEN** the app language is set to " pt_BR "
- **AND** an event is captured
- **THEN** the event properties should include `$app_language` with value "pt-BR"

#### Scenario: Clearing the app language override returns to detection (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the app is displayed in its "en" localization
- **AND** the app language is set to "de"
- **WHEN** the app language is set to the platform's null value
- **AND** an event is captured
- **THEN** the event properties should include `$app_language` with value "en"

#### Scenario: The app language override survives a reset (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the app is displayed in its "en" localization
- **AND** the app language is set to "de"
- **WHEN** reset is called
- **AND** an event is captured
- **THEN** the event properties should include `$app_language` with value "de"

#### Scenario: A caller-supplied app language wins over the override (@client)
- **GIVEN** a client SDK that reports the user's language
- **AND** the app language is set to "de"
- **WHEN** capture is called with properties:
  | property       | value |
  | $app_language  | fr    |
- **THEN** the event properties should include `$app_language` with value "fr"
