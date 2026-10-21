@public @canonical_behavior @acceptance @ai-scorers @server
Feature: AI Scorers
  Canonical contract: openspec/specs/ai-scorers/spec.md
  These scenarios require management API harness bindings before integration selection.

  Background:
    Given an isolated SDK instance

  # Requirement: Scorer management surface and stable identity

  Scenario: Same-name scorers remain independent
    Given an isolated scorer client and two scorers named "Correctness"
    When the caller fetches each scorer by its UUID
    Then each response identifies the requested definition and its own current version UUID

  # Requirement: Boolean score polarity is versioned configuration

  Scenario: Failure polarity does not invert an uploaded value
    Given an isolated scorer client and a boolean scorer version with true_is_failure true
    When the caller uploads an ok evaluation result with value true using that version
    Then the received result still has status ok and boolean value true
    And the scorer version still describes true as failure

  # Requirement: Numeric and categorical configurations retain their meaning

  Scenario: A zero numeric threshold and null bounds survive management
    Given an isolated scorer client
    When the caller creates a numeric scorer with null bounds and a gte passing threshold of 0
    Then the request preserves the null bounds and zero threshold
    And the returned configuration contains the acknowledged rule

  Scenario: An empty multiple-selection passing set is preserved
    Given an isolated scorer client
    When the caller creates a categorical scorer with multiple selection and an empty passing category list
    Then the empty list is transmitted and returned as configuration
    And it is distinct from an omitted or null passing rule

  # Requirement: Metadata changes do not rewrite versions

  Scenario: Restoring and clearing metadata preserves the version
    Given an isolated scorer client and an archived scorer with a description and tags
    When the caller updates archived to false, description to null, and tags to an empty list
    Then the scorer is active with cleared description and tags
    And its version number, version UUID, and configuration are unchanged

  # Requirement: Explicit immutable version creation

  Scenario: A new version does not alter an existing result's configuration
    Given an isolated scorer client and a saved scorer version UUID
    When the caller creates a new version with different polarity
    Then the current version UUID changes
    And fetching the saved version returns its original configuration

  Scenario: Identical configuration can intentionally create a version
    Given an isolated scorer client and a scorer with a current configuration
    When the caller explicitly creates a version with that same configuration
    Then a new current version number and UUID are returned

  # Requirement: Optional scorer concurrency guard

  Scenario: A stale version creation remains a conflict
    Given an isolated scorer client whose caller observed version 1, now superseded by version 2
    When the caller creates a version with base version 1
    Then the caller receives the conflict and current-version details
    And the service receives one write and no automatic refresh or replacement write

  # Requirement: Scorer mutations are not automatically replayed

  Scenario: A lost version acknowledgment does not create another version
    Given an isolated scorer client and a mock service that persists a version but loses its response
    When the caller creates that version with client retries enabled
    Then the service receives one version-creation request
    And the caller receives a structured error with unknown persistence

  # Requirement: Definition offsets and version cursors remain distinct

  Scenario: Scorer listing retains its filters
    Given an isolated scorer client and a page of active numeric scorers filtered by tag "regression"
    When the caller continues with that page's next offset and the same filters
    Then the request retains kind, archive, and tag filters at the configured scorer endpoint

  Scenario: Version history continues by cursor
    Given an isolated scorer client and a version page with next cursor "next-page"
    When the caller requests the next version page
    Then the request sends cursor "next-page" and does not substitute a numeric offset

  # Requirement: Returned scorer values are detached and validated

  Scenario: A malformed success is not an acknowledgment
    Given an isolated scorer client and a mock service returning success with an invalid current version UUID
    When the caller creates a scorer
    Then the caller receives an invalid-response error with unknown persistence
    And the service receives no automatic replay
