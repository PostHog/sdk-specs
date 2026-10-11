## Why

The capture-ai spec's Configuration section says the capability has "One public
flag" — `enable_full_ai_capture` — and treats everything about the AI lane's
transport (compression, queue capacity, upload timeout, per-event size cap) as
non-normative. Two server SDKs have since converged on a public, AI-lane-scoped
configuration surface with identical defaults:

| Knob | posthog-python (`v1`) | posthog-go (`v1`) | Default |
|---|---|---|---|
| Compression | `capture_ai_compression` | `CaptureAICompression` | none |
| Queue capacity | `capture_ai_max_queue_size` | `CaptureAIMaxQueueSize` | 1000 |
| Upload timeout | `capture_ai_timeout` | `CaptureAIBatchUploadTimeout` | 30s |
| Per-event size cap | `capture_ai_max_event_bytes` (lower-only) | internal constant | 8 MiB + envelope headroom |
| Batch-size target | internal constant | internal constant | ~5 MiB |

Both SDKs also keep the lanes' configuration independent: the analytics
compression environment variable (`POSTHOG_CAPTURE_COMPRESSION` in Python) does
not change AI uploads, so a project that gzips analytics does not silently start
gzipping multi-MB AI payloads.

Leaving the spec at "one public flag" means the next SDK to add AI capture has no
contract to copy, and is free to reuse the analytics queue, timeout and
compression settings — which is the behavior both SDKs deliberately moved away
from.

## What Changes

- The Configuration section splits into the content-capture flag (unchanged) and
  the AI lane configuration surface, with the shared defaults and the
  lower-only rule for the per-event cap.
- A new capture-ai requirement, **AI lane configuration is scoped to the AI
  lane**, covering lane isolation of configuration, the defaults, the lower-only
  per-event cap, the non-configurable batch target, and rejecting invalid values
  at construction.
- The Transport (non-normative) paragraph no longer implies the per-event cap is
  purely operational; the cap's value stays non-normative, its lower-only
  exposure does not.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture-ai`: new **AI lane configuration is scoped to the AI lane**
  requirement; Configuration and Transport sections.

## Impact

- **posthog-python** (`v1` branch): already conforms — PostHog/posthog-python#1022.
- **posthog-go** (`v1` branch): conforms except that the per-event cap is an
  internal constant, which this spec permits (the knob is MAY).
- **posthog-node**: supports `capture_ai` but has no AI-lane knobs yet; it gains
  a contract to implement, not a break.
- Other server SDKs: no change until they add AI capture.
