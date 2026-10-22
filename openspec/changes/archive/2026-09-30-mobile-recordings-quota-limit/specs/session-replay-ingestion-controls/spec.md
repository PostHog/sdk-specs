## Narrative alignment

When syncing this delta, extend Behavior item 1 ("Resolve replay enablement") so the quota check is part of resolving enablement, add the quota case to Error handling, and note the `quotaLimited` field on the remote-config interaction. Do not renumber the remaining Behavior items or change any other control.

## ADDED Requirements

### Requirement: Mobile recording quota limiting

A remote-config or flags response MAY carry a top-level `quotaLimited` array naming the billing resources whose ingestion quota the project has exhausted. The resources are reported independently: `recordings` for web session replay, `mobile_recordings` for mobile session replay, and `feature_flags` for flag evaluation. A replay-capable SDK SHALL read `quotaLimited` from the project remote-config response as well as the flags response, because either may carry it.

An SDK whose replay capture produces mobile-source recordings — the native mobile SDKs and the native replay layer that `posthog-react-native` and `posthog-flutter` embed — SHALL treat `mobile_recordings` in `quotaLimited` as replay disabled for the enablement gate, exactly as a falsy `sessionRecording`, even when the response's `sessionRecording` resolves to active. The server deliberately keeps `sessionRecording` active in this case, because web recording on the same project is still allowed; the SDK, not the server, is responsible for stopping the mobile capture path. The SDK SHALL also evict its cached recording configuration, so a cold start before the next response does not re-enable replay from cache, and SHOULD log that replay stopped because of the quota.

The condition SHALL NOT be sticky beyond the responses that report it: when a later remote-config or flags response does not name `mobile_recordings`, the SDK SHALL resolve enablement from that response as usual. An absent `quotaLimited` field SHALL mean no quota limiting, so a server that never sends the field leaves replay enablement unchanged.

Because the resources are independent, `recordings` alone SHALL NOT disable mobile replay, and `mobile_recordings` alone SHALL NOT disable web replay or change feature-flag handling. Quota limiting is evaluated as part of the enablement gate, so a quota-limited session records nothing regardless of linked flag, sampling, or triggers.

#### Scenario: Mobile recordings quota disables replay despite an active recording config
- **GIVEN** a mobile-source replay SDK with session replay configured locally
- **AND** the response reports session recording as active with no linked flag, sampling, or triggers
- **AND** the same response reports `quotaLimited` containing `mobile_recordings`
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should not be active

#### Scenario: A quota-limited response evicts the cached recording config
- **GIVEN** a mobile-source replay SDK that has cached an active recording config
- **WHEN** it processes a response reporting `quotaLimited` containing `mobile_recordings`
- **THEN** the cached recording config is removed
- **AND** a restart that resolves enablement from cache before the next response does not record

#### Scenario: A later response without the resource restores normal enablement
- **GIVEN** a mobile-source replay SDK whose replay was disabled by `mobile_recordings` quota limiting
- **WHEN** it processes a later response that reports session recording as active and does not name `mobile_recordings`
- **THEN** session recording should be active

#### Scenario: An absent quota field leaves enablement unchanged
- **GIVEN** a mobile-source replay SDK talking to a server that never sends `quotaLimited`
- **AND** the response reports session recording as active with no other controls
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active

#### Scenario: A web recordings limit does not disable mobile replay
- **GIVEN** a mobile-source replay SDK with session replay configured locally
- **AND** the response reports session recording as active and `quotaLimited` containing `recordings` but not `mobile_recordings`
- **WHEN** the SDK resolves whether to record the current session
- **THEN** session recording should be active
