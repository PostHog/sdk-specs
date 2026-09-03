## Why

The logs `beforeSend hook` requirement says a throwing hook "SHALL be caught: the SDK swallows
the error and continues the chain with the prior value" — fail-open, the record still ships.
No SDK implements it. Every logs implementation that can observe a throw drops the record:

| SDK | Behavior on a throwing logs hook |
| --- | --- |
| `posthog-js` / `posthog-node` (shared core) | drops the record |
| `posthog-android` | drops the record (`catch (e: Throwable) { onHookError?.invoke(e); return null }`) |
| `posthog-flutter` | drops the record (`"beforeSend threw, dropping log"`) |
| `posthog-ruby` (`logs_before_send`) | drops the record, and documents that it does |
| `posthog-ios` | cannot observe a throw — `BeforeSendChain` is a non-throwing `(T) -> T?` |

The divergence is not accidental, and the traces capability already noticed it. The `Gating and
beforeSpanSend` requirement makes the traces hook fail-closed and says why — "a broken scrubber
must not leak the unscrubbed record" — then adds: *"This deliberately diverges from the logs
`beforeSend` fail-open rule, which does not carry a scrubbing designation."*

That is an accurate reading of the logs spec as written, and it is the part this proposal
disagrees with. The logs spec never designates `beforeSend` as the scrubbing point, but every
implementation and every user-facing doc treats it as one, and the SDKs chose fail-closed on
their own for exactly the traces reasoning:

- `posthog-ruby` documents `logs_before_send` as "useful for scrubbing PII", and drops on raise.
- `posthog-android` reports only the throwable's class when a hook throws, because "a hook's
  exception message can embed user log bodies / attributes (PII)" — a precaution that only makes
  sense if the hook is understood to be handling sensitive content.

A log body is free text with arbitrary attributes: the surface people actually attach secrets to,
more so than a structured analytics event. Fail-open means the one record whose scrubber crashed
is the one that ships unscrubbed, arriving indistinguishable from a record no hook was meant to
touch. The missing scrubbing designation is the bug; the fail-open rule is downstream of it.

So the two hooks should not diverge. Analytics already settled here — `before-send-hook` has
required fail-closed since 2026-08-18, for the same "a failed privacy filter must not leak the
event" reason — which leaves the logs hook as the only one this repo still specs fail-open.
Rather than change five SDKs to match a line none of them implemented, this gives the logs hook
the designation it already has in practice and aligns the failure rule with its two siblings.

`posthog-node`'s `beforeSpanSend` (PostHog/posthog-js#4584) ships fail-closed today and currently
documents the logs hook as an implementation that does not match its own spec. That note goes
away with this change.

## What Changes

- Designate the logs `beforeSend` as the scrubbing point for sensitive record content, matching
  `beforeSpanSend` and matching what SDK documentation already tells users.
- Require a throwing `beforeSend` to **drop** the record rather than continue the chain with the
  pre-hook value.
- Say what "caught" still guarantees: the throw SHALL NOT propagate into the caller's capture
  call, and SHALL NOT stop later records from being processed.
- Require the drop to be diagnosable, while allowing an SDK to report only the error type — a
  hook's exception message can embed the very record body it was handed.
- Replace the `throwing hook is contained` scenario, which asserts the behavior being removed.
- Add the throw to the `Capture-time gating` drop list, which enumerates why gate 4 drops a
  record and would otherwise read as exhaustive while missing the new cause.
- Update the `traces` cross-reference, which asserts a divergence that no longer exists.

Deliberately not in scope: bringing the **analytics** `before_send` implementations into line.
That hook's failure behavior is already settled — `before-send-hook` has required fail-closed
since `2026-08-18-fail-closed-before-send-hook-errors`: catch, warn, stop the chain, and drop,
never enqueuing "the original event or the last successfully transformed value". `posthog-js`,
`posthog-node`, `posthog-go`, `posthog-dotnet`, `posthog-android` and `posthog-flutter`
(PostHog/posthog-flutter#542) match it; `posthog-python` (`client.py`, "Continue with the original
message if callback fails") and `posthog-ruby` (`process_before_send`, "using original event")
still continue with the pre-hook event and are in deviation from it. Closing that is an
implementation gap in two SDKs against an existing requirement, not a spec question, so it is
tracked there rather than reopened here.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `logs`: Designate `beforeSend` as the scrubbing point and require a throwing hook to drop the
  record instead of continuing with the pre-hook value.
- `traces`: Drop the sentence asserting that `beforeSpanSend` diverges from a fail-open logs rule.

## Impact

- No SDK changes. This makes the canonical text match what `posthog-js`, `posthog-node`,
  `posthog-android`, `posthog-flutter` and `posthog-ruby` already do, and removes a deviation
  each of them is currently in.
- `posthog-ios` is unaffected: its chain signature makes a throwing hook unrepresentable, which
  satisfies the requirement vacuously.
- A future SDK reading the spec literally would have shipped fail-open and leaked unscrubbed
  records. This is the change that stops that.
- Users lose no records they have today, since no implementation ships the fail-open behavior.
- All three before-send-style hooks become one rule, so a port implementing more than one writes
  the same handling twice rather than remembering which signal fails which way.
