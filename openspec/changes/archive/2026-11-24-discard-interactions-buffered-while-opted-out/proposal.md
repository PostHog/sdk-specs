## Why

Some client capture features do not call `capture` at the moment of the interaction. The browser's
heatmaps extension buffers every click and mouse move in memory and sends the buffer on a timer, and
the dead-click detector holds each click as a candidate for a few seconds before it decides whether
the click was dead. Both read consent only when they finally capture.

`consent-gating` today only says that an event-producing call short-circuits while capture is
disallowed. That is not enough for a buffering feature: an interaction that happened while capturing
was off is still in the buffer when the visitor opts in, and the next send carries it. The click on
a consent banner's accept button is one of those interactions, so the data a visitor refused — or
had not yet agreed to — reaches PostHog as soon as they agree to anything.

posthog-js now checks consent when the interaction is stored and discards everything pending when
consent changes. The spec should state the rule for every SDK that buffers interactions this way,
so the deferred path is not left to each implementation.

## What Changes

- **Added: "Interaction data buffered before a consent change is never sent."** A capture feature
  that stores interactions and sends them later SHALL read the consent state when it stores an
  interaction, not only when it sends. On a consent change the SDK SHALL discard the pending
  buffer and any deferred report whose interaction happened before the change, in both directions
  (opt-out and opt-in), and an identity change that a consent change triggers (the browser's
  cookieless `on_reject` mode) SHALL discard them too, so points never cross from one identity to
  the next.
- Scope today is the browser's heatmaps buffer and its dead-click/dead-swipe candidates. The
  requirement is written against the behavior, not those features, so an SDK that adds a buffered
  interaction feature inherits it.

This does not change `capture`, the public opt-in/opt-out APIs, or any event's properties. The
deferred-crash rule in `opt-in` ("Deferred crash reports honour consent at crash time") decides the
same question for reconstructed crashes; this is the in-process counterpart for interaction
buffers, and the two agree: consent at the time of the interaction decides.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `consent-gating`: one added requirement.

## Impact

- **posthog-js browser:** matches the behavior shipped in PostHog/posthog-js#5833 — `_onClick` and
  mouse-move bursts check `is_capturing()` before storing, `discardPending()` clears the heatmap
  buffer on an opt-out, on an opt-in that changes the stored state, and on entering cookieless
  mode, and a dead-click candidate clicked before the change is dropped.
- **Other client SDKs:** no change today. None of them buffer interactions outside `capture`.
- No new public API, no new events, no new properties.
