## Narrative alignment

When syncing this delta, name the feature flag properties in the **Server** bullet of Behavior
step 4, so the bullet lists them among the values the SDK adds, and extend the **Feature flags**
entry under Interactions to say the stamped properties fill only keys the caller, the request
context and the SDK-level default properties left unset. Leave the client bullet and the other
sections unchanged.

## ADDED Requirements

### Requirement: Server SDKs add feature flag properties as defaults

On server SDKs, the `$feature/<key>` and `$active_feature_flags` properties a capture call
derives from a flags snapshot or from `send_feature_flags` are values the SDK adds, not values
the caller set. They SHALL fill only the keys left unset by the event's own properties and, where
the SDK has them, by the ambient request context and the SDK-level default/super properties
(`super_properties`, `DefaultEventProperties`, `SuperProperties`, `global_properties`). An SDK
that has no such layer is not required to add one.

`$active_feature_flags` follows the same rule as a single `$feature/<key>`: a value supplied by
any of those layers replaces the SDK's list rather than merging with it.

The SDK SHALL stamp the flag properties before `before_send` runs, so a hook sees the resolved
values and can change or remove them.

#### Scenario: Flag properties land on an event that sets none of them (@server)
- **GIVEN** the SDK resolves flag "beta-ui" to "variant-a" for the captured distinct id
- **WHEN** capture is called with event "Save" and a flags snapshot, or with `send_feature_flags` enabled
- **THEN** the enqueued "Save" event should have property "$feature/beta-ui" equal to "variant-a"
- **AND** it should have "beta-ui" in "$active_feature_flags"

#### Scenario: A property on the call wins over the flag value (@server)
- **GIVEN** the SDK resolves flag "beta-ui" to "variant-a" for the captured distinct id
- **WHEN** capture is called with event "Save", property "$feature/beta-ui" equal to "override", and a flags snapshot, or with `send_feature_flags` enabled
- **THEN** the enqueued "Save" event should have property "$feature/beta-ui" equal to "override"

#### Scenario: A request context value wins over the flag value (@server)
- **GIVEN** the SDK resolves flag "beta-ui" to "variant-a" for the captured distinct id
- **AND** the SDK's ambient request context carries "$feature/beta-ui" equal to "from-context"
- **WHEN** capture is called with event "Save" and a flags snapshot, or with `send_feature_flags` enabled
- **THEN** the enqueued "Save" event should have property "$feature/beta-ui" equal to "from-context"

#### Scenario: An SDK-level default property wins over the flag value (@server)
- **GIVEN** the SDK resolves flag "beta-ui" to "variant-a" for the captured distinct id
- **AND** the SDK's default/super properties carry "$feature/beta-ui" equal to "from-default"
- **WHEN** capture is called with event "Save" and a flags snapshot, or with `send_feature_flags` enabled
- **THEN** the enqueued "Save" event should have property "$feature/beta-ui" equal to "from-default"

#### Scenario: before_send can remove a flag property (@server)
- **GIVEN** the SDK resolves flag "beta-ui" to "variant-a" for the captured distinct id
- **AND** a before_send hook that deletes "$feature/beta-ui" from the event properties
- **WHEN** capture is called with event "Save" and a flags snapshot, or with `send_feature_flags` enabled
- **THEN** the delivered "Save" event should omit "$feature/beta-ui"
