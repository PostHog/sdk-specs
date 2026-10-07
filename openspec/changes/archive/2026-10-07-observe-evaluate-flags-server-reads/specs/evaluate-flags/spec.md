## ADDED Requirements

### Requirement: Observable remote snapshot reads and exposure delivery

A server SDK SHALL allow remote evaluation and public snapshot access to be observed through caller-visible getter results, feature-flag evaluation requests, and events delivered to the configured ingestion service. Reading multiple flags from one returned snapshot SHALL preserve the existing projection and lazy-tracking contracts and SHALL NOT perform additional evaluation requests. Explicit public flush SHALL make resulting exposure delivery observable.

Public results SHALL be compared by their canonical semantics using the SDK's documented public methods or fields. Scalar value accessors and rich result objects SHALL preserve the same enabled/boolean/variant distinctions without requiring identical language-specific member names. Payload reads SHALL preserve the documented decoded or serialized JSON representation, including JSON-looking string payloads. Key enumeration SHALL remain silent and SHALL NOT initiate evaluation. Explicit-key filtering SHALL invoke the existing in-memory filtering contract: retain only requested keys present in the source snapshot, drop unknown keys with the documented diagnostic where logging is available, preserve the original snapshot, and add neither evaluation requests nor exposure by itself. Accessed-key filtering SHALL retain only present flags accessed through value/enablement reads, including disabled flags, and SHALL remain empty before such reads. Payload reads, key enumeration, and filtering SHALL NOT count as value access; child access bookkeeping SHALL NOT mutate the parent's selection. Where a public enablement accessor supports caller defaults, those defaults SHALL apply only to a missing flag and SHALL NOT override a present value or replace the canonical tracking response. Missing identity, a publicly disabled SDK, and a failed remote evaluation with no locally resolved flags SHALL preserve safe empty snapshot access under the existing safe-empty and tracking contracts.

#### Scenario: Remote snapshot reads share one evaluation and deduplicate exposure (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** the SDK is initialized with a flush threshold larger than the exposure count
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true and "checkout" as variant "control"
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the returned snapshot's enablement and value accessors are called for "beta-ui"
- **AND** its value, enablement, and value accessors are called in order for "checkout"
- **THEN** the five caller-visible semantic results are true, true, "control", true, and "control", in that order
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** exactly two delivered events are named "$feature_flag_called" and carry distinct id "snapshot-user"
- **AND** exactly one exposure identifies "beta-ui" with canonical response true
- **AND** exactly one exposure identifies "checkout" with canonical response "control"

#### Scenario: Remote snapshot projections distinguish disabled variant and missing flags (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** the SDK is initialized with a flush threshold larger than the exposure count
- **AND** remote evaluation for distinct id "snapshot-user" returns "disabled" as false and "checkout" as variant "control", and omits "missing"
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the returned snapshot's enablement and value accessors are called for "disabled", "checkout", and "missing"
- **THEN** "disabled" returns false for both projections
- **AND** "checkout" returns true enablement and value "control"
- **AND** "missing" returns false enablement and the platform's native nullish missing value
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** exactly three delivered events are named "$feature_flag_called" and carry distinct id "snapshot-user"
- **AND** exactly one exposure identifies "disabled" with canonical response false
- **AND** exactly one exposure identifies "checkout" with canonical response "control"
- **AND** exactly one exposure identifies "missing" with metadata indicating flag_missing
- **AND** the missing-key response follows the platform's documented sentinel

#### Scenario: Remote evaluation without snapshot reads delivers no exposure (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "checkout" as variant "control"
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** no snapshot accessor is called
- **AND** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Remote snapshot payload reads are silent and retain JSON semantics (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "checkout" as variant "control" with payload {"copy":"new","enabled":false,"attempt":0,"context":{"codes":[1,2],"success":false}}
- **AND** it returns "no-payload" as true without a payload, and omits "missing"
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the returned snapshot's payload accessor is called twice for "checkout", once for "no-payload", and once for "missing"
- **THEN** both "checkout" reads return that payload in the platform's documented valid JSON representation
- **AND** the false, zero, nested object, and array values retain their JSON semantics
- **AND** the "no-payload" and "missing" reads return the platform's documented empty payload result
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario Outline: Remote scalar payload reads preserve type and decoding boundaries (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "checkout" with payload represented by JSON <payload>
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the returned snapshot's payload accessor is called for "checkout"
- **THEN** the public payload represents JSON <payload> using the platform's documented representation
- **AND** the payload is not coerced by truthiness or decoded beyond that representation
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** no delivered event is named "$feature_flag_called"

**Examples:**
| payload |
| false |
| 0 |
| null |
| "hello" |
| "{\"copy\":\"new\"}" |

#### Scenario: Independent compound requests evaluate their own identity and group context (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct ids "snapshot-user-a" and "snapshot-user-b" returns "checkout" as variant "control"
- **WHEN** the public evaluation method is called for "snapshot-user-a" with group {"organization":"org-a"}
- **AND** "checkout" is read through the returned snapshot's value accessor
- **AND** the public evaluation method is called for "snapshot-user-b" with group {"organization":"org-b"}
- **AND** "checkout" is read through that request's snapshot value accessor
- **THEN** both results expose "control" from their respective evaluations
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly two remote evaluation requests have been received, one for each supplied identity and group context
- **AND** exactly two delivered "$feature_flag_called" events identify "checkout" with canonical response "control"
- **AND** one exposure retains "snapshot-user-a" and group {"organization":"org-a"}
- **AND** the other exposure retains "snapshot-user-b" and group {"organization":"org-b"}

#### Scenario: Compound evaluation forwards explicit context into remote requests and exposure (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true
- **WHEN** the public evaluation method is called with that identity, group {"organization":"acme"}, person properties {"plan":"free","retryable":false,"attempt":0,"context":{"codes":[1,2]}}, group properties {"organization":{"tier":"team","active":false}}, remote fallback enabled, and GeoIP disabled
- **AND** the returned snapshot's value accessor is called for "beta-ui"
- **THEN** the caller-visible semantic value is true
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received with the supplied identity and group context
- **AND** the provided person/group property values and GeoIP choice are preserved in that request
- **AND** SDK-added contextual properties do not overwrite supplied values
- **AND** exactly one delivered "$feature_flag_called" event identifies "beta-ui" with canonical response true, distinct id "snapshot-user", and group {"organization":"acme"}

#### Scenario: Request-time key scope and public enumeration preserve silent reads (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation can return "beta-ui", "checkout", and "search"
- **AND** "checkout" has payload {"copy":"new"}
- **WHEN** the public evaluation method is called for "snapshot-user" with requested keys ["beta-ui","checkout"] and remote fallback enabled
- **AND** the returned snapshot's public keys are enumerated
- **AND** its payload accessor is called for "checkout"
- **THEN** the enumerated key set is exactly "beta-ui" and "checkout", with ordering unspecified
- **AND** the payload represents JSON {"copy":"new"} using the platform's documented representation
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received with exactly the requested key scope
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Explicit empty request-time keys produce no remote traffic or exposure (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation could return "checkout" as variant "control"
- **WHEN** the public evaluation method is called for "snapshot-user" with an explicitly empty requested key list
- **AND** the returned snapshot's public keys are enumerated
- **THEN** the caller observes an empty key set
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** no remote feature-flag evaluation request has been received
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Explicit-key filters preserve the original snapshot and remain silent (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true, "checkout" as variant "control" with payload {"copy":"new"}, and "search" as false
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the returned snapshot's original keys and "checkout" payload are read through public accessors
- **AND** its public explicit-key filter is called with ["checkout","checkout","missing"]
- **AND** the filtered snapshot's keys and "checkout" payload are read through public accessors
- **AND** the original snapshot's public explicit-key filter is called with an empty key list and that child's keys are enumerated
- **AND** the original snapshot's keys and "checkout" payload are read again
- **THEN** the original key set is "beta-ui", "checkout", and "search" before and after filtering, with ordering unspecified
- **AND** the first filtered key set contains "checkout" exactly once and omits "missing"
- **AND** the empty filter's key set is empty
- **AND** every "checkout" payload read represents JSON {"copy":"new"} using the platform's documented representation
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Filtered value reads retain decisions and share normal exposure dedupe (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true and "checkout" as variant "control" with payload {"copy":"new"}
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** its public explicit-key filter is called with ["checkout"]
- **AND** the filtered snapshot's keys, "checkout" enablement, value, and payload are read
- **AND** the original snapshot's values for "checkout" and "beta-ui" and its keys are read
- **THEN** the filtered key set is exactly "checkout"
- **AND** the filtered enablement is true and its canonical value is "control"
- **AND** its payload represents JSON {"copy":"new"} using the platform's documented representation
- **AND** the original canonical values remain "control" and true, and its key set remains "beta-ui" and "checkout"
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** exactly two delivered "$feature_flag_called" events carry distinct id "snapshot-user"
- **AND** exactly one exposure identifies "checkout" with canonical response "control"
- **AND** exactly one exposure identifies "beta-ui" with canonical response true

#### Scenario: Accessed-key filtering before value use is empty and silent (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true and "checkout" as variant "control" with payload {"copy":"new"}
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** its accessed-key filter is called before any read and that child's keys are enumerated
- **AND** the original snapshot's "checkout" payload and keys are read through public accessors
- **AND** the original snapshot's accessed-key filter is called again and that child's keys are enumerated
- **THEN** both accessed-filter key sets are empty
- **AND** the original snapshot still contains "beta-ui" and "checkout"
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Accessed-key filtering selects used flags without child-to-parent leakage (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true, "search" as false, and "checkout" as variant "control" with payload {"copy":"new"}, and omits "missing"
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the original snapshot's "checkout" payload and keys are read
- **AND** its enablement accessor is called for "beta-ui" and its value accessor is called for "search" and "missing"
- **AND** its accessed-key filter is called and the filtered keys are enumerated
- **AND** a separate public explicit-key child containing "checkout" is created from the original snapshot
- **AND** that child's value accessor is called for "checkout"
- **AND** that child's accessed-key filter is called and its filtered keys are enumerated
- **AND** the original snapshot's accessed-key filter is called again and its filtered keys are enumerated
- **THEN** the parent's accessed-filter key set is exactly "beta-ui" and "search" before and after the child read
- **AND** the child's accessed-filter key set is exactly "checkout"
- **AND** payload-only "checkout" is not selected on the parent, and unknown "missing" is not selected in any accessed-filter result
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** exactly four delivered "$feature_flag_called" events carry distinct id "snapshot-user"
- **AND** one exposure identifies "beta-ui" with canonical response true, one identifies "search" with response false, and one identifies "checkout" with response "control"
- **AND** one exposure identifies "missing" with metadata indicating flag_missing and the platform's documented missing response sentinel

#### Scenario: Supported caller defaults affect only missing enablement (@server @snapshot_default_capable)
- **GIVEN** a fresh isolated server SDK and mock ingestion service whose public snapshot enablement accessor supports caller defaults
- **AND** remote evaluation for distinct id "snapshot-user" returns "beta-ui" as true, "disabled" as false, and "checkout" as variant "control", and omits "missing"
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** "missing" enablement is read with the default omitted, explicitly false, and explicitly true
- **AND** "disabled" enablement is read with default true
- **AND** "beta-ui" and "checkout" enablement are read with default false
- **AND** the snapshot's value accessor is called for "missing"
- **THEN** the missing enablement results are false, false, and true in that order
- **AND** disabled enablement remains false and the enabled boolean/variant results remain true
- **AND** the missing value result remains the platform's native nullish sentinel
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user"
- **AND** exactly four delivered "$feature_flag_called" events identify that caller, one per accessed key
- **AND** the present flag exposures use canonical responses true, false, and "control"
- **AND** the missing-key exposure indicates flag_missing and uses the canonical missing response sentinel rather than the caller's true default

#### Scenario: Missing evaluation identity returns safe empty results without traffic (@server)
- **GIVEN** a fresh isolated server SDK and mock ingestion service with no request-context identity
- **WHEN** the public evaluation method is called without a distinct id
- **AND** the returned snapshot's keys, "checkout" enablement, value, and payload are read
- **AND** its explicit-key filter for ["checkout"] and accessed-key filter are called and their keys are enumerated
- **THEN** all observed key sets are empty
- **AND** enablement is false and value/payload use the platform's documented missing results
- **AND** no public evaluation, getter, or filter throws or rejects to the caller
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** no remote feature-flag evaluation request has been received
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Disabled SDK evaluation returns safe empty results without traffic (@server)
- **GIVEN** a fresh isolated server SDK publicly configured as disabled and a mock ingestion service
- **WHEN** the public evaluation method is called for "snapshot-user"
- **AND** the returned snapshot's keys, "checkout" enablement, value, and payload are read
- **AND** its explicit-key filter for ["checkout"] and accessed-key filter are called and their keys are enumerated
- **THEN** all observed key sets are empty
- **AND** enablement is false and value/payload use the platform's documented missing results
- **AND** no public evaluation, getter, or filter throws or rejects to the caller
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** no remote feature-flag evaluation request has been received
- **AND** no delivered event is named "$feature_flag_called"

#### Scenario: Failed remote evaluation retains safe reads without accessor retries (@server)
- **GIVEN** a fresh isolated server SDK with no loaded local definitions or evaluated results and a mock ingestion service
- **AND** feature-flag request retries are disabled through public SDK configuration
- **AND** the remote feature-flag evaluation service responds with HTTP 503
- **WHEN** the public evaluation method is called for "snapshot-user" with remote fallback enabled
- **AND** the returned snapshot's keys, "checkout" enablement, value, and payload are read
- **AND** its explicit-key filter for ["checkout"] and accessed-key filter are called and their keys are enumerated
- **THEN** all observed key sets are empty
- **AND** enablement is false and value/payload use the platform's documented missing results
- **AND** the SDK does not throw or reject to the caller; an idiomatic error returned alongside the safe snapshot remains permitted where documented
- **WHEN** the SDK is explicitly flushed through its public method
- **THEN** exactly one remote evaluation request has been received for "snapshot-user" and the mock served the HTTP 503 response
- **AND** the getters and filters made no additional evaluation request
- **AND** exactly one delivered "$feature_flag_called" event identifies "checkout" for "snapshot-user", carries flag_missing metadata, and uses the documented missing response sentinel
