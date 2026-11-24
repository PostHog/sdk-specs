## Why

Every SDK attaches a queue-depth key (`$sdk_debug_retry_queue_size` on the browser,
`$sdk_debug_pending_queue_size` on mobile) to every captured event, even when its value only
says the queue is healthy. On the browser the retry queue is almost always empty, so nearly
every event carries `$sdk_debug_retry_queue_size: 0`. On mobile, a depth below `flushAt` is just
ordinary batching. These values add bytes to every event without helping anyone diagnose a
delivery problem.

## What Changes

- **Renamed and rewritten: "The queue-depth key stays on every non-`$snapshot` event" becomes
  "The queue-depth key is attached only while the send queue is backed up".**
  - An SDK SHALL NOT attach the key when the queue's depth is `0`.
  - posthog-js SHALL attach `$sdk_debug_retry_queue_size` whenever its retry queue is not empty,
    because that queue only holds failed requests waiting to be retried.
  - A mobile SDK SHOULD attach `$sdk_debug_pending_queue_size` when the depth is at or above its
    current flush threshold, and MAY omit it below that threshold, where the queue is ordinary
    batching. The flush threshold is the depth at which the SDK starts a flush: the configured
    `flushAt`, or the lower value an SDK that reduces `flushAt` after a `413` response is using.
    Every first-party mobile SDK, including React Native and Flutter desktop, omits it below that
    threshold.
  - When attached, it goes on every non-`$snapshot` event as before, and it stays stripped from
    the mobile crash-context snapshot.
  - The key is SDK-owned. While the queue is not backed up, the SDK removes a registered or
    caller-supplied value of the same name, so the app cannot make a healthy queue look backed up.
    This keeps today's behavior, where the SDK value already replaces such a value. The keys
    requirement and the replay-off gate state this exception next to their caller-wins rule.
- **Modified: Session, queue, hold-reason, trigger, and mode keys.** The two scenarios that
  expected the queue key on any eligible event now set up a backed-up queue first.
- **Modified: Attach the disabled shape when replay is not configured.** The scenarios no longer
  expect the queue key on every event.
- **Modified: Attach only the disabled shape while replay is intentionally off.** The scenarios no
  longer expect the queue key on every event. The rule that the replay-off gate does not remove the
  queue key is unchanged: while the queue is backed up, the key is still attached when replay is off.
- The Purpose paragraph's description of the queue-depth key is updated by hand at apply time,
  because the delta cannot reach it.

A missing key means the queue was not backed up when the event was built, or, for an event from
an SDK version that predates this rule, that the value was not reported. `$lib` and
`$lib_version` tell the two apart.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-debug-properties`: one renamed and rewritten requirement and three modified
  requirements, listed above.

## Impact

- **posthog-js browser:** attach `$sdk_debug_retry_queue_size` only when the retry queue is not
  empty. The current compatibility goldens drop the key; the historical goldens are unchanged.
- **posthog-js react-native:** attach `$sdk_debug_pending_queue_size` only when the persisted
  queue holds at least `flushAt` events.
- **posthog-ios, posthog-android:** attach `$sdk_debug_pending_queue_size` only when the queue's
  depth is at or above the current `flushAt`, which both SDKs halve after a `413` response.
- **posthog-flutter:** the Dart core (Windows and Linux) follows the mobile rule. iOS, macOS,
  Android and web events follow the native SDKs and posthog-js.
- Consumers that filter on the key existing see fewer events with it: only those captured while
  delivery is behind.
- No new public API. No new keys.
