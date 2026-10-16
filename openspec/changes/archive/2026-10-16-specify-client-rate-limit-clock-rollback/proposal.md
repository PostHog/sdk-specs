## Why

The `capture` spec lists "client-side rate limit (browser only)" as a reason a capture is dropped
silently, and never says what that limiter is or what bounds it. Nothing in the contract stopped it
from dropping captures for a reason other than capture volume.

It did. posthog-js persists a token bucket refilled from the device's wall clock. A backward clock
change made the elapsed time negative, so the refill *subtracted* tokens:
[posthog-js#5297](https://github.com/PostHog/posthog-js/issues/5297) reports a 143-second rollback
turning a 99-token balance negative and falsely rate-limiting captures for the rest of that
balance's life — the bucket is persisted, so a reload does not clear it.
[posthog-js#5298](https://github.com/PostHog/posthog-js/pull/5298) fixed it, and noted the spec
"does not define clock rollback semantics".

Which captures reach PostHog is the capture contract, so this is worth closing in writing.

## What Changes

- New requirement in `capture`, **Client-side capture rate limiting never loses tokens to a clock
  change**: the limiter is a persisted token bucket; its refill counts elapsed time as zero when the
  clock is behind the stored instant, stores the later of the two instants, caps the balance at the
  burst limit, and never lets it go below zero. Dropping is a function of capture volume, not of the
  direction the clock moved.
- Two `@client` scenarios: a rollback does not drop the next capture, and a rollback followed by the
  clock catching up does not refill the bucket twice.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: one added requirement. No existing requirement changes.

## Impact

Descriptive for posthog-js, which behaves this way as of #5298. No other SDK implements a
client-side capture rate limit today, so none has to change; the requirement scopes itself to SDKs
that do.

- **Acceptance adapters**: the scenarios use three phrases that have no binding yet — initializing
  with "client rate limiting of N capture(s) per second with a burst limit of M", "the SDK clock
  moves backward by", and "no event named ... should be enqueued". They are written in the style of
  the existing clock and capture steps. No acceptance feature file is added in this change.
- **Uncertain**: the configuration option names and defaults recorded here are posthog-js's. A second
  SDK adding client-side rate limiting may want different names; the requirement allows platform
  convention but fixes the defaults, which is the part a reviewer should confirm.
