## ADDED Requirements

### Requirement: The config version selects the evaluator

The local evaluator SHALL choose how to evaluate each flag definition from its `filters.version`, by the version rule of the public rules v2 contract (`config_versions` in `contracts/feature_flag_rules_v2/registries/literals.json` in posthog-sdk-test-harness):

- absent, or a JSON number equal to `1`: config version 1, which the other requirements of this spec define;
- a JSON number equal to `2`, such as `2` or `2.0`: config version 2, which `flag-rules-v2-local-evaluation` defines, in an SDK that has that capability;
- any other value, such as another number, a string, a boolean or `null`: the flag is unsupported, and local evaluation is inconclusive with the reason `unsupported_definition`.

The other requirements of this spec apply to config version 1 definitions only. The SDK SHALL NOT evaluate a definition that is not config version 1 with the config version 1 rules, on any path: single reads, bulk reads, evaluated snapshots, payload reads, and the evaluation of a flag that another flag depends on. An SDK without `flag-rules-v2-local-evaluation` treats a config version 2 definition as unsupported.

A config version 1 condition whose `flag` filter names a definition that is not config version 1 SHALL make the dependent flag inconclusive with the reason `unsupported_definition`, as a dependency with no loaded definition does. This holds whether the named flag is active or not. The flags service does not send such a dependent: a config version 1 flag may not depend on a config version 2 flag, and the definitions feeds leave out a flag whose dependency they leave out.

Why: the config version 1 rules read a config version 2 document as a flag with no conditions and return `false` as a conclusive local result. That result also stops a remote fallback from replacing it.

#### Scenario Outline: The config version selects the evaluator (@server)
- **GIVEN** the definition of "checkout" has `filters.version` <version>
- **WHEN** "checkout" is evaluated locally
- **THEN** it is evaluated <outcome>

  | version | outcome |
  | absent | by the config version 1 rules |
  | `1` | by the config version 1 rules |
  | `2` | by the config version 2 evaluator, in an SDK that has one; otherwise it is inconclusive with the reason `unsupported_definition` |
  | `2.0` | by the config version 2 evaluator, in an SDK that has one; otherwise it is inconclusive with the reason `unsupported_definition` |
  | `3` | not at all: it is inconclusive with the reason `unsupported_definition` |
  | `"2"` | not at all: it is inconclusive with the reason `unsupported_definition` |
  | `null` | not at all: it is inconclusive with the reason `unsupported_definition` |

#### Scenario: A config version 2 document never reaches the config version 1 rules (@server)
- **GIVEN** an SDK without a config version 2 evaluator holds a definition of "layout-preview" with `filters.version` 2 and no `groups`
- **WHEN** "layout-preview" is read
- **THEN** local evaluation is inconclusive with the reason `unsupported_definition`
- **AND** the read does not return `false` as a local result

#### Scenario: A config version 1 flag that depends on a config version 2 flag is inconclusive (@server)
- **GIVEN** the config version 1 flag "legacy-dependent" has a condition with a `flag_evaluates_to` filter on the config version 2 flag "layout-preview"
- **WHEN** "legacy-dependent" is evaluated locally
- **THEN** local evaluation is inconclusive with the reason `unsupported_definition`
- **AND** "layout-preview" is not evaluated with the config version 1 rules
