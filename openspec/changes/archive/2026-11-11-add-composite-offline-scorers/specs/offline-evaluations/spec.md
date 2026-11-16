## ADDED Requirements

### Requirement: Explicit composite calculation declarations
The SDK SHALL support calculate=true on result declarations and both single and
bulk upload surfaces. A calculation SHALL serialize only item_id, scorer_version_id,
and calculate=true, with no caller-supplied score, non-default status, payload,
error code, evaluator trace, or evaluation time. Omitted/default null optional
arguments MAY be accepted but SHALL NOT be serialized. The ordinary status/value
contract remains unchanged for reported results. Omitted or false calculate
SHALL be omitted on ordinary uploads for compatibility with older backends.

Declarations SHALL snapshot and restore calculation requests through to_dict
and from_dict with stable item/scorer-version identities. Upload SHALL NOT
discover scorer definitions or evaluate formulas. The backend requires calculation
requests for composites and reported values for reported scorers. New calculations
require an uploading experiment; exact retries return stored outcomes, including
after completion, subject to current composite/input access.

#### Scenario: A saved calculation is restored
- **GIVEN** a calculation declaration attached to a reusable evaluation item
- **WHEN** the caller serializes and restores the declaration
- **THEN** the item and scorer-version UUIDs and calculate=true are unchanged
- **AND** the declaration contains no value or result metadata

#### Scenario: A calculation rejects a supplied score
- **WHEN** the caller requests calculate=true with value false
- **THEN** validation fails before any upload

#### Scenario: Ordinary requests retain legacy wire fields
- **WHEN** the caller uploads a reported result with calculate omitted or false
- **THEN** the request omits calculate and retains its ordinary status and value

### Requirement: Composite dependencies remain in one upload request
Ingestion-only uploads MUST supply each composite and every pinned reported input
for that item in the same HTTP request, including exact retries.
Previously stored inputs MAY be resubmitted with their original content.
Using stored inputs without resubmission requires both evaluation:read and
llm_analytics:read in addition to offline_evaluation_ingestion:write.
Project secret keys cannot use stored inputs without resubmission.
Current access to the composite and every pinned input is required even on retries.
Missing inputs reject the whole HTTP request; input ordering within it is arbitrary.

Bulk chunking SHALL preserve caller order and keep all supplied results for each
composite-bearing item in one request. Overlapping first-to-last item spans SHALL
be kept together, including intervening results. Ordinary-only submissions retain
the existing independent chunking behavior. Limits remain 1,000 declared items,
1,000 results, and 5 MiB encoded JSON per request. An indivisible group exceeding
a limit SHALL reject the complete bulk call before I/O. Available item declarations
SHALL be included in each request that references them. The SDK SHALL NOT fetch
dependencies to perform grouping or infer credential permissions.

Bulk errors SHALL retain completed receipts, the failed group's first original
index, all pending results, and the exact failed request. Replaying pending work
SHALL preserve the failed request's identities, content, and ordering.

#### Scenario: A count boundary cannot separate a composite from its inputs
- **GIVEN** 999 independent results followed by an input and its calculation for one item
- **WHEN** the caller uploads the sequence
- **THEN** the service receives requests containing 999 results and 2 results
- **AND** receipt order matches caller order

#### Scenario: Interleaved dependencies form one group
- **GIVEN** reported A, calculated B, calculated A, and reported B in that order
- **WHEN** the caller uploads these results
- **THEN** all four results are sent together in their original order

#### Scenario: Oversized groups send no partial work
- **GIVEN** valid early results followed by a composite group larger than a request limit
- **WHEN** the caller uploads the sequence
- **THEN** validation fails before any request is sent

#### Scenario: A failed group can be replayed exactly
- **GIVEN** an acknowledged first chunk and a composite group whose response was lost
- **WHEN** the caller retries the bulk error's pending results
- **THEN** the failed group's request is reproduced exactly with the original result index retained in the error
- **AND** no complete or fail operation is sent automatically

### Requirement: Calculated outcomes are visible in upload receipts
Result receipts SHALL expose the stored status and nullable error_code on initial
uploads and exact retries. HTTP success SHALL NOT imply a successful calculation.
Missing outcomes on composite acknowledgments SHALL produce invalid-response
errors with unknown persistence and retain recoverable pending work.
Older reported acknowledgments without outcome fields SHALL remain accepted;
Python represents the missing status as None rather than inventing an outcome.
Malformed status/error-code fields SHALL not be accepted as successful receipts.

The server propagates input statuses in the order error, skipped, not_applicable;
input errors use composite_input_error. Formula failures or output values outside
the configured rules use composite_formula_error. Valid reported inputs in such
an accepted request remain saved. Missing inputs instead reject the atomic upload.
All accepted composite outcomes count toward expected_result_count, while derived
results add no uploaded-result billing usage. Omitting a composite means not
requested. Formulas and stored results never recalculate on read or exact retry.
Experiment-level formulas and result inspection APIs remain outside this SDK capability.

#### Scenario: A formula failure is an acknowledged outcome
- **WHEN** the service accepts an upload with composite status error and code composite_formula_error
- **THEN** the receipt exposes that error status and code without requiring a result-read request

#### Scenario: A composite acknowledgment cannot omit the outcome
- **WHEN** the service acknowledges a calculation without status or error_code fields
- **THEN** the SDK reports invalid_response with unknown persistence

#### Scenario: Derived outcomes count toward completion
- **GIVEN** two reported inputs and one accepted composite error for an item
- **WHEN** the experiment is completed with expected_result_count 3
- **THEN** the composite error counts toward completion
- **AND** only the newly accepted reported inputs contribute billing usage
