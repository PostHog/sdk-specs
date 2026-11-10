## Context

The existing metadata contract treats framework-consumed exceptions as handled, but does not name the boundary for a framework-managed job retry. In Active Job, `perform` raises and `retry_on` consumes that failure while rescheduling. Using `perform` alone would label this handled retry as unhandled.

## Goals / Non-Goals

**Goals:** Define the boundary consistently for integrations that report job retries. Preserve unhandled metadata for failures that escape job execution.

**Non-Goals:** Requiring retry reporting, changing opt-in defaults, prescribing retry policy, or changing exception deduplication, nested exception disposition, source or severity metadata.

## Decisions

Use job execution including the framework retry handler as the relevant application boundary. When a handler consumes the exception and schedules a retry without allowing it to escape that boundary, a retry report is handled. Merely observing an exception or scheduling work while rethrowing it is not enough to mark it handled.

The alternative was the user job method alone. That would classify a framework-consumed retry differently from other framework-consumed failures and would make recoverable retries appear unhandled. Terminal failures remain unhandled only when they escape job execution, not merely because retry attempts were exhausted.

The rule is conditional on reporting. Integrations such as Celery that do not emit retry exception events do not need to start doing so. Existing independent nested-exception handled-state rules remain unchanged.

## Risks / Trade-offs

- Frameworks differ in how they propagate retry signals. The rule depends on whether the reported exception is consumed at the execution boundary, not a framework method name or a retry counter.
- Existing SDK retry reports may need a handled-state correction. The Ruby follow-up is tested against real Active Job 5.2.8.1 and 7.2.3.1 lifecycles, without changing scheduling or terminal metadata.

## Migration Plan

Sync and archive this clarification in the same PR. Apply SDK changes in their own repositories. No public API migration is required.

## Open Questions

None for this clarification. Whether an integration should report retries remains outside this contract.
