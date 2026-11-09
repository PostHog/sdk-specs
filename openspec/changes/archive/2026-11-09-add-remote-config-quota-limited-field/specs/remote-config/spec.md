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
| `quotaLimited` | array of strings | Billing resources whose quota the project has exhausted; currently `recordings` here and `feature_flags` on the flags response |

`quotaLimited` is absent when no quota is exhausted. The project config response currently lists only `recordings`, and the server sets `sessionRecording` to `false` in the same response, so an SDK does not need a second replay gate from this field. The flags response carries the same field and reports `feature_flags` when the flags quota is exhausted. An SDK that reads the field SHALL ignore values it does not recognize.

This is not an exhaustive schema and does not require every SDK to implement every product. Nested replay/survey/error-tracking settings retain their product-specific semantics. Conceptual acceptance settings such as `session_replay_enabled` and `feature_flags_available` SHALL NOT be treated as actual JSON wire field names.

#### Scenario: Parse real wire fields and tolerate extensions
- **GIVEN** the JSON endpoint returns HTTP 200 with `{"hasFeatureFlags":false,"sessionRecording":false,"surveys":false,"quotaLimited":["recordings","futureResource"],"futureSetting":{"enabled":true}}`
- **WHEN** the SDK processes the response
- **THEN** it recognizes the supported project settings using their wire names
- **AND** the unknown `futureSetting` field does not prevent applying those settings
- **AND** the unknown `futureResource` value in `quotaLimited` is ignored
- **AND** absent optional fields do not make the response invalid
