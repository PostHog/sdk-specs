## Context

The hook is the last application-controlled interception point before delivery. Every SDK but one runs it synchronously inside capture, which makes the ordering question invisible: the event is handed over before the capture call returns, so no later call can overtake it. posthog-flutter accepts a hook that returns a `Future`, which opens a window between "the app captured the event" and "the SDK has the event" in which any other call can land first.

## Decisions

**Order over snapshot-and-restore.** The alternative fix is to capture the identity state at hook time and restore it when the event is handed over. Earlier revisions of PostHog/posthog-flutter#672 did that and review kept finding state it did not cover — the cookieless sentinel, consent revoked in another browser tab, the next user's registered properties and `$groups`. Ordered hand-over makes the whole class disappear, so the requirement is written as an ordering guarantee rather than a list of fields to preserve.

**Getters wait too.** A getter that reads state the pending event has not yet been handed over under would report state the app cannot act on consistently. posthog-flutter holds getters behind the pending event, and the requirement follows it.

**A bounded wait, and the event is still sent.** A hook that never completes would otherwise stall the SDK for the life of the process. The requirement therefore demands a bound and names posthog-flutter's 10 seconds as the shipped value rather than fixing one cross-SDK number, since only one SDK has the problem. Releasing the queue is not the same as abandoning the event: the event is handed over when the chain finishes, because dropping it would make a slow privacy filter lose data silently.

**No deadlock.** A hook that calls back into the SDK is legitimate (renaming a `$screen` re-captures). Such a call must not wait for the turn it runs inside.

## Open questions

- The convergent answer is a synchronous hook (PostHog/posthog-flutter#686, proposed for 6). This change records the contract for as long as an asynchronous hook is accepted; it does not require SDKs to accept one, and it does not pre-judge whether the Flutter hook stays asynchronous.
- `acceptance/private/before-send-hook.feature` is untouched: the harness has no steps for call ordering or for an asynchronous hook. The scenarios live in `spec.md` only and have not been run against an adapter.
