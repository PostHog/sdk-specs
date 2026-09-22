## ADDED Requirements

### Requirement: Snapshot evaluation runtime access

A server SDK that loads local flag definitions MAY expose a runtime accessor on the snapshot (`getEvaluationRuntime(key)` / `get_evaluation_runtime(key)` or equivalent). It lets a caller choose which flags to forward to a client, for example when bootstrapping a browser SDK from a server request. An SDK that exposes the accessor SHALL follow the rules below.

The accessor SHALL return the flag's configured evaluation runtime exactly as `/local_evaluation` reports it in the definition's `evaluation_runtime` field (`"all"`, `"client"` or `"server"`). The SDK SHALL NOT filter, reorder or drop snapshot flags based on the runtime; which runtimes are safe to forward is the caller's decision.

The value SHALL be available for every snapshot flag that has a loaded local definition reporting the field, whether the flag's value resolved locally or was filled from a `/flags` (or equivalent) fallback. A flag that fell back to remote evaluation keeps the runtime of its local definition; the remote value does not erase it.

The accessor SHALL return the platform's nullish sentinel when the key is not in the snapshot, when the loaded definition does not report the field, or when the flag has no loaded local definition, because `/flags` does not report the runtime. A nullish result means the runtime is unknown. The SDK SHALL NOT substitute a default such as `"all"`.

Reading the runtime SHALL use only the snapshot and SHALL NOT issue a flag-evaluation request, mark the flag as accessed for `onlyAccessed()`, or emit `$feature_flag_called`.

#### Scenario: Runtime read is a silent lookup of the local definition (@evaluation_runtime_capable)
- **GIVEN** local feature flag definitions resolve "client-flag" for distinct id "user-123" as true
- **AND** the local feature flag definition for "client-flag" reports evaluation runtime "client"
- **AND** local feature flag definitions resolve "legacy-flag" for distinct id "user-123" as true
- **AND** the local feature flag definition for "legacy-flag" reports no evaluation runtime
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot evaluation runtime is read for "client-flag"
- **AND** snapshot evaluation runtime is read for "legacy-flag"
- **THEN** the returned evaluation runtime for "client-flag" should be "client"
- **AND** the returned evaluation runtime for "legacy-flag" should be absent
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
- **THEN** the snapshot should contain "gated-flag" with value true
- **AND** the returned evaluation runtime for "gated-flag" should be "all"

#### Scenario: Flag without a local definition has no runtime (@evaluation_runtime_capable)
- **GIVEN** no local feature flag definition is loaded for "remote-only-flag"
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key              | value |
  | remote-only-flag | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **THEN** the snapshot should contain "remote-only-flag" with value true
- **AND** the returned evaluation runtime for "remote-only-flag" should be absent
- **AND** the returned evaluation runtime for "missing-flag" should be absent
