## ADDED Requirements

### Requirement: Remote-config replies outliving their setup

A remote-config reply SHALL be applied to local state and announced to integrations and listeners only while the setup that issued its request is still the live one.

When the SDK instance has been shut down, a reply that lands after shutdown SHALL NOT be applied and SHALL NOT invoke any integration or listener callback. When an SDK allows setup again on the same instance after shutdown, a reply issued by an earlier setup SHALL NOT be applied to, or announced to, a later setup's configuration and integrations. The SDK SHALL match a reply to its issuing setup by identity — both the configuration and the remote-config loader the request was made with — rather than by the instance being enabled again, because a host MAY reuse the same configuration object across shutdown and setup.

Discarding such a reply SHALL be silent: it is not a fetch failure, SHALL NOT be reported through the capability's error handling, and SHALL NOT prevent the live setup's own reply from being applied. Whether the in-flight request is cancelled or allowed to complete and then ignored is an implementation choice.

#### Scenario: Reply landing after shutdown is discarded
- **GIVEN** an SDK instance with a remote-config request in flight
- **WHEN** the instance is shut down
- **AND** the remote-config reply lands afterwards
- **THEN** no integration or listener should be notified of remote config
- **AND** no feature should be re-armed on the shut-down instance
- **AND** the SDK should report no remote-config error

#### Scenario: Reply from a previous setup is discarded after setup again
- **GIVEN** an SDK instance that was set up, issued a remote-config request, and was shut down
- **AND** the same instance is set up again, reusing the same configuration object
- **WHEN** the first setup's reply lands
- **THEN** the second setup's integrations and listeners should not be notified of that reply
- **AND** the second setup's own remote-config reply should still be applied and announced
