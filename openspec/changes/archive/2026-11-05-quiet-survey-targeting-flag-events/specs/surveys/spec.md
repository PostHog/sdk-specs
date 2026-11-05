## ADDED Requirements

### Requirement: Survey targeting flag reads emit no usage event

When the SDK reads a feature flag to decide whether a survey is eligible, and the flag key starts
with `survey-targeting-`, the SDK SHALL suppress the feature flag usage event
(`$feature_flag_called`) for that read. This applies to every eligibility read of such a key,
whichever field of the survey definition carried it — the linked flag, the targeting flag, the
internal targeting flag, or an entry in `feature_flag_keys`.

Keys prefixed `survey-targeting-` are created by PostHog for survey targeting rather than by the
customer, so their usage events inflate event volume and flag usage metrics without telling the
customer anything they asked to measure.

The SDK SHALL match the prefix at the start of the key only. A key that contains
`survey-targeting-` elsewhere is an ordinary key.

For an eligibility read of any other key — a customer-created linked flag, or a
`feature_flag_keys` entry — the SDK SHALL keep its configured flag event behavior, so the read
emits a usage event wherever an ordinary `isFeatureEnabled` read would. Suppression is per read:
it SHALL NOT change the client-level flag event setting, and an SDK whose flag events are
disabled globally stays silent for every key regardless of prefix.

The separate read that resolves a linked flag's **variant** SHALL emit no usage event, for any
key.

This requirement applies to SDKs that own a survey display lifecycle. Wrapper SDKs whose survey
eligibility runs inside the SDK they wrap conform through that SDK.

#### Scenario: A targeting flag read emits no usage event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** feature flag events are enabled
- **AND** cached surveys include an active survey "survey-1" gated by the targeting flag "survey-targeting-abc123"
- **WHEN** survey eligibility is evaluated
- **THEN** no event named "$feature_flag_called" should be enqueued for flag "survey-targeting-abc123"

#### Scenario: An ordinary linked flag read still emits a usage event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** feature flag events are enabled
- **AND** cached surveys include an active survey "survey-1" gated by the linked flag "beta-program"
- **WHEN** survey eligibility is evaluated
- **THEN** one event named "$feature_flag_called" should be enqueued for flag "beta-program"

#### Scenario: The prefix only matches at the start of the key
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** feature flag events are enabled
- **AND** cached surveys include an active survey "survey-1" gated by the linked flag "legacy-survey-targeting-abc123"
- **WHEN** survey eligibility is evaluated
- **THEN** one event named "$feature_flag_called" should be enqueued for flag "legacy-survey-targeting-abc123"

#### Scenario: A linked flag variant lookup emits no usage event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** feature flag events are enabled
- **AND** cached surveys include an active survey "survey-1" gated by the linked flag "beta-program" matching variant "test"
- **WHEN** survey eligibility is evaluated
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-program"

#### Scenario: Globally disabled flag events stay disabled for ordinary keys
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** feature flag events are disabled
- **AND** cached surveys include an active survey "survey-1" gated by the linked flag "beta-program"
- **WHEN** survey eligibility is evaluated
- **THEN** no event named "$feature_flag_called" should be enqueued for flag "beta-program"
