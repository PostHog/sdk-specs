## Why

The `capture` requirement "Client-level GeoIP control with per-call override" is written for server
SDKs and says only that client SDKs "SHALL NOT require the option". Three client SDKs now ship one,
with behavior the spec does not describe:

- posthog-ios has shipped `PostHogConfig.disableGeoIp` (default `false`).
- posthog-android added `PostHogConfig.disableGeoIp` in PostHog/posthog-android#971 (merged
  2026-11-13, released in android-v3.77.0).
- posthog-flutter added `disableGeoIp` in PostHog/posthog-flutter#720 (merged 2026-11-14), forwarding
  to the native option on iOS/Android and handling it in the Dart core on desktop.

posthog-js's core (node, react-native) already carries `disableGeoip` with a stateful default of
`false`; its browser package has none and points callers at `before_send`.

The client behavior is consistent enough to state as a contract — default off, marker stamped after
the caller's properties but before `beforeSend`, `geoip_disable` on the flags request, no per-call
override — and the one real divergence (Flutter's stamp ordering, and Flutter web) is worth recording.

## What Changes

- **Capture**: modify "Client-level GeoIP control with per-call override" so its client sentence
  points at the new requirement instead of only saying the option is not required.
- **Capture**: add "Client SDK GeoIP opt-out", describing the optional client-level option, its
  default, marker precedence over caller properties, `beforeSend` ordering, `$snapshot` and
  `$set`/`$set_once`/`$group_set` exclusions, minimized `$feature_flag_called` retention, the flags
  request field, and the absence of a per-call override. Five scenarios.
- Not breaking. No currently shipped client SDK changes behavior under this requirement.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: state the client-side GeoIP opt-out contract.

## Impact

Specifications only. Conformant today: posthog-ios, posthog-android (>= 3.77.0), posthog-flutter
(with the recorded stamp-ordering and web divergences), posthog-js core for react-native. Client SDKs
without the option (posthog-js browser, posthog-unity, posthog-kmp, posthog-godot) stay conformant
because the option is optional.
