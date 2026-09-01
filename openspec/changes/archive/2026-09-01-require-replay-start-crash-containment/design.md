## Context

`start-session-recording` runs replay setup on the caller's thread. Two audited SDKs crashed during that setup when the replay configuration was invalid and the replay integration failed to initialize. The crash reached the host application because the setup path threw before any snapshot was masked. The spec already implied that this must not happen, but only in prose, so no conformance test held either SDK to it.

## Goals

- State one observable crash-containment outcome that every replay-capable SDK MUST meet.
- Test the two setup failure inputs that the customer hit.

## Decisions

### Contain failures at the start boundary

`start-session-recording` is the boundary where a caller asks for replay. A failure inside replay setup — invalid configuration, or an unavailable or failed integration — MUST stop at that boundary. The SDK no-ops or logs, and the call returns normally. Session recording stays inactive because setup did not complete. This matches the fail-closed rule already stated for `session-replay-privacy` capture.

### Keep logging optional

The requirement says "no-op or log", not "log". Some platforms have no logger on the start path, and an unsupported platform may silently no-op. The non-negotiable outcome is that the call does not throw and recording stays inactive. The acceptance scenarios assert only those two outcomes so the contract does not over-constrain SDKs that legitimately stay silent.

### Resolve, do not reject

Promise-returning variants resolve after a contained setup failure rather than reject, because a rejected promise surfaces as an application-level error, which is the crash class this change prevents.

## Risks / Trade-offs

- **A silent no-op can hide a misconfiguration** -> Allow logging and recommend it; the customer's direct SDK fixes can log the setup failure so the misconfiguration stays diagnosable.
