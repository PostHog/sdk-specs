## ADDED Requirements

### Requirement: Interactions inside an explicit mask are not recorded

When a user interaction — a touch, click, or equivalent pointer gesture — begins on a target
inside an **explicit mask region**, the SDK SHALL NOT record that interaction in the replay, and
SHALL NOT record its end. The interaction MUST still be delivered to the application.

Masking the pixels of a region is not enough on its own: an interaction recorded at its exact
coordinates reveals which control inside the masked region the user operated.

An explicit mask region is one marked by the SDK's region-masking controls — browser
`ph-no-capture`, iOS `ph-no-capture` and `postHogMask()`, Android `ph-no-capture` and
`Modifier.postHogMask()`, and the wrapper components that compile to them. Category masking
(`maskAllTextInputs`, `maskAllTexts`, `maskAllImages`) and text masking markers such as `ph-mask`
SHALL NOT drop interactions, because the control is not hidden and dropping the interaction would
remove ordinary taps on text fields from every recording. Explicit unmask markers keep the
precedence they already have, so an interaction inside an unmasked subtree is recorded.

The SDK SHALL decide against the same mask rules and drawn geometry the frame masker uses,
including a view at its animated position, and SHALL evaluate the UI state before the application
handles the event, so an application handler cannot hide the masked view and let the interaction
through.

The decision made when the interaction begins SHALL carry to the rest of that interaction,
including when the masked view is hidden or removed, or the gesture ends outside the mask. An
interaction that ends inside an explicit mask SHALL also be dropped.

When the SDK cannot determine whether the interaction landed inside an explicit mask — for example
a mask region that has not laid out yet — it SHOULD drop the interaction, as it discards an
uncertain snapshot rather than uploading one.

This requirement applies wherever the SDK records replay interactions. The existing rule that
touches on an Android secure window are not recorded is unaffected and continues to apply on its
own trigger.

#### Scenario: A touch inside a no-capture view is not recorded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** a view marked no-capture is on screen
- **WHEN** the user taps inside that view
- **THEN** no interaction is recorded for that tap
- **AND** the application still receives the tap

#### Scenario: A touch inside an explicit mask region is not recorded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** a region marked with the SDK's explicit mask control is on screen
- **WHEN** the user taps inside that region
- **THEN** no interaction is recorded for that tap

#### Scenario: A touch on a view masked only by category masking is recorded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** text input masking is enabled and a text field carries no explicit mask marker
- **WHEN** the user taps the text field
- **THEN** the interaction is recorded
- **AND** the recorded replay still masks the field's text

#### Scenario: A touch inside an explicitly unmasked subtree is recorded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** a view marked with an explicit unmask marker is on screen
- **WHEN** the user taps inside that view
- **THEN** the interaction is recorded

#### Scenario: A gesture that starts in a mask stays dropped when it ends outside
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** a region marked with the SDK's explicit mask control is on screen
- **WHEN** the user starts a touch inside that region
- **AND** the touch ends outside the region
- **THEN** no interaction is recorded for either end of that gesture

#### Scenario: A masked view removed mid-gesture does not reveal the gesture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** a view marked no-capture is on screen
- **WHEN** the user starts a touch inside that view
- **AND** the view is hidden or removed before the touch ends
- **THEN** no interaction is recorded for that gesture

#### Scenario: A touch ending inside a mask is not recorded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **AND** a view marked no-capture is on screen
- **WHEN** the user starts a touch outside that view
- **AND** the touch ends inside that view
- **THEN** no interaction is recorded for the end of that gesture
