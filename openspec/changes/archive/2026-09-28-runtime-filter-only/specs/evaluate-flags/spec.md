## MODIFIED Requirements

### Requirement: Snapshot evaluation runtime access

A server SDK that loads local flag definitions MAY expose the flag evaluation runtime on the snapshot. It lets a caller choose which flags to forward to a client, for example when bootstrapping a browser SDK from a server request. An SDK that exposes the evaluation runtime SHALL expose it as a runtime criterion on its in-memory snapshot filter (for example `only(filter)` with an `evaluationRuntimes` field, alongside the explicit-key filter) and SHALL follow the rules below. The filter is the only surface for the runtime; this spec defines no per-key accessor.

The criterion SHALL match a flag on the evaluation runtime its loaded local definition reports in the `evaluation_runtime` field (`"all"`, `"client"` or `"server"`), exactly as `/local_evaluation` reports it. The filtered snapshot SHALL keep a flag only when that runtime is one of the requested values. When the filter also carries explicit keys, a flag SHALL satisfy every criterion set.

The runtime SHALL come from the local definition for every snapshot flag that has one, whether the flag's value resolved locally or was filled from a `/flags` (or equivalent) fallback. A flag that fell back to remote evaluation keeps the runtime of its local definition; the remote value does not erase it.

A flag's runtime is unknown when its loaded definition does not report the field or when the flag has no loaded local definition, because `/flags` does not report the runtime. A flag with an unknown runtime SHALL NOT match any runtime criterion. The SDK SHALL NOT substitute a default such as `"all"`; unknown is not client-safe. Callers that want to keep such flags filter by explicit key.

Outside the filter, the SDK SHALL NOT filter, reorder or drop snapshot flags based on the runtime; which runtimes are safe to forward is the caller's decision.

Filtering by runtime follows the in-memory filtering rules: it SHALL use only the snapshot and SHALL NOT issue a flag-evaluation request, mark any flag as accessed for `onlyAccessed()`, or emit `$feature_flag_called`.

#### Scenario: Runtime filter is a silent lookup of the local definition (@evaluation_runtime_capable)
- **GIVEN** local feature flag definitions resolve "client-flag" for distinct id "user-123" as true
- **AND** the local feature flag definition for "client-flag" reports evaluation runtime "client"
- **AND** local feature flag definitions resolve "legacy-flag" for distinct id "user-123" as true
- **AND** the local feature flag definition for "legacy-flag" reports no evaluation runtime
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** the snapshot is filtered to evaluation runtime "client"
- **THEN** the filtered snapshot should contain "client-flag" with value true
- **AND** the filtered snapshot should not contain "legacy-flag"
- **AND** no remote feature flag evaluation request should have been sent
- **AND** no event named "$feature_flag_called" should be enqueued
- **AND** snapshot only accessed should return no flags

#### Scenario: Remote fallback keeps the local definition's runtime (@evaluation_runtime_capable)
- **GIVEN** local feature flag definitions cannot resolve "gated-flag" for distinct id "user-123"
- **AND** the local feature flag definition for "gated-flag" reports evaluation runtime "all"
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key        | value |
  | gated-flag | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** the snapshot is filtered to evaluation runtime "all"
- **THEN** the snapshot should contain "gated-flag" with value true
- **AND** the filtered snapshot should contain "gated-flag" with value true

#### Scenario: Flag without a local definition never matches a runtime (@evaluation_runtime_capable)
- **GIVEN** no local feature flag definition is loaded for "remote-only-flag"
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key              | value |
  | remote-only-flag | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** the snapshot is filtered to evaluation runtimes "client", "all" and "server"
- **THEN** the snapshot should contain "remote-only-flag" with value true
- **AND** the filtered snapshot should not contain "remote-only-flag"

#### Scenario: Runtime filter keeps the requested runtimes and drops unknown ones (@evaluation_runtime_capable)
- **GIVEN** a snapshot contains "client-flag" with evaluation runtime "client", "all-flag" with evaluation runtime "all", "server-flag" with evaluation runtime "server", and "legacy-flag" with no evaluation runtime
- **WHEN** the snapshot is filtered to evaluation runtimes "client" and "all"
- **THEN** the filtered snapshot contains "client-flag" and "all-flag"
- **AND** it does not contain "server-flag" or "legacy-flag"
- **AND** no feature-flag evaluation request is made
- **AND** no `$feature_flag_called` event is emitted
- **AND** the parent snapshot's accessed-key set is unchanged

