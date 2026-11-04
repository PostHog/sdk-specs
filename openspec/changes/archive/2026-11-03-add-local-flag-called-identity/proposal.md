## Why

Nothing in the specs says that a `$feature_flag_called` event identifies which flag definition produced
the value. `feature-flag-called-tracker` names `$feature_flag_id` and `$feature_flag_version` only in
passing, inside the minimal-event allowlist, as "evaluation debug scalars the server/SDK already
attaches". That phrasing reads as "whatever the remote response happened to carry", so a server SDK that
evaluates a flag locally has no stated obligation to attach either one — and the two server SDKs that
send these properties both read them from the remote `/flags` response metadata only.

posthog-python closed that gap in [PostHog/posthog-python#1149](https://github.com/PostHog/posthog-python/pull/1149).
A locally evaluated read now takes `id` and `version` from the local flag definition that produced the
value, across `get_feature_flag()`, `feature_enabled()`, `get_feature_flag_result()` and the
`get_feature_flag_payload(..., send_feature_flag_events=True)` path. `evaluate_flags()` previously set
`$feature_flag_id` but hardcoded `version=None` on the belief that local definitions carry no version;
they do, so the snapshot record now takes it from the definition.

Without this property, a locally evaluated `$feature_flag_called` event cannot be attributed to a flag
definition or a definition revision downstream, while the same read against the remote endpoint can be.
posthog-go still reads both properties from `evalResult.FlagDetail` only (`posthog.go`), so its locally
evaluated events omit them. Recording posthog-python's behavior as the winner states which side of that
divergence is correct.

## What Changes

- `feature-flag-called-tracker` gains a **Flag definition identity on flag-called events** requirement:
  a `$feature_flag_called` event carries `$feature_flag_id` and `$feature_flag_version` for a locally
  evaluated read as well as a remote one, taken from the local flag definition; each property is omitted
  when its source does not carry it; and a structured snapshot read records the same values on the
  locally evaluated flag record it exposes.
- The local values are read from the same definitions snapshot that produced the value, so a definitions
  refresh between evaluation and capture cannot report a different definition's identity.
- No change to any public API, to the dedupe contract, or to the minimal-event allowlist. The two
  properties were already on that allowlist, so a minimized event carries them too.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `feature-flag-called-tracker`: one added requirement.

## Impact

- **posthog-python**: already compliant.
- **posthog-go**: attaches both properties only from remote `/flags` metadata; its locally evaluated
  `$feature_flag_called` events need the definition's `id` and `version`.
- **Other server SDKs with local evaluation** (posthog-node, posthog-php, posthog-ruby, posthog-dotnet,
  posthog-java, posthog-rs, posthog-elixir): attach both properties on locally evaluated reads.
- **Client SDKs**: not applicable — they do not evaluate flags locally.
