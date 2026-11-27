## ADDED Requirements

### Requirement: Survey appearance font family

A survey definition's `appearance.fontFamily` names the font its UI SHALL use. An SDK that renders
built-in survey UI SHALL apply the resolved font across the whole survey surface — question text,
description, intro screen, confirmation message, button labels, and text input value and
placeholder — rather than to a subset of that text. Applying it SHALL NOT change any other
appearance attribute the renderer already sets: font sizes, weights, text-style scaling, and colors
are unaffected.

The value is a CSS `font-family` list. A renderer that is not resolving CSS SHALL use only the first
family in that list: the content of a leading quoted name (which may itself contain commas), or
otherwise the text before the first comma, with surrounding whitespace and quotes removed. It SHALL
NOT pass the remaining entries, the separators, or the quotes to its font loader, and SHALL match the
family against installed fonts case-insensitively.

The field SHALL be treated as unset when it is absent, null, or empty or whitespace-only, when its
first family is empty, or when its first family is one of the case-insensitive CSS keywords
`inherit` or `system-ui`. `inherit` is the surveys API default, and neither keyword names a family,
so a renderer that is not resolving CSS MUST NOT pass either to its font loader. When the field is
unset, the SDK SHALL render in the font its survey UI uses when no family is given, so a survey that
does not set one looks unchanged. A CSS renderer resolves the keywords as CSS does: it MAY emit
`inherit` verbatim so the survey takes the host document's font, and posthog-js applies the
`inherit` default to an absent field.

A named family the platform cannot resolve — a font the application does not bundle and the device
does not install — SHALL fall back to that same default font. The fallback MUST NOT raise into the
host application and MUST NOT prevent the survey from being displayed. A CSS renderer SHALL keep its
default font stack after the requested family so the fallback happens during font matching.

An SDK that does not render surveys itself but builds a display model for a host, wrapper, or
framework-native UI layer SHALL carry `fontFamily` through that model unchanged, including a CSS
list or an `inherit` value, so the rendering layer resolves it under this requirement.

#### Scenario: A survey appearance font family is applied across the survey
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `fontFamily` set to a family the platform can resolve
- **WHEN** survey "survey-1" is rendered
- **THEN** the question text, description, button labels, and text input placeholder should use that family
- **AND** their font sizes, weights, and colors should be unchanged

#### Scenario: A non-CSS renderer uses the first family of a CSS list
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** the SDK renders surveys without resolving CSS
- **AND** survey "survey-1" has appearance field `fontFamily` set to "\"Times New Roman\", serif"
- **WHEN** survey "survey-1" is rendered
- **THEN** the platform font loader should be asked for the family "Times New Roman"
- **AND** no font named "serif" or containing a quote or comma should be requested from the platform font loader

#### Scenario: The inherit sentinel renders the default font
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `fontFamily` set to "inherit"
- **WHEN** survey "survey-1" is rendered
- **THEN** the survey should render in the SDK's default font
- **AND** no font named "inherit" should be requested from the platform font loader

#### Scenario: The system-ui keyword renders the default font
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** the SDK renders surveys without resolving CSS
- **AND** survey "survey-1" has appearance field `fontFamily` set to "system-ui, sans-serif"
- **WHEN** survey "survey-1" is rendered
- **THEN** the survey should render in the SDK's default font
- **AND** no font named "system-ui" should be requested from the platform font loader

#### Scenario: A blank font family renders the default font
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `fontFamily` set to a whitespace-only string
- **WHEN** survey "survey-1" is rendered
- **THEN** the survey should render in the SDK's default font

#### Scenario: An unresolvable font family falls back without failing the survey
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `fontFamily` set to a family the application does not bundle
- **WHEN** survey "survey-1" is rendered
- **THEN** the survey should render in the SDK's default font
- **AND** no error should be raised into the host application
- **AND** survey display callback should be invoked for survey "survey-1"

#### Scenario: A delegated display model carries the font family through
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** the SDK delegates survey rendering to a host UI layer
- **AND** survey "survey-1" has appearance field `fontFamily` set to "inherit"
- **WHEN** the display model for survey "survey-1" is built
- **THEN** the display model's `fontFamily` should be "inherit"
