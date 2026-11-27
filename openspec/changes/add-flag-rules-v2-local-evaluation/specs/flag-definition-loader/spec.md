## ADDED Requirements

### Requirement: Shared definition caches keep config version 1 entries in `flags`

An SDK that requests the version 2 definitions feed (`flag-rules-v2-local-evaluation`) SHALL write only config version 1 entries, those whose `filters.version` is absent or `1`, to the `flags` field of the data it hands to an external flag definition cache provider or another supported definition store. It SHALL write every other entry of the feed, in feed order, to a separate field named `flags_v2`, and SHALL omit `flags_v2` when there is no such entry. The other fields of the cached data do not change.

When it reads cached data, such an SDK SHALL load the entries of both fields and choose each entry's evaluator by that entry's own `filters.version`, as "The config version selects the evaluator" in `local-feature-flag-evaluator` defines, whichever field holds it. Cached data without `flags_v2` loads as a snapshot without config version 2 flags: those keys have no local definition, so a single read fetches them remotely, as it does any key without a local definition.

An SDK that does not request the version 2 feed reads only `flags`. It therefore never receives a config version 2 document from data that a newer SDK wrote, and a provider that drops fields it does not know loses only the config version 2 flags.

Why: several SDK releases can share one cache. An SDK without a config version 2 evaluator that found a config version 2 document in `flags` would return `false` for that flag as a local result, with no fallback.

#### Scenario: The writer keeps config version 2 entries out of flags (@server)
- **GIVEN** an SDK with `flag-rules-v2-local-evaluation` fetched a version 2 feed with the config version 1 flag "legacy-banner", the config version 2 flag "layout-preview" and the config version 3 flag "future-config-version"
- **WHEN** it hands the definitions to its external flag definition cache provider
- **THEN** the cached `flags` field holds only "legacy-banner"
- **AND** the cached `flags_v2` field holds "layout-preview" and "future-config-version", in that order
- **AND** `group_type_mapping`, `cohorts`, `minimal_flag_called_events` and `property_matching_version` are cached as before

#### Scenario: An older reader of the shared cache sees only config version 1 flags (@server)
- **GIVEN** cached data with "legacy-banner" in `flags` and "layout-preview" in `flags_v2`
- **WHEN** an SDK without `flag-rules-v2-local-evaluation` reads it with the fetch-decision operation returning false
- **THEN** it loads "legacy-banner" and has no local definition for "layout-preview"
- **AND** a single read of "layout-preview" fetches it remotely and does not return `false` as a local result

#### Scenario: A newer reader loads both fields (@server)
- **GIVEN** cached data with "legacy-banner" in `flags` and "layout-preview" in `flags_v2`
- **WHEN** an SDK with `flag-rules-v2-local-evaluation` reads it with the fetch-decision operation returning false
- **THEN** it evaluates "legacy-banner" with the config version 1 rules and "layout-preview" with the config version 2 evaluator
- **AND** no direct flag definition API request is sent

#### Scenario: Cached data without flags_v2 has no config version 2 flags (@server)
- **GIVEN** cached data that an older SDK wrote, with "legacy-banner" in `flags` and no `flags_v2`
- **WHEN** an SDK with `flag-rules-v2-local-evaluation` reads it
- **THEN** it loads "legacy-banner"
- **AND** a single read of "layout-preview" fetches it remotely
