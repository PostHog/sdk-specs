## MODIFIED Requirements

### Requirement: Remote-config JSON wire representation

The SDK SHALL parse a successful JSON response as a top-level project-configuration object, not an event-ingestion envelope or a map of evaluated flag values. It SHALL tolerate unknown fields and optional fields absent from the response. Malformed fields and fetch failures remain subject to this capability's existing error-handling rules.

Common optional wire fields include:

| Field | Representation | Meaning |
| --- | --- | --- |
| `hasFeatureFlags` | boolean | Whether the project has active flags; informs whether to preload flags |
| `sessionRecording` | boolean or object | Session replay configuration |
| `surveys` | boolean or array | Survey availability or definitions |
| `errorTracking` | boolean or object | Error tracking configuration |
| `capturePerformance` | boolean or object | Performance/network timing configuration |
| `supportedCompression` | array of strings | Advertised compression formats |
| `quotaLimited` | array of strings | Billing resources whose ingestion quota the project has exhausted, reported independently (for example `feature_flags`, `recordings`, `mobile_recordings`) |

This is not an exhaustive schema and does not require every SDK to implement every product. Nested replay/survey/error-tracking settings retain their product-specific semantics. Conceptual acceptance settings such as `session_replay_enabled` and `feature_flags_available` SHALL NOT be treated as actual JSON wire field names.

`quotaLimited` is carried on both the project remote-config response and the flags response, so an SDK that acts on a resource SHALL parse the field from whichever of those responses it consumes. Each resource gates only its own product; see the session-replay ingestion-controls spec for the replay resources.

#### Scenario: Parse real wire fields and tolerate extensions
- **GIVEN** the JSON endpoint returns HTTP 200 with `{"hasFeatureFlags":false,"sessionRecording":false,"surveys":false,"futureSetting":{"enabled":true}}`
- **WHEN** the SDK processes the response
- **THEN** it recognizes the supported project settings using their wire names
- **AND** the unknown `futureSetting` field does not prevent applying those settings
- **AND** absent optional fields do not make the response invalid

#### Scenario: Parse quota-limited resources from the project config response
- **GIVEN** the JSON endpoint returns HTTP 200 with `{"sessionRecording":{"endpoint":"/s/"},"quotaLimited":["mobile_recordings"]}`
- **WHEN** the SDK processes the response
- **THEN** it reads `quotaLimited` from the project config response rather than only from the flags response
- **AND** an absent `quotaLimited` field is treated as no quota limiting
