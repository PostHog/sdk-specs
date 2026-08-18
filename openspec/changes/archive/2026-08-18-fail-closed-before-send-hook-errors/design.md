## Context

Before-send hooks are the final application-controlled interception point before analytics events enter the delivery queue. Applications can use them to remove PII or reject sensitive events. The current contract permits SDK-specific fail-open behavior after a hook throws, which can bypass that privacy control.

## Goals / Non-Goals

**Goals:**

- Define one cross-SDK outcome for analytics before-send hook exceptions.
- Prevent an event from being queued after its filtering chain fails.
- Preserve the fire-and-forget capture contract by containing and logging the hook exception.
- Make the outcome testable in the canonical acceptance scenarios.

**Non-Goals:**

- Change explicit drops caused by returning `null` or `nil`.
- Change hook ordering or successful mutation behavior.
- Define exception behavior for the separate logs or traces hook contracts.
- Change any public hook signature.

## Decisions

- **Fail closed on every hook exception.** The SDK catches the exception, records a warning, stops the chain, and drops the event. Continuing with the original or last good value is unsafe because the failed hook may have been responsible for PII removal.
- **Do not propagate the exception.** Capture remains fire-and-forget, so application code must not crash because a hook failed.
- **Assert both containment and non-enqueue.** The acceptance scenario verifies that capture does not throw, a warning is recorded, and the event is absent from the queue.
- **Align the capture contract.** Capture must refer to the canonical fail-closed behavior rather than allowing platform-specific fallback policies.

## Risks / Trade-offs

- **SDKs that currently fail open will send fewer events after hook failures.** This is intentional and prioritizes privacy over delivery completeness.
- **Existing compliance results may regress until SDKs adopt the rule.** The acceptance assertion makes those implementation gaps explicit.
