@public @canonical_behavior @acceptance @ai-datasets @server
Feature: AI Datasets
  Canonical contract: openspec/specs/ai-datasets/spec.md
  These scenarios require management API harness bindings before integration selection.

  Background:
    Given an isolated SDK instance

  # Requirement: Dataset management surface and metadata

  Scenario: Metadata changes preserve revision state
    Given an isolated dataset client and a dataset with a description, metadata, and no items
    When the caller updates only metadata to an empty object
    Then the returned metadata is empty and the description is unchanged
    And both current revision fields remain null

  Scenario: Duplicate dataset names surface the server rejection
    Given an isolated dataset client and an existing dataset named "Regression cases"
    When the caller creates another dataset with that name in the same project
    Then the caller receives the server's structured error instead of a successful dataset result

  # Requirement: Item values and source provenance

  Scenario: JSON values retain their types
    Given an isolated dataset client and an active dataset
    When the caller creates an item with input false, expected output 0, and source output ""
    Then the received request and returned item preserve those three distinct JSON values

  Scenario: Incomplete provenance fails before a write
    Given an isolated dataset client and an active dataset
    When the caller creates an item with a source trace ID but no source timestamp
    Then the caller receives a validation error and the mock service receives no request

  # Requirement: Stable item identity and immutable versions

  Scenario: Updating an item preserves its historical version
    Given an isolated dataset client and an item at version 1 with an expected output
    When the caller updates expected output to null using base version 1
    Then the stable item ID is unchanged and a new version ID is returned
    And reading the original revision returns the original expected output

  Scenario: Identical content does not create history
    Given an isolated dataset client and an item at its current version
    When the caller submits the same editable content with that base version
    Then the item version and dataset revision remain unchanged

  # Requirement: Optimistic concurrency for item mutations

  Scenario: A concurrent update is not overwritten
    Given an isolated dataset client whose caller observed item version 1, now superseded by version 2
    When the caller updates that item using base version 1
    Then the caller receives the conflict with current-version details
    And the mock service receives one write and no automatic refresh or replacement write

  Scenario: Restore copies history into a new version
    Given an isolated dataset client and an archived item currently at version 3
    When the caller restores it using base version 3 and source version 1
    Then the returned active version has version 1's content and a new immutable version ID

  # Requirement: Dataset and item archive states

  Scenario: Restoring a dataset preserves archived items
    Given an isolated dataset client and an archived dataset containing an archived item
    When the caller restores the dataset and lists active items
    Then that item is absent from the active listing and present in the archived listing

  # Requirement: Explicit item-create idempotency

  Scenario: A keyed item create can recover a lost acknowledgment
    Given an isolated dataset client and a mock service that persists an item create but loses its response
    When the caller creates the item using client item ID "case-1" with retries enabled
    Then every attempt uses the same identity and content
    And the successful result identifies the one persisted item and version

  Scenario: An unkeyed item create is not replayed
    Given an isolated dataset client and a mock service that loses an item-create response
    When the caller creates the item without a client item ID
    Then the caller receives an error with unknown persistence and the service receives one request

  # Requirement: Explicit pagination without credential forwarding

  Scenario: Pagination preserves the original request scope
    Given an isolated dataset client and an item page at revision 3 whose next URL names another host and revision 4
    When the caller continues the listing using the returned offset
    Then the next request uses the configured host, original dataset, revision 3, and archive filter
    And no credentials are sent to the host in the response URL

  Scenario: Invalid continuation is observable
    Given an isolated dataset client and an empty item page with a continuation
    When the caller reads that page
    Then the caller receives an invalid-response error

  # Requirement: Revision-pinned snapshots

  Scenario: Dataset changes do not move a snapshot
    Given an isolated dataset client and a snapshot resolved at revision 3
    When the dataset advances to revision 4 before the caller iterates the snapshot
    Then all item requests use revision 3
    And iterating again uses revision 3 from the first page

  Scenario: Historical resolution survives concurrent writes
    Given an isolated dataset client resolving historical revision 2 while new revisions shift the history pages
    When the first history lookup returns a different revision
    Then the snapshot resolves the UUID belonging to revision 2 from the remaining history

  # Requirement: Snapshot failures are distinct from empty datasets

  Scenario: Empty history differs from an empty revision
    Given an isolated dataset client, a never-populated dataset, and a dataset whose items are all archived
    When the caller requests snapshots of both datasets
    Then the never-populated dataset produces an error
    And the other snapshot iterates successfully with no active items

  Scenario: A partial read remains a failure
    Given an isolated dataset client and a snapshot whose first page succeeds and second page fails
    When the caller consumes the iteration
    Then the caller receives the first page followed by the structured read error

  # Requirement: Validate returned dataset identity and revision scope

  Scenario: A newer item cannot enter a pinned read
    Given an isolated dataset client requesting active items at revision 3
    When the mock service responds with an item introduced at revision 4
    Then the caller receives an invalid-response error instead of that item

  # Requirement: Convert dataset cases into independent executions

  Scenario: Source data does not become a new execution's output
    Given an isolated dataset client and an active case with source output, source trace ID, and client item ID "case-1"
    When the caller converts the case twice with different execution outputs and trace IDs
    Then the declarations have different execution IDs and the same case key and dataset-item version ID
    And each declaration contains its caller-supplied output and application trace ID
