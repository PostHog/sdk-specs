## Why

A bounded persistent queue and the mechanism that schedules upload attempts have different responsibilities. A retry budget can stop an active flush sequence from consuming network and battery, but it does not establish that valid queued records should be deleted. Coupling those concerns allows an extended outage or retryable backend failure to erase a durable backlog.

Two related lifecycle races also need a canonical outcome. SDKs should not spend retry attempts while their platform positively reports that the network is unavailable, and a successful in-flight request must not positionally delete replacement records that entered a full queue after the sent records were evicted.

## What Changes

- Define the permitted removal conditions for records in bounded durable queues and prohibit retry-budget exhaustion from acting as a deletion condition.
- Allow a retry budget to end a failure-driven flush sequence while retaining records for a later independent flush trigger.
- Require SDKs to pause transport attempts without consuming retry budget while network state is known to be offline, then make queued work eligible when connectivity returns.
- Require successful flushes to acknowledge the exact queue entries sent, so capacity eviction and concurrent replacement cannot cause never-sent records to be removed.
- Align the logs and traces retry contracts with the durable retry-queue lifecycle.
- Add private acceptance scenarios for retry exhaustion, offline pause and recovery, and full-buffer replacement during an in-flight flush.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `retry-queue`: Separate durable record retention from flush retries, pause known-offline delivery, and remove acknowledged entries by stable identity.
- `logs`: Retain records in bounded durable log queues when a retry sequence ends.
- `traces`: Retain spans in bounded durable trace queues when a retry sequence ends.

## Impact

The canonical retry-queue, logs, and traces specifications change, together with private retry-queue acceptance coverage. SDKs with bounded persistent queues that currently clear records after retry exhaustion or remove successful batches positionally require follow-up implementation changes.

This change does not require browser page-lifetime buffers to become persistent. It does not add or rename a public option, select fleet-wide retry counts or backoff constants, change queue capacities or eviction order, or reclassify terminal HTTP and payload failures.
