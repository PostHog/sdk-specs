## MODIFIED Requirements

### Requirement: Warning for flags local evaluation never resolves

An SDK that evaluates flags locally SHOULD log a diagnostic warning, when the platform exposes SDK logging, for each loaded definition that local evaluation can never resolve: a flag whose unresolved reason would be `experience_continuity` or `unsupported_definition`. These causes come from the definition, so the SDK knows them when definitions load. A flag that can be unresolved only for `missing_context` or `unresolved_dependency` does not trigger the warning, because those causes depend on the call or on another flag. This applies whether or not the SDK exposes unresolved flags. An SDK that logs the warning SHALL follow the rules below.

For server SDKs, the definition-load warning SHALL exclude flags whose `evaluation_runtime` is `"client"`. This exclusion applies to both `experience_continuity` and `unsupported_definition`, for API and shared-cache loads. Flags with runtime `"server"` or `"all"`, a null runtime, or no runtime field remain eligible for the warning. SDKs SHALL retain the runtime metadata needed to make this distinction when decoding or hydrating definitions. Treating a null or absent runtime as eligible for this warning does not change "Snapshot evaluation runtime access", where a flag with an unknown runtime matches no runtime criterion.

The SDK SHALL retain client-only definitions and their normal local evaluation behavior. Suppressing this warning SHALL NOT remove definitions, change evaluation results, or prevent a caller from evaluating a client-only flag locally for browser bootstrapping.

The warning SHALL name the flag and the reason. The SDK SHALL NOT repeat the warning for the same flag until that flag's definition changes. A refresh that leaves the definition unchanged, including a not-modified response or a shared-cache load, SHALL NOT repeat it.

A server SDK SHALL stop tracking a flag as warned when its definition becomes client-only. If that flag's `evaluation_runtime` later changes to anything other than `"client"` (including null or removal of the field) and it remains unresolvable from its definition, the SDK SHALL warn again.

The warning helps a developer notice the flag early. It does not replace the per-snapshot reporting in "Snapshot unresolved flag reporting", which also covers `missing_context`.

#### Scenario Outline: Loading a definition that local evaluation never resolves logs one warning (@unresolvable_flag_warning_capable)
- **GIVEN** SDK logging is enabled
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **WHEN** local feature flag definitions are refreshed successfully using "<refresh result>"
- **THEN** exactly one warning naming "checkout" and reason "experience_continuity" should be logged
- **AND** no remote feature flag evaluation request should have been sent

  | refresh result |
  | unchanged definitions |
  | 304 not modified |
  | successful shared-cache load |

#### Scenario: A changed definition that local evaluation never resolves logs the warning again (@unresolvable_flag_warning_capable)
- **GIVEN** SDK logging is enabled
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **WHEN** local feature flag definitions are refreshed successfully with a changed definition for "checkout" that still has experience continuity enabled
- **THEN** exactly two warnings naming "checkout" and reason "experience_continuity" should be logged

#### Scenario Outline: Server definition loads do not warn about client-only flags (@unresolvable_flag_warning_capable)
- **GIVEN** SDK logging is enabled
- **AND** <definition>
- **AND** the local feature flag definition for "checkout" reports evaluation runtime "client"
- **WHEN** local feature flag definitions are refreshed successfully using "<refresh result>"
- **THEN** no warning naming "checkout" should be logged
- **AND** no remote feature flag evaluation request should have been sent

  | definition | refresh result |
  | the local feature flag definition for "checkout" has experience continuity enabled | changed definitions |
  | the local feature flag definition for "checkout" has experience continuity enabled | successful shared-cache load |
  | local feature flag definitions include a flag "checkout" matching a static cohort | changed definitions |
  | local feature flag definitions include a flag "checkout" matching a static cohort | successful shared-cache load |

#### Scenario Outline: Definitions not restricted to client runtime still log warnings (@unresolvable_flag_warning_capable)
- **GIVEN** SDK logging is enabled
- **AND** <definition>
- **AND** the local feature flag definition for "checkout" <runtime step>
- **WHEN** local feature flag definitions are refreshed successfully using "changed definitions"
- **THEN** exactly one warning naming "checkout" and reason "<reason>" should be logged
- **AND** no remote feature flag evaluation request should have been sent

  | definition | runtime step | reason |
  | the local feature flag definition for "checkout" has experience continuity enabled | reports evaluation runtime "server" | experience_continuity |
  | the local feature flag definition for "checkout" has experience continuity enabled | reports evaluation runtime "all" | experience_continuity |
  | the local feature flag definition for "checkout" has experience continuity enabled | reports evaluation runtime null | experience_continuity |
  | the local feature flag definition for "checkout" has experience continuity enabled | reports no evaluation runtime | experience_continuity |
  | local feature flag definitions include a flag "checkout" matching a static cohort | reports evaluation runtime "server" | unsupported_definition |

#### Scenario Outline: Suppressing client-only warnings preserves local evaluation (@unresolvable_flag_warning_capable)
- **GIVEN** SDK logging is enabled
- **AND** local feature flag definitions resolve "client-flag" for distinct id "user-123" as true
- **AND** the local feature flag definition for "client-flag" reports evaluation runtime "client"
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** the local feature flag definition for "checkout" reports evaluation runtime "client"
- **WHEN** local feature flag definitions are refreshed successfully using "<refresh result>"
- **AND** evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
- **THEN** the snapshot should contain "client-flag" with value true
- **AND** the snapshot unresolved flags should contain "checkout" with reason "experience_continuity"
- **AND** no warning naming "checkout" should be logged
- **AND** no remote feature flag evaluation request should have been sent

  | refresh result |
  | changed definitions |
  | successful shared-cache load |

#### Scenario: A flag returning from client-only to server runtime warns again (@unresolvable_flag_warning_capable)
- **GIVEN** SDK logging is enabled
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** the local feature flag definition for "checkout" reports evaluation runtime "server"
- **WHEN** local feature flag definitions are refreshed successfully using "changed definitions"
- **THEN** exactly one warning naming "checkout" and reason "experience_continuity" should be logged
- **WHEN** local feature flag definitions are refreshed successfully with a changed definition for "checkout" that reports evaluation runtime "client"
- **THEN** exactly one warning naming "checkout" and reason "experience_continuity" should be logged
- **WHEN** local feature flag definitions are refreshed successfully with a changed definition for "checkout" that reports evaluation runtime "server"
- **THEN** exactly two warnings naming "checkout" and reason "experience_continuity" should be logged
- **AND** no remote feature flag evaluation request should have been sent
