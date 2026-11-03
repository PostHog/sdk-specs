## ADDED Requirements

### Requirement: Payload reads through the flag result getter

A client SDK MAY omit a dedicated payload getter when its flag result getter (`get-feature-flag-result`) returns the payload and accepts a per-call `sendFeatureFlagEvent` option. posthog-ios 4.0, posthog-android 4.0 and posthog_flutter 6.0 do this. In such an SDK, the scenarios in this spec SHALL hold for a flag result read with `sendFeatureFlagEvent` set to `false`, reading the result's payload: the payload is decoded once, a malformed payload reads as the no-payload value, and the read SHALL NOT send `$feature_flag_called`.

#### Scenario: Silent result read returns the payload without tracking (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key      | value | payload             |
  | checkout | blue  | {"cta":"Try now"}   |
- **WHEN** get feature flag result "checkout" is called with the feature flag event option disabled
- **THEN** the returned payload should include:
  | field | value   |
  | cta   | Try now |
- **AND** no event named "$feature_flag_called" should be enqueued

## Narrative alignment

When syncing this delta, update the iOS, Android and Flutter **Surface variants** in `get-feature-flag-payload`, `get-feature-flags`, `get-feature-flags-and-payloads`, `reload-feature-flags` and `get-feature-flag`, and the Flutter wrapper notes in `feature-flag-cache` and `feature-flag-called-tracker`. No other requirement changes.
