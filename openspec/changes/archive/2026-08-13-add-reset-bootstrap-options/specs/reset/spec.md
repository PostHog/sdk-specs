# Reset Delta: Bootstrap Options

## ADDED Requirements

### Requirement: Reset MAY accept bootstrap options to seed the next identity

A client SDK MAY implement this extension; if it does, it MUST accept an options form of `reset`
that carries a `bootstrap` object (the same shape documented by the `bootstrap` capability:
`distinctId`/`isIdentifiedId`, `featureFlags`, `featureFlagPayloads`, and — for SDKs with a session
manager — `sessionID`), alongside the existing device-id-rotation toggle. This is an allowed,
SDK-specific extension, mirroring how the `bootstrap` capability already documents its own optional
`sessionID` extension as applicable only to SDKs that support it.

When a `bootstrap` object is supplied to `reset`, the SDK SHALL apply it after the reset completes:
seeding the new anonymous or identified distinct id, serving the given feature flags and payloads
immediately, and adopting the given session id, following the same semantics as bootstrap-at-setup
(see the `bootstrap` capability) rather than requiring the caller to reload the page or process to
apply server-provided values for the next identity. When `reset` is called without a `bootstrap`
option (including the legacy boolean form), it SHALL continue to behave exactly as the existing
`Canonical reset behavior` requirement describes — a fresh, un-seeded anonymous identity.

#### Scenario: Reset applies a caller-supplied anonymous distinct id
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **WHEN** reset is called with bootstrap distinct id "custom-anon-id" and identified state false
- **THEN** get distinct id should return "custom-anon-id"

#### Scenario: Reset without bootstrap options behaves as the canonical reset
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **WHEN** reset is called with no bootstrap option
- **THEN** get distinct id should not return "user-123"
- **AND** the new distinct id should not be a previously caller-supplied value
