## Context

The archived `add-session-replay-debug-properties` design recorded six decisions. This change
keeps 1 (buffering spans both mobile holds), 3 (posthog-js's trigger value set), 5 (session keys
follow the event's own `$session_id`) and 6 (a previous-process crash carries no live state). It
revises 2 (how trigger state reaches events) and 4 (the counters follow-up, which stays closed
except for four drop counters on `$snapshot`). The decisions below
cover what the delta doesn't make obvious on its own.

## Decisions

### 1. Two tiers: required keys and an optional bundle, with the queue depth outside both

posthog-js#5144 keeps `REQUIRED_REPLAY_PROPERTIES` on every event and throttles the rest.
Mobile SDKs port the same shape. The spec names the tiers once,
in the attach requirement, and every other requirement uses those names. The key list labels
each key with its tier, so nobody has to work it out per key. The required set is what the
recording buttons and the capture diagnostics read from individual events. The shared part is
the status, both trigger statuses, and the replay buffer length. The browser adds four keys that
only it produces. The queue depth stays outside both tiers because it is the one key support
reads on ordinary custom events: a stuck queue explains missing events.

### 2. Gate the optional bundle by event name, decided before `beforeSend`

posthog-js gates on "name starts with `$`" minus a short denylist: `$feature_flag_called` and
`$snapshot`, plus `$$heatmap` on the browser. An allowlist would silently leave out any SDK event
added later. It also decides eligibility on the name passed to capture, not on the name
`before_send` returns: it tests `event_name` both when it builds the event and when it arms the
window. A mobile port needs its own way to carry that decision across `beforeSend`. The spec
states both rename cases explicitly so a port can't pick the other reading.

### 3. The window starts at acceptance and runs on the wall clock

posthog-js arms its 30-second timer after `before_send` returns, and only for an event that
passed it. A mobile port that stamped the window when it built the properties would let time
spent in `beforeSend` shorten the window, and an event timestamp in the future could hold the
window shut if the window were compared against the event's timestamp. The spec therefore says
the window starts when the carrying event is accepted into the send queue, and is measured
against the wall clock, not the event's timestamp. An event dropped by `beforeSend`,
deduplicated, or not stored does not start it. The spec allows either mechanism, a timer or a
stored acceptance time. A backdated capture neither attaches the bundle outside the wall-clock
rule nor moves the window, because the event's timestamp takes no part.

### 4. One outstanding claim is a SHOULD, not a MUST

Holding at most one outstanding claim means an eligible event captured from inside
`beforeSend`, or at the same moment on another thread, does not also get the bundle. posthog-js
sets its paused flag only after `before_send` returns, so a nested capture there gets the bundle
as well. Making this a MUST would put the flagship SDK out of conformance for something that
costs one extra bundle per nested capture, which is minor. The spec therefore makes it a SHOULD,
and names the posthog-js gap. A port that does hold a claim must not expire it by age: a claim
that lapsed after 30 seconds would let a capture nested in a slow `beforeSend` carry the bundle
too, which is the case the claim exists to prevent. Every exit from a claiming capture starts
the window or releases the claim instead. The
repo's convention is to describe reference behavior, so any stronger rule has to come after
posthog-js closes the gap.

### 5. Capture mode is mobile-only and optional

posthog-js has no capture-mode key, so its lists can't say which tier the key belongs in. Nothing
reads it from individual events, so it belongs in the optional bundle. The spec states that
classification outright, along with the only two values and the derivation:
`screenshot` when screenshot mode is on or the host SDK is `posthog-flutter`, otherwise
`wireframe`. Android and Flutter then have nothing to guess. The key comes from configuration,
so it survives stop and uninstall, and it stays in the crash-context snapshot.

### 6. Trigger statuses become required on both platforms, still not as super properties

The trigger keys could have moved into the throttled bundle, but #5144 puts both trigger
statuses in `REQUIRED_REPLAY_PROPERTIES`. They still reach events through
`SessionRecording.sdkDebugProperties` reading back `hidden` session persistence, not as super
properties. iOS computes them fresh on each build. The spec keeps that difference in how the
value is produced and adds one shared rule: the keys reach events only through the debug merge.
Pending trigger conditions stay optional on both platforms.

### 7. Unconfigured replay: mobile keeps `disabled` on every event, the browser attaches nothing

Without an integration, a mobile SDK still has a fallback map: `$recording_status: disabled`,
plus capture mode where the platform ships the replay module, and a session start. The spec
keeps only the status on ordinary events, so every mobile event says replay was off, which is the
OOM-triage case this spec was written for. Capture mode and session start come along only with
the optional bundle. posthog-js attaches no
replay key without the session-recording extension. With the extension present but not started,
it attaches `$recording_status: 'disabled'`, and the "returns calculated properties" test asserts
that for a custom event. The spec states the mobile rule as the requirement and the browser
behavior as a named divergence.

### 8. The counters follow-up is closed, except four drop counters on `$snapshot`

The original design deferred the rrweb performance counters to a later
`session-replay-debug-counters` change. #5144 removed most of them from captured events, so no
platform emits those and the out-of-scope requirement says so. `$sdk_debug_current_session_duration`
and `$sdk_debug_replay_throttle_delay_ms` are removed the same way.

Four drop counters survive. They count replay data the recorder discarded: unstringifiable events,
throttled attribute mutations, and oversized mutations with their bytes. A drop does nothing
visible to the page, and the recording quietly loses data, so the count has to ship. #5144 sends
them on `$snapshot` events only, each only while above zero, outside the 30-second window, and
resets them on session rotation. The spec gives them their own requirement instead of widening the
optional bundle, because they never ride on the events the bundle rides on, and `$snapshot` still
carries no required, optional, or queue-depth key. They are browser-only as implemented and iOS has
no analog, so the spec says a mobile SDK that omits them conforms and does not ask Android or
Flutter to add them.

### 9. Citations: posthog-js at a merged pin, posthog-ios only for existing behavior

The posthog-js citations point at `origin/main` `928990ded`, which contains #5144. The spec cites
posthog-ios `origin/main` `88f4b6b56` only for behavior already there. Rules with no posthog-js
analog and no mobile code yet are stated as the contract, and their mobile tests are marked
planned. The change is applied and archived in one PR, as `AGENTS.md` requires, and mobile
adoption is tracked as downstream follow-up in `tasks.md`.
