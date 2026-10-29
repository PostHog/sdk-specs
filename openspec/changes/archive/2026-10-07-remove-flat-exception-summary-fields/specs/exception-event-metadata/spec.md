## MODIFIED Requirements

### Requirement: Producer and processor metadata ownership

SDKs and Cymbal SHALL treat metadata ownership as follows:

| Property | Producer input | Processor behavior |
| --- | --- | --- |
| `$exception_list` | SDK canonical exception data and mechanism tree linkage | validates, preserves linkage, normalizes, and resolves frames |
| `$exception_level` | SDK severity | preserves for querying and downstream use |
| `$exception_source` | SDK concrete capture integration or hook | preserves; does not infer from source files |
| `$debug_images` | SDK native image metadata | validates, consumes for symbolication, and preserves supported fields |
| `$exception_fingerprint` | optional SDK/user override | selects the explicit or automatic fingerprint |
| `$exception_handled` | legacy input only; not authoritative | derives from outermost `mechanism.handled` |
| `$exception_type` | legacy input only; not authoritative | derives from the primary exception's `type` when needed for compatibility |
| `$exception_message` | legacy input only; not authoritative | derives from the primary exception's `value` when needed for compatibility |
| `$exception_types` | none | derives from the exception list |
| `$exception_values` | none | derives from the exception list |
| `$exception_sources` | none | derives from in-app stack-frame source-file paths |
| `$exception_functions` | none | derives from in-app stack-frame functions |
| `$exception_fingerprint_version` | none | derives from automatic grouping |
| `$exception_fingerprint_record` | none | derives from grouping |
| `$exception_issue_id` | none | derives from issue linking |
| `$exception_release` | none | derives from release resolution |
| `$cymbal_errors` | none | derives from processing diagnostics |

First-party SDKs SHALL use the producer fields as their source of truth and SHALL NOT synthesize processor-owned properties. Cymbal MAY accept or overwrite legacy producer values for compatibility, but SDK conformance is measured against the ownership in this table. In particular, `$exception_source` and `$exception_sources` are distinct: the singular property is a capture integration supplied by the SDK, while the plural property is a list of source-code files derived by Cymbal.

#### Scenario: SDK does not confuse capture source with source files (@both)
- **GIVEN** Django middleware captures an exception whose stack contains `app/views.py`
- **WHEN** the SDK enqueues the raw event
- **THEN** `$exception_source` should equal `django.middleware`
- **AND** the SDK should omit `$exception_sources`

#### Scenario: Primary exception summary is derived from the exception list (@both)
- **GIVEN** the primary exception entry has `type` equal to `TypeError` and `value` equal to `boom`
- **WHEN** compatibility metadata is needed for legacy flat fields
- **THEN** `$exception_type` should be derived from the primary exception's `type`
- **AND** `$exception_message` should be derived from the primary exception's `value`
