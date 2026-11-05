## Why

Survey eligibility reads several feature flags per survey — the linked flag, the targeting flag,
the internal targeting flag, and the keys in `feature_flag_keys`. The targeting flags are created
by PostHog itself, with keys prefixed `survey-targeting-`, and are not flags the customer reads in
their own code. Emitting `$feature_flag_called` for them inflates event volume and makes flag usage
metrics unusable: in one reported app roughly nine in ten `$feature_flag_called` events came from
survey flags.

The browser SDK has suppressed these events since PostHog/posthog-js#2022 by passing
`send_event: !flagKey.startsWith('survey-targeting-')`. posthog-ios and posthog-android have now
matched that rule. The `surveys` spec says nothing about flag usage events, so the three SDKs agree
on behavior the contract does not state, and the remaining survey-capable SDKs have nothing to
implement against.

## What Changes

- New requirement in `surveys`: when evaluating survey eligibility, the SDK SHALL suppress the
  feature flag usage event (`$feature_flag_called`) for flag keys that start with
  `survey-targeting-`, in every place eligibility reads a flag.
- Flag keys without that prefix — customer-created linked flags and `feature_flag_keys` entries —
  keep the SDK's configured tracking behavior. Matching a prefix anywhere other than the start of
  the key does not suppress anything.
- The separate lookup that reads a linked flag's **variant** stays silent, as it does in all three
  SDKs today.
- Suppression is per read. It does not change the client-level flag event setting, and an SDK whose
  tracking is already disabled globally stays silent regardless.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: adds the **Survey targeting flag reads emit no usage event** requirement.

## Impact

- **posthog-js (browser)**: already conforms (PostHog/posthog-js#2022, addressing
  PostHog/posthog-js#1327).
- **posthog-ios**: conforms as of PostHog/posthog-ios#1021.
- **posthog-android**: conforms as of PostHog/posthog-android#937.
- **posthog-react-native**, **posthog-flutter**, **posthog-kmp**: survey eligibility runs through
  the SDK they wrap, so they conform once their pinned version includes the behavior.
- Server SDKs: not applicable — they do not own a survey display lifecycle.
- Customers see fewer `$feature_flag_called` events after upgrading. Flag usage metrics for
  `survey-targeting-*` keys stop being populated by the SDK; the surveys product does not depend on
  those events.
