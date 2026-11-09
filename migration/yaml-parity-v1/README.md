# YAML parity suite v1

These features specify capture, retry, remote flag and local flag behavior. Inputs
and expected results are inline Gherkin tables and JSON doc strings. Run them with
the SDK test harness's `--migration-suite` selector, or select an individual
`--feature` or `--case-id`.

## Case identity and selection

The harness identifies each scenario by its feature path and scenario name. Keep
scenario names distinct within a feature and describe the behavior they verify.
For a Scenario Outline that needs stable per-row labels, use `@case:<case_id>`
with a `case_id` Examples column containing a distinct label for each row. The
harness substitutes that label for each execution; rows are never deduplicated.

`@requires:<capability>` tags declare necessary SDK API/feature support. All
inherited requirements apply. Put requirements on the Feature when shared by all
its scenarios, otherwise on the Scenario or an Examples group. Split Examples
groups when rows require different capabilities. Required public operations come
from the harness's step bindings, not a separate operation inventory.

Capture API declarations are independent of client/server SDK type:

- `capture_ai_v0`: AI capture delivery, including the ordinary-capture no-reroute
  case. That case accepts either legacy batch or analytics-v1 ordinary traffic.
- `capture_v1`: analytics-v1 delivery through ordinary capture.
- `capture_v0`: legacy capture; `capture_v0_batch` additionally selects the batch
  format checks, while `capture_v0_event` selects the event format checks.
- `encoding_gzip`, `encoding_deflate`, `encoding_br`, `encoding_zstd`: independent
  encoding requirements for scenarios that explicitly configure compression.

`@excludes:<capability>` tags name capabilities that replace a scenario. The
harness does not select a scenario when the SDK declares any capability it excludes.
Pair each excluded scenario with a replacement that requires the same capability.

Remote flag scenarios require `flags_v2` and `@sdk:server`. The repeated-getter
scenario additionally requires `flags_getter_remote_uncached`. An SDK that declares
`flags_response_v4` sends `?v=4` on remote `/flags` requests. That capability
replaces the `?v=2` query check with a `?v=4` check. Local flag scenarios
require `feature_flags_local_evaluation_v1` without an SDK-type restriction.
`@sdk:client` or `@sdk:server` restricts applicability when specified; no such tag
means no SDK-type restriction. Existing category tags describe behavior areas.

The `/flags?v=4` read scenarios require `flags_response_v4` and `@sdk:server`. Each
one serves a single v4 response body and makes one remote read:

- `remote-flags-v4-legacy-getter.feature`: the existing flag getter returns the
  legacy rendering of the record.
- `remote-flags-v4-legacy-payload.feature`: additionally requires
  `feature_flag_payloads`. The SDK's existing payload getter, called with the same
  arguments as the flag getter, returns the payload as a decoded JSON value.

A getter that has no value or payload may return the SDK's native undefined result
or JSON null. These two features are generated from the SDK test harness's feature
flag rules v2 contract fixtures (the reader fixtures and the value corpus). Do not
edit them by hand: change the contract in the harness and regenerate them with the
harness's `bin/update-flags-v4-features.py --specs <this checkout>`. The harness
checks that the pinned features match its contract.

Capabilities describe actual SDK support; they do not configure SDK behavior or
supply omitted arguments. Explicitly requested cases retain missing prerequisites
as gaps rather than passing or disappearing from the report.

## Observable behavior

Setup supplies only the configuration shown in each scenario and the controlled
service host. Omitted values remain omitted; null, false, zero and empty collections
remain distinct supplied inputs. Flush, reload and readiness calls are explicit
public operations. SDK defaults, retry scheduling and generated identities belong
to the SDK.

Traffic assertions observe the accumulated mock-server collection since reset,
including initialization, unless a step explicitly filters it. First-request and
first-event assertions do not imply checks on every request or event. The retry
features retain real observation intervals and check the delays stated in the
steps. Assertions about mock response bodies alone do not establish SDK handling
of those responses.

Local evaluation uses a fresh SDK, controlled definitions delivered through its
public loading path, exact conclusive getter results and no remote evaluation
requests throughout initialization, reload and evaluation. Definitions downloads
are allowed; `/flags` and `/decide` evaluation requests are not. Reload scenarios
require fresh authenticated definitions responses within the specified deadline
and assert changed values in the same SDK instance.
