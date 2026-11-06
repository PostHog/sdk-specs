@public @canonical_behavior @acceptance @offline-evaluations @server
Feature: Offline Evaluations
  Canonical contract: openspec/specs/offline-evaluations/spec.md
  These scenarios require management API harness bindings before integration selection.

  Background:
    Given an isolated SDK instance

  # Requirement: Acknowledged project-bound client

  Scenario: Success is an acknowledgment
    Given an isolated offline evaluation client and a mock service holding an upload response
    When the caller uploads a valid result
    Then the call remains pending until the service returns a valid acknowledgment
    And no analytics flush is required for the upload

  Scenario: Invalid client options do not send requests
    When the caller constructs an offline evaluation client with project ID 0
    Then the caller receives a validation error before any request is sent

  # Requirement: Authenticated app API routing

  Scenario: An ingestion host maps to the management host
    Given an isolated offline evaluation client configured with host "https://eu.i.posthog.com" and a test secret key
    When the caller creates an experiment
    Then the request targets "https://eu.posthog.com" at the configured project's experiment path with bearer authentication

  Scenario: Redirects cannot forward the secret
    Given an isolated offline evaluation client and a mock service returning a redirect to another host
    When the caller performs a management request
    Then the caller receives a structured error and no request is sent to the redirect destination

  # Requirement: Stable experiment creation and local resumption

  Scenario: Creation can be replayed after an uncertain response
    Given an isolated offline evaluation client with automatic retries disabled and a service that persists creation but loses its response
    When the caller retries using the error's prepared submission
    Then the original UUID, start time, and creation fields are reused
    And the receipt identifies the original experiment

  Scenario: Resume does not discover or create a run
    Given an isolated offline evaluation client and an existing experiment UUID
    When the caller resumes that UUID
    Then a handle with that UUID is returned and the service receives no request

  # Requirement: Immutable execution declarations and exact restoration

  Scenario: Saved declarations survive process reconstruction
    Given a locally constructed evaluation item and two results using different scorer versions
    When the caller serializes and restores the declarations, then mutates the saved JSON objects
    Then the restored declarations retain the original identities and payloads
    And both results still reference the same execution item

  # Requirement: Payload omission and JSON fidelity

  Scenario: Missing and null payload values differ
    When the caller constructs items with omitted payload, empty payload, and explicit null output
    Then their serialized declarations respectively omit payload, contain an empty payload object, and contain output null

  Scenario: Invalid payloads fail locally
    Given an isolated offline evaluation client
    When the caller constructs an item with a non-finite number in its payload
    Then the caller receives a validation error and the service receives no upload

  # Requirement: Typed outcomes preserve score meaning

  Scenario: A false score is still a successful evaluator outcome
    Given an isolated offline evaluation client and an accepted item UUID and scorer-version UUID
    When the caller uploads status ok with boolean value false
    Then the received result contains status ok and boolean false with those exact UUIDs
    And no scorer discovery request is sent

  Scenario: A non-ok outcome cannot carry a score
    Given an isolated offline evaluation client
    When the caller constructs an error result with numeric value 0
    Then the caller receives a validation error and the service receives no upload

  Scenario: Numeric score precision cannot be silently lost
    When the caller constructs a numeric result with integer value 9007199254740993
    Then the caller receives a validation error instead of a rounded score

  # Requirement: Upload identity and idempotent acknowledgments

  Scenario: Multiple scorers share one item declaration
    Given an isolated offline evaluation client and two results for one item using different scorer versions
    When the caller uploads both results together
    Then the received request declares the item once and contains both result pairs
    And the receipt acknowledges the one item and both results in order

  Scenario: Exact replay is observable without duplication
    Given an isolated offline evaluation client and an acknowledged item/result upload
    When the caller replays the same declarations in the same experiment
    Then the receipt retains the stored identities and original acceptance times with created false

  Scenario: Missing acknowledgments remain uncertain
    Given an isolated offline evaluation client and an upload of two results
    When the mock service responds successfully but acknowledges only one result
    Then the caller receives an invalid-response error with unknown persistence

  # Requirement: Bounded and independently replayable upload chunks

  Scenario: Count boundaries preserve independently replayable declarations
    Given an isolated offline evaluation client and 1001 valid results for one declared item using distinct scorer versions
    When the caller uploads the sequence
    Then requests preserve result order and each contains at most 1000 results
    And each request includes the shared item declaration

  Scenario: UTF-8 request size includes the envelope
    Given an isolated offline evaluation client and individually valid results whose combined encoded request exceeds 5 MiB
    When the caller uploads the sequence
    Then it is split into ordered requests each no larger than 5 MiB including the JSON envelope

  Scenario: Invalid bulk input sends no partial work
    Given an isolated offline evaluation client and a sequence containing a duplicate item/scorer-version pair
    When the caller uploads the sequence
    Then the caller receives a validation error and the service receives no upload

  # Requirement: Partial bulk failure exposes exact recoverable work

  Scenario: The second chunk fails after the first is acknowledged
    Given an isolated offline evaluation client and an upload requiring three chunks
    When the first chunk is acknowledged and the second fails after exhausting its permitted retries
    Then the bulk error contains the first receipt and pending results for chunks two and three
    And no third-chunk, complete, or fail request is sent
    And retrying the pending results reproduces the failed chunk's original identities and content

  # Requirement: Explicit experiment lifecycle

  Scenario: Count mismatch leaves the experiment open
    Given an isolated offline evaluation client and an experiment expecting two results with only one accepted
    When the caller explicitly completes the experiment
    Then the caller receives a conflict with expected and accepted counts
    And the experiment remains uploading

  Scenario: Failure is explicit and repeatable
    Given an isolated offline evaluation client and a partially uploaded experiment
    When the caller explicitly fails the experiment twice
    Then both receipts identify the same failed experiment and its retained accepted counts

  Scenario: Closed experiments permit exact replay but reject new data
    Given an isolated offline evaluation client and a completed experiment with an accepted result
    When the caller replays that result and then attempts a new result
    Then the replay is acknowledged without duplication and the new result produces a conflict

  # Requirement: Retry only operations with safe identity

  Scenario: Retry preserves the exact upload
    Given an isolated offline evaluation client and a mock service that loses the first upload response
    When the permitted retry succeeds
    Then the retry uses the identical prepared body and experiment identity

  Scenario: A long Retry-After is not shortened
    Given an isolated offline evaluation client with a 30-second retry wait bound
    When the mock service returns HTTP 429 with Retry-After 60
    Then the caller receives the structured error with that delay and no early retry is sent

  # Requirement: Structured failures preserve uncertainty and protect payloads

  Scenario: A rejection after a lost response cannot erase uncertainty
    Given an isolated offline evaluation client whose first upload attempt loses its response
    When the retry returns a definite rejection
    Then the final error retains unknown persistence and the server's structured rejection details

  Scenario: Error messages do not expose evaluation content
    Given an isolated offline evaluation client and a server rejection containing evaluation payload details
    When the caller catches the API error
    Then those details are accessible through structured error fields and absent from its message

  # Requirement: Shared resource tags remain mutable metadata

  Scenario: Experiment tags can change after completion
    Given an isolated offline evaluation client and a completed experiment with its saved creation submission
    When the caller sets tags to " Regression " and "regression"
    Then the returned tag collection is the single normalized name "regression"
    And the saved submission and completed lifecycle state remain unchanged

  # Requirement: Client closure and cancellation do not close experiments

  Scenario: Context exit does not finish an experiment
    Given an isolated offline evaluation client with an uploading experiment
    When the caller exits the client context
    Then the service receives no complete or fail request
    And a subsequent network operation on that closed client fails with persistence not_sent

  Scenario: Cancellation propagates without cleanup writes
    Given an isolated asynchronous offline evaluation client with an upload in flight
    When the caller cancels the operation
    Then native cancellation reaches the caller and no retry, complete, or fail request follows

  # Requirement: Dataset and scorer versions anchor one reproducible run

  Scenario: One pinned dataset execution is scored twice
    Given an isolated evaluation client, a dataset snapshot, and two immutable scorer versions
    When the caller creates an experiment with the snapshot revision UUID, converts one case, and uploads both scorer results
    Then the experiment request contains the snapshot revision UUID
    And the upload declares one execution with the case's exact item-version UUID and two results with the pinned scorer-version UUIDs
    And the item's introducing revision does not replace the snapshot revision

  Scenario: An item outside the pinned dataset revision is rejected
    Given an isolated evaluation client and an experiment linked to dataset revision 3
    When the caller uploads a new item linked to a version introduced only in revision 4
    Then the caller receives the backend's structured validation error and the upload commits no new items or results

  # Requirement: Per-item model attribution with experiment fallback

  Scenario: One experiment contains executions from different models
    Given an isolated offline evaluation client and an experiment with model_version "model-a"
    And two evaluation items declaring model_version "model-b" and "model-c"
    When the caller uploads results for both items in one request
    Then each received item declaration contains its respective model_version beside its UUID
    And results reference those item UUIDs and scorer versions without a model field
    And no request changes the experiment's model_version

  Scenario: Omitted and null item models inherit the experiment default
    Given an isolated offline evaluation client and an experiment with model_version "model-a"
    When the caller uploads one item with an omitted model and another with model_version null
    Then neither received declaration contains a non-null item model
    And the experiment creation request retains model_version "model-a" as the default

  Scenario: An experiment can have no default model
    Given an isolated offline evaluation client and an experiment without a model_version
    When the caller uploads an item declaring "model-b" and another without a model
    Then the received first item declares model_version "model-b" and the second contains no non-null model
    And the experiment creation request contains no non-null model

  Scenario: Invalid item model identifiers fail locally
    When the caller constructs an evaluation item with an empty string, a non-string non-null value, or a string longer than 255 characters as model_version
    Then the caller receives a validation error before any upload is sent

  Scenario: Valid model identifiers retain their exact text
    Given evaluation items with a 255-character model identifier and a model identifier containing leading and trailing spaces
    When the caller serializes and uploads the items
    Then the received model identifiers exactly match the supplied strings

  Scenario: A resumed handle needs no experiment model lookup
    Given an isolated offline evaluation client and a locally resumed experiment handle
    When the caller uploads one item with an explicit model and another without one
    Then the request retains the explicit model and leaves the other model unset
    And no experiment or model read precedes the upload

  # Requirement: Model attribution survives declaration replay and recovery

  Scenario: Saved item models survive reconstruction and detached mutation
    Given an evaluation item with model_version "model-b" and two results using different scorer versions
    When the caller serializes and restores the declarations, then changes model_version in the saved item dictionary
    Then the original and restored items retain "model-b" and their original execution UUID
    And both restored results still reference that execution item

  Scenario: Legacy saved declarations retain replay compatibility
    Given an accepted item whose saved declaration has no model_version key and whose experiment has model_version "model-a"
    When the caller restores and replays that declaration with the same result
    Then the upload does not insert a non-null item model
    And the acknowledgment retains the original identities and acceptance times with created false

  Scenario: Explicit item models replay without duplication
    Given an acknowledged item and result with item model_version "model-b"
    When the caller replays the same item and result in the same experiment
    Then the received declaration still contains "model-b"
    And the acknowledgment retains the original identities and acceptance times with created false

  Scenario: Changing an accepted item's model is a content conflict
    Given an acknowledged item with model_version "model-b"
    When the caller redeclares the same item UUID with model_version "model-c" or without its explicit model
    Then the backend rejects the changed declaration and the caller receives a structured content_conflict error

  Scenario: An explicit default is not an inherited declaration
    Given an acknowledged item with no explicit model in an experiment with model_version "model-a"
    When the caller redeclares the same item UUID with explicit model_version "model-a"
    Then the caller receives a structured content_conflict error despite the equal effective model

  Scenario: Conflicting models in one bulk call send no partial work
    Given two results with distinct scorer versions whose attached declarations use the same item UUID but models "model-b" and "model-c"
    When the caller uploads both results as one bulk operation
    Then the caller receives a local validation error and the service receives no upload

  Scenario: Repeated chunk declarations retain the model through recovery
    Given 1001 results for one item declaring model_version "model-b" with distinct scorer versions
    And the service acknowledges the first chunk but loses the second chunk's response
    When the caller receives the bulk error and retries its pending results
    Then every chunk declaring the item includes "model-b"
    And failed_chunk retains that model and the retry reproduces the failed chunk's identities and content

  Scenario: Another scorer can reference an accepted item without its model
    Given an accepted evaluation item with model_version "model-b"
    When the caller uploads another scorer's result using only that item's UUID
    Then the result references the accepted item without redeclaring or looking up its model
