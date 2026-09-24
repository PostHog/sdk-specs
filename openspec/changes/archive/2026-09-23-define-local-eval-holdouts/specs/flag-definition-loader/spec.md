## ADDED Requirements

### Requirement: Holdout metadata survives definition loading and caching

The definition loader SHALL preserve `filters.holdout.id` and `filters.holdout.exclusion_percentage` when hydrating local evaluator definitions. Typed models, API projections, and supported definition-cache serialization and deserialization SHALL retain these fields without truncating fractional percentages. Refreshes SHALL replace holdout configuration with the new definition snapshot, including removing a previous holdout when the refreshed definition omits it. This does not require a new cache backend.

#### Scenario: Shared cache retains holdout membership (@server)
- **GIVEN** the definition API returns an active flag with holdout id 727 and exclusion percentage 12.5
- **WHEN** one SDK instance stores those definitions in a configured shared cache and another instance loads them
- **THEN** the loaded flag should retain holdout id 727 and exclusion percentage 12.5
- **AND** both instances should calculate identical holdout membership for the same bucketing identity

#### Scenario: Refresh removes an old holdout (@server)
- **GIVEN** cached definitions contain an active flag with a 100 percent holdout
- **WHEN** a replacement definition snapshot omits that flag's holdout configuration
- **THEN** subsequent local evaluations should use ordinary release conditions rather than the previous holdout
