## Context

The archived `add-session-replay-debug-properties` design recorded six decisions. This change
keeps 1 (buffering spans both mobile holds), 3 (posthog-js's trigger value set), 5 (session keys
follow the event's own `$session_id`) and 6 (a previous-process crash carries no live state). It
revises 2 (how trigger state reaches events) and 4 (the counters follow-up). The decisions below
cover what the delta doesn't make obvious on its own.

## Decisions

### 1. Two tiers: required keys and an optional bundle, with the queue depth outside both

posthog-js#5144 keeps `REQUIRED_REPLAY_PROPERTIES` on every event and throttles the rest.
posthog-ios#859 copies that with `requiredReplayDebugPropertyKeys`. The spec names the tiers once,
in the attach requirement, and every other requirement uses those names. The key list labels
each key with its tier, so nobody has to work it out per key. The required set is what the
recording buttons and the capture diagnostics read from individual events. The shared part is
the status, both trigger statuses, and the replay buffer length. The browser adds four keys that
only it produces. The queue depth stays outside both tiers because it is the one key support
reads on ordinary custom events: a stuck queue explains missing events.

### 2. Gate the optional bundle by event name, decided before `beforeSend`

Both references gate on "name starts with `$`" minus a short denylist: `$feature_flag_called`
and `$snapshot`, plus `$$heatmap` on the browser. An allowlist would silently leave out any SDK
event added later. Both also decide eligibility on the name passed to capture, not on the name
`beforeSend` returns. posthog-js tests `event_name` both when it builds the event and when it
arms the window. iOS stores the claim on `PostHogEvent`, so it survives a rename. The spec states
both rename cases explicitly so a port can't pick the other reading.

### 3. The window starts at acceptance and runs on the wall clock

posthog-js arms its 30-second timer after `before_send` returns, and only for an event that
passed it. iOS originally stamped the window when it built the properties and compared that
against the event's timestamp. Review of #859 found two problems with that. Time spent in
`beforeSend` shortened the window. A future-dated capture could also hold the window shut. At
`fda0e238c`, iOS stamps the window with `now()` when a claiming event is stored, and releases the
claim when the event is dropped, deduplicated, or not stored. The spec states that behavior and
allows either mechanism, a timer or a stored acceptance time. The earlier draft's rule that a
backdated capture neither attaches nor moves the window is gone, because the event's timestamp
no longer takes part.

### 4. One outstanding claim is a SHOULD, not a MUST

iOS refuses a new claim while one is outstanding. So an eligible event captured from inside
`beforeSend`, or at the same moment on another thread, does not also get the bundle. posthog-js
sets its paused flag only after `before_send` returns, so a nested capture there gets the bundle
as well. Making this a MUST would put the flagship SDK out of conformance for something that
costs one extra bundle per nested capture, which is minor. The spec therefore makes it a SHOULD,
names the posthog-js gap, and lets a port treat a claim older than the interval as leaked, as
iOS does. The repo's convention is to describe reference behavior, so any stronger rule has to
come after posthog-js closes the gap.

### 5. Capture mode is mobile-only and optional

posthog-js has no capture-mode key, so its lists can't say which tier the key belongs in. iOS
leaves it out of `requiredReplayDebugPropertyKeys`, so it rides in the optional bundle. The spec
states that classification outright, along with the only two values and the derivation:
`screenshot` when screenshot mode is on or the host SDK is `posthog-flutter`, otherwise
`wireframe`. Android and Flutter then have nothing to guess. The key comes from configuration,
so it survives stop and uninstall, and it stays in the crash-context snapshot.

### 6. Trigger statuses become required on both platforms, still not as super properties

The earlier draft moved the trigger keys into the throttled bundle. #5144 puts both trigger
statuses in `REQUIRED_REPLAY_PROPERTIES`. They still reach events through
`SessionRecording.sdkDebugProperties` reading back `hidden` session persistence, not as super
properties. iOS computes them fresh on each build. The spec keeps that difference in how the
value is produced and adds one shared rule: the keys reach events only through the debug merge.
Pending trigger conditions stay optional on both platforms.

### 7. Unconfigured replay: mobile keeps `disabled` on every event, the browser attaches nothing

Without an integration, iOS's fallback map is `$recording_status: disabled` plus capture mode on
iOS and a session start. The required-key filter keeps only the status on ordinary events. So
every mobile event says replay was off, which is the OOM-triage case this spec was written for.
Capture mode and session start come along only with the optional bundle. posthog-js attaches no
replay key without the session-recording extension. With the extension present but not started,
it attaches `$recording_status: 'disabled'`, and the "returns calculated properties" test asserts
that for a custom event. The spec states the mobile rule as the requirement and the browser
behavior as a named divergence.

### 8. The counters follow-up is closed

The original design deferred the rrweb performance counters to a later
`session-replay-debug-counters` change. #5144 removed them from captured events, so no platform
emits them and the out-of-scope requirement says so. `$sdk_debug_current_session_duration` and
`$sdk_debug_replay_throttle_delay_ms` are removed the same way.

### 9. posthog-js citations are merged; iOS citations wait for a re-pin

The posthog-js citations point at `origin/main` `928990ded`, which contains #5144. posthog-ios#859
is still open, so its citations name the head SHA `fda0e238c`. `tasks.md` keeps an open task to
re-pin them after the merge. The change is still applied and archived in this PR, as `AGENTS.md`
requires. Only the iOS line numbers are provisional.
