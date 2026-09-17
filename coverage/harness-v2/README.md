# Harness v2 source coverage baseline

This directory owns the shared phase-1 expectation inventory. It is not an executable
scenario format, a reviewed migration-parity receipt, or an SDK run report.
See [SUMMARY.md](SUMMARY.md) for generated counts and the next gate.

## Inputs and identity

- SDK specs: `9cb330e3bac8868f39cc7dd665e42817285c9493`.
- Legacy harness: `029a94a3861c79f5e99d656b03648ba903eb6e7e`.
- Selected catalog: the byte-for-byte discovery input in
  `inputs/public-rpc-catalog.txt`, SHA-256
  `ac8165c607ea0d15e924d3984e4da49d68cdcb77d1d2fe8de18da142603870e3`.
  Its original location is `sdk-specs/notes/public-rpc-catalog.md`; relative links
  in that snapshot refer to sibling notes there. This frozen documentary evidence
  is not the versioned invocation/configuration schema due in phase 2.
- [source-selection.json](source-selection.json) records the refreshed remote heads
  and the deliberate decision to retain the plan's pins.

The generator reads **Git objects at those pins**, never moving worktree contents.
Gherkin IDs use the original revision, path and declaration line; examples append
the original example-row line. YAML IDs use the revision, suite, category and case
name; assertion IDs append the ordered step number. These are frozen origin IDs,
not identifiers to recompute when executable cases move. Renamed/regrouped cases
must retain these origin IDs in their mapping, or record explicit replacement IDs
and review evidence. Do not point this generator at new pins and silently replace
the baseline. Compiler-generated AST IDs are not persisted as identities.

## Reproduce and validate

Requires Git, uv and Python >=3.12. Supply repositories containing the pinned Git
objects; their current branches and uncommitted files do not affect discovery.
From the specs repository:

```sh
uv run --locked coverage/harness-v2/inventory.py --harness-repo /path/to/harness
uv run --locked coverage/harness-v2/inventory.py --harness-repo /path/to/harness --check
cd coverage/harness-v2
uv run --no-project --with gherkin-official==39.0.0 --with PyYAML==6.0.3 python -m unittest -v test_inventory
```

`--check` performs full regeneration in memory and exits nonzero for any missing or
changed generated artifact. Input hashes, duplicate identities, empty outlines and
pin count mismatches also fail discovery. No SDK or adapter is started.

## Files and interpretation

| File | Content |
| --- | --- |
| `manifest.json` | Source revisions/digests, parser versions, counts and generated ledger digests. |
| `gherkin-declarations.jsonl` | All 395 source declarations, including complete example tables and locations. |
| `shared-cases.jsonl` | All 728 compiled cases; expanded background/outline steps, arguments, tags, source lines, requirement candidates, fixture/applicability/binding backlog. |
| `legacy-cases.jsonl` | All 157 cases and 1,066 ordered steps, complete inputs/definitions, inherited capability filters and direct adapter call sites. |
| `legacy-actions.jsonl` | Pinned action implementations, assertion branch sites, SDK calls and helper semantics, including compound capture loops, init defaults and reset. |
| `migration-crosswalk.jsonl` | 375 explicit assertion-action predicates and 143 helper-embedded assertion groups, each linked to the original ordered case. |
| `catalog-routes.jsonl` | All 180 routes with exact catalog argument/result/behavior columns, candidate case IDs and untested behavior. |
| `catalog-config.jsonl` | All 143 configuration paths, including parent records and nested fields; textual candidates and untested dimensions. |
| `mapping-notes.json` | Authored discovery notes for the initial flush slice and legacy candidates. Validated references are merged into generated ledgers. |

Gherkin parsing and outline expansion use the official Cucumber implementation.
Table cells remain Gherkin strings, and doc strings retain their source media type
and text; phase 2 will define typed step interpretation. YAML loading matches the
legacy SafeLoader semantics, including aliases and omission/null/false/zero. This
migration-only dependency does not add a YAML execution path to harness v2.

An assertion action can contain multiple checks or conditional failure branches;
its parameters and implementation sites are retained together, not counted as
independent runtime passes. In particular, local-only flag reads and definition
reload helpers assert behavior even though their action names do not start with
`assert_`. The four local-evaluation cases retain every ordered evaluation and
snapshot, not merely their four titles. Action calls are static call **sites**,
not claimed dynamic invocation counts. Fixture/adapter side effects remain linked
to pinned context, interface, contract and action source; phase 5 must audit them.
Server-authored response checks must not be treated as proof of SDK handling.

## Mapping gate

`unresolved` is a discovery state. Later reviewed dispositions are `covered`,
`extend existing scenario`, `new scenario`, and `superseded by reviewed target decision`.
A covered entry needs concrete target case/assertion links and input, sequencing,
fixture and applicability equivalence evidence. Supersession needs a reviewed
target decision. Counts, shared titles and matching API names are not such evidence.

Catalog feature-index links intentionally remain candidates, including the catalog's
older pinned requirement links. Per-case requirement sources use the selected specs
revision. Configuration text hits are only search aids. Neither candidate list is a
coverage numerator. Missing candidates do not prove missing behavioral coverage.

Public/private feature folders describe source organization, not execution layers.
Queue state and other internal observations require public observations or genuine
component fixtures. Source tags remain intact; translating them into runtime,
identity, protocol and product profiles is unresolved rather than silently filtering
cases out for Node. No conformance or net-new-coverage count is reported.
