# /// script
# requires-python = ">=3.12"
# dependencies = ["gherkin-official==39.0.0", "PyYAML==6.0.3"]
# ///
"""Generate the frozen phase-1 discovery ledger, not a conformance report."""
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess

from gherkin.parser import Parser
from gherkin.pickles.compiler import Compiler
import yaml

ROOT = Path(__file__).resolve().parent
SPECS_PIN = "9cb330e3bac8868f39cc7dd665e42817285c9493"
HARNESS_PIN = "029a94a3861c79f5e99d656b03648ba903eb6e7e"
CATALOG_HASH = "ac8165c607ea0d15e924d3984e4da49d68cdcb77d1d2fe8de18da142603870e3"


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args]).decode()


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def source(revision, path, line=1):
    return {"revision": revision, "path": path, "line": line}


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def clean_ast(value):
    if isinstance(value, dict):
        return {k: clean_ast(v) for k, v in value.items() if k not in {"id", "astNodeIds", "astNodeId"}}
    if isinstance(value, list):
        return [clean_ast(v) for v in value]
    return value


def catalog_inventory(text):
    if digest(text) != CATALOG_HASH:
        raise ValueError("Selected catalog digest changed; select and review a new baseline explicitly")
    routes = []
    for line_no, line in enumerate(text.splitlines(), 1):
        if re.match(r"\| `/[^`]+` \|", line):
            cells = [s.strip() for s in line.strip("|").split("|")]
            routes.append({"route": cells[0].strip("`"), "arguments": cells[1],
                           "result": cells[2], "behavior": cells[3], "catalog_line": line_no})
    # This extracts fields from the frozen, flat TS interface declarations, not
    # a general TS parser or a request validator. Digest and counts fail closed.
    interfaces = {}
    for match in re.finditer(r"interface (\w+) \{([^{}]*)\}", text):
        fields = []
        for field in re.finditer(r"(\w+)\??:\s*([^;]+?)(?:;|\s*$)", match[2]):
            line = text[:match.start(2) + field.start()].count("\n") + 1
            fields.append((field[1], field[2], line))
        interfaces[match[1]] = fields
    configs = []

    def expand(name, prefix):
        for field, field_type, line in interfaces[name]:
            path = prefix + "." + field
            configs.append({"path": path, "type": field_type, "catalog_line": line})
            for nested in re.findall(r"\b\w+\b", field_type):
                if nested in interfaces:
                    expand(nested, path)
    expand("SetupConfig", "config")
    index = {}
    for line in text.split("## 8. Requirement and fixture index", 1)[1].splitlines():
        if "| [spec](" in line:
            cells = [s.strip() for s in line.strip("|").split("|")]
            index[cells[0]] = {"discovery_text": cells[1],
                               "candidate_routes": re.findall(r"`(/[^`]+)`", cells[1]),
                               "catalog_requirement": re.search(r"\((https://[^)]+)\)", cells[2])[1]}
    if len(routes) != 180 or len(configs) != 143:
        raise ValueError(f"Catalog counts changed: {len(routes)} routes, {len(configs)} configs")
    if len({r['route'] for r in routes}) != 180 or len({c['path'] for c in configs}) != 143:
        raise ValueError("Duplicate catalog identities")
    return routes, configs, index


def gherkin_inventory(files, read, index):
    declarations, cases = [], []
    for path in files:
        document = Parser().parse(read("specs", path))
        document["uri"] = path
        nodes = {n["id"]: n for n in walk(document) if "id" in n}
        feature = document["feature"]
        capability = Path(path).stem.replace("_", "-")
        requirement_path = f"openspec/specs/{capability}/spec.md"
        requirement = read("specs", requirement_path)
        headings = [{"text": m[1], "line": requirement[:m.start()].count("\n") + 1}
                    for m in re.finditer(r"^### Requirement: (.+)$", requirement, re.M)]
        ids = {}
        for node in walk(feature):
            if "examples" not in node:
                continue
            sid = f"gherkin:{SPECS_PIN[:7]}:{path}:L{node['location']['line']}"
            ids[node["id"]] = sid
            declarations.append({"id": sid, "source": source(SPECS_PIN, path, node["location"]["line"]),
                                 "declaration": clean_ast(node)})
        for pickle in Compiler().compile(document):
            sid = ids[pickle["astNodeIds"][0]]
            example = nodes[pickle["astNodeIds"][1]] if len(pickle["astNodeIds"]) > 1 else None
            cid = sid + (f":example-L{example['location']['line']}" if example else "")
            steps = []
            for step in pickle["steps"]:
                steps.append({**clean_ast(step), "source": source(SPECS_PIN, path,
                             nodes[step["astNodeIds"][0]]["location"]["line"])})
            discovery = index.get(capability, {})
            cases.append({"id": cid, "declaration_id": sid, "source": source(SPECS_PIN, path, pickle["location"]["line"]),
                          "name": pickle["name"], "example": clean_ast(example),
                          "tags": [t["name"] for t in pickle["tags"]], "steps": steps,
                          "target_requirement": {"source": source(SPECS_PIN, requirement_path),
                              "candidate_headings": headings, "status": "unresolved",
                              "blocker": "Select exact requirement clauses and reconcile selected catalog semantics"},
                          "rpcs": {**discovery, "status": "unresolved",
                              "blocker": "Catalog feature index is navigation; ordered step-to-RPC bindings need phase 2/4 review"},
                          "fixture_needs": {"status": "unresolved", "context_step_indexes": [i for i, s in enumerate(steps) if s["type"] == "Context"],
                              "blocker": "Separate SDK setup from clock/storage/network/host stimuli and select genuine observations"},
                          "execution_layer": {"source_surface": path.split('/')[1], "status": "unresolved",
                              "blocker": "Public feature location does not prove public observability; assign public-boundary or native-component fixture per assertion"},
                          "applicability": {"status": "unresolved", "blocker": "Translate source tags into runtime, identity, protocol and product dimensions; no Node exclusions inferred"},
                          "binding_status": "not_implemented", "validation_evidence": []})
    return declarations, cases


class LocatedDict(dict):
    line: int


class LocatedLoader(yaml.SafeLoader):
    pass


def mapping(loader, node):
    loader.flatten_mapping(node)
    result = LocatedDict(loader.construct_pairs(node, deep=True))
    result.line = node.start_mark.line + 1
    return result


LocatedLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, mapping)


def action_inventory(text):
    actions = {}
    for cls in ast.parse(text).body:
        if not isinstance(cls, ast.ClassDef):
            continue
        names = [n.value.value for method in cls.body if isinstance(method, ast.FunctionDef) and method.name == "name"
                 for n in ast.walk(method) if isinstance(n, ast.Return) and isinstance(n.value, ast.Constant)]
        if not names:
            continue
        checks = []
        calls = []
        for node in ast.walk(cls):
            is_raise = (isinstance(node, ast.Raise) and isinstance(node.exc, ast.Call)
                        and isinstance(node.exc.func, ast.Name) and node.exc.func.id == "AssertionError")
            if isinstance(node, ast.Assert) or is_raise:
                checks.append({"line": node.lineno, "code": ast.get_source_segment(text, node)})
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                receiver = ast.unparse(node.func.value)
                if receiver == "ctx.sdk_adapter" or (receiver == "ctx" and node.func.attr == "reset"):
                    calls.append({"line": node.lineno, "code": ast.get_source_segment(text, node)})
        actions[names[0]] = {"name": names[0], "source": source(HARNESS_PIN, "src/posthog_test_harness/actions.py", cls.lineno),
                             "end_line": cls.end_lineno, "assertion_sites": sorted(checks, key=lambda c: c['line']),
                             "adapter_call_sites": sorted(calls, key=lambda c: c['line']),
                             "implementation": ast.get_source_segment(text, cls)}
    return actions


def yaml_inventory(read, actions):
    contract = read("harness", "CONTRACT.yaml")
    suites = re.findall(r"^  (\w+): !include (contracts/[^\s]+tests.yaml)$", contract, re.M)
    cases, assertions = [], []
    for suite, path in suites:
        definition = yaml.load(read("harness", path), Loader=LocatedLoader)
        for category, group in definition["categories"].items():
            for case in group["tests"]:
                cid = f"yaml:{HARNESS_PIN[:7]}:{suite}:{category}:{case['name']}"
                steps = []
                for i, step in enumerate(case["steps"]):
                    action = actions[step["action"]]
                    step_id = f"{cid}:step-{i + 1}"
                    steps.append({"id": step_id, "source": source(HARNESS_PIN, path, step.line),
                                  "input": step, "action_definition": action['name'],
                                  "adapter_call_sites": action["adapter_call_sites"],
                                  "kind": "assertion" if step["action"].startswith("assert_") else
                                          "sdk_interaction" if action["adapter_call_sites"] else "fixture"})
                    # Explicit assertion actions can contain several checks/branches.
                    # Keep that predicate intact, with every internal assertion site.
                    if step["action"].startswith("assert_") or action["assertion_sites"]:
                        assertions.append({"id": step_id + ":assertion", "case_id": cid, "step_id": step_id,
                            "source": source(HARNESS_PIN, path, step.line), "action": step["action"],
                            "params": step.get("params", {}), "assertion_sites": action["assertion_sites"],
                            "kind": "explicit" if step["action"].startswith("assert_") else "helper_embedded",
                            "disposition": "unresolved", "target_case_ids": [], "evidence": [],
                            "blocker": "Compare full predicate, inputs, sequencing, filters and helper semantics against Gherkin; no equivalence inferred from titles"})
                cases.append({"id": cid, "source": source(HARNESS_PIN, path, case.line), "suite": suite,
                    "category": category, "name": case["name"], "description": case.get("description"),
                    "source_metadata": {k: v for k, v in case.items() if k != "steps"},
                    "capability_filters": {"suite_requires": definition.get("requires"),
                        "test_requires": case.get("requires"), "sdk_types": case.get("sdk_types", [])},
                    "fixture_step_ids": [s["id"] for s in steps if s["kind"] == "fixture"],
                    "steps": steps})
    return cases, assertions


def apply_notes(shared, assertions, notes):
    for key, rows in [('shared_cases', shared), ('assertions', assertions)]:
        by_id = {row['id']: row for row in rows}
        for identity, fields in notes[key].items():
            if identity not in by_id:
                raise ValueError(f'Unknown annotation identity: {identity}')
            allowed = {'inventory_notes'} if key == 'shared_cases' else {'candidate_case_ids', 'blocker', 'evidence'}
            if not set(fields) <= allowed:
                raise ValueError(f'Unsupported annotation fields: {identity}')
            for candidate in fields.get('candidate_case_ids', []):
                if candidate not in {c['id'] for c in shared}:
                    raise ValueError(f'Unknown candidate case: {candidate}')
            by_id[identity].update(fields)


def jsonl(rows):
    return ''.join(json.dumps(row, sort_keys=True, ensure_ascii=False) + '\n' for row in rows)


def build(specs_repo, harness_repo):
    sources = {}

    def read(which, path):
        revision, repo = (SPECS_PIN, specs_repo) if which == "specs" else (HARNESS_PIN, harness_repo)
        text = git(repo, "show", f"{revision}:{path}")
        sources[f"{which}:{path}"] = {"revision": revision, "path": path, "sha256": digest(text)}
        return text

    catalog = (ROOT / "inputs/public-rpc-catalog.txt").read_text()
    routes, configs, index = catalog_inventory(catalog)
    files = [p for p in git(specs_repo, "ls-tree", "-r", "--name-only", SPECS_PIN, "acceptance").splitlines() if p.endswith('.feature')]
    declarations, shared = gherkin_inventory(files, read, index)
    actions = action_inventory(read("harness", "src/posthog_test_harness/actions.py"))
    legacy, assertions = yaml_inventory(read, actions)
    annotations_text = (ROOT / 'mapping-notes.json').read_text()
    apply_notes(shared, assertions, json.loads(annotations_text))
    # Preserve data inputs as pinned provenance, without republishing corpora.
    for path in git(specs_repo, "ls-tree", "-r", "--name-only", SPECS_PIN, "acceptance").splitlines():
        if not path.endswith('.feature'):
            read("specs", path)
    for path in ["contracts/adapter_actions.yaml", "contracts/test_actions.yaml", "src/posthog_test_harness/contract.py",
                 "src/posthog_test_harness/tests/context.py", "src/posthog_test_harness/tests/suites/contract_suite.py",
                 "src/posthog_test_harness/sdk_adapter/interface.py"]:
        read("harness", path)
    for row in routes:
        row.update({"candidate_case_ids": [c["id"] for c in shared if row['route'] in c['rpcs'].get('candidate_routes', [])],
                    "covered_case_ids": [], "status": "unresolved", "validation_evidence": [],
                    "untested_behavior": row["behavior"],
                    "blocker": "No reviewed case-level proof of arguments, results, defaults or completion; feature index candidates are not coverage"})
    for row in configs:
        # Exact textual occurrence is only a search aid, never coverage evidence.
        row.update({"text_candidate_case_ids": [c['id'] for c in shared if row['path'] in json.dumps(c['steps'])],
                    "covered_case_ids": [], "status": "unresolved", "validation_evidence": [],
                    "untested_behavior": ["omitted/default", "supplied values", "null/empty distinctions", "invalid values", "lifecycle effects"],
                    "blocker": "Review configuration-specific behavior and fixture support; text occurrence does not establish a behavioral assertion"})
    counts = {"feature_files": len(files), "public_files": sum('/public/' in f for f in files),
              "private_files": sum('/private/' in f for f in files), "declarations": len(declarations),
              "outlines": sum(d['declaration']['keyword'] == 'Scenario Outline' for d in declarations),
              "expanded_cases": len(shared), "outline_examples": sum(c['example'] is not None for c in shared),
              "yaml_cases": len(legacy), "yaml_steps": sum(len(c['steps']) for c in legacy),
              "yaml_suites": dict(Counter(c['suite'] for c in legacy)),
              "explicit_assertion_actions": sum(a['kind'] == 'explicit' for a in assertions),
              "helper_assertion_actions": sum(a['kind'] == 'helper_embedded' for a in assertions),
              "crosswalk_unresolved": len(assertions), "routes": len(routes), "configuration_paths": len(configs)}
    expected = {"feature_files": 60, "public_files": 40, "private_files": 20, "declarations": 395,
                "outlines": 49, "yaml_cases": 157, "yaml_steps": 1066,
                "yaml_suites": {"capture": 33, "capture_v1": 98, "capture_ai": 5, "feature_flags": 17, "feature_flags_local_evaluation": 4}}
    for key, value in expected.items():
        if counts[key] != value:
            raise ValueError(f"Pin reconciliation failed for {key}: {counts[key]} != {value}")
    for rows in [declarations, shared, legacy, assertions]:
        if len({r['id'] for r in rows}) != len(rows):
            raise ValueError("Duplicate source identity")
    if {c['declaration_id'] for c in shared} != {d['id'] for d in declarations}:
        raise ValueError("Unexpanded declaration (including an empty outline)")
    outputs = {"gherkin-declarations.jsonl": jsonl(declarations), "shared-cases.jsonl": jsonl(shared),
               "legacy-cases.jsonl": jsonl(legacy), "migration-crosswalk.jsonl": jsonl(assertions),
               "legacy-actions.jsonl": jsonl(list(actions.values())),
               "catalog-routes.jsonl": jsonl(routes), "catalog-config.jsonl": jsonl(configs)}
    manifest = {"schema_version": 1, "purpose": "frozen source discovery; not semantic parity or runtime conformance",
                "specs_revision": SPECS_PIN, "harness_revision": HARNESS_PIN, "catalog_sha256": CATALOG_HASH,
                "mapping_notes_sha256": digest(annotations_text),
                "tool_versions": {"gherkin-official": "39.0.0", "PyYAML": "6.0.3"},
                "counts": counts, "sources": list(sources.values()),
                "generated_sha256": {name: digest(content) for name, content in outputs.items()}}
    outputs['manifest.json'] = json.dumps(manifest, indent=2, sort_keys=True) + '\n'
    outputs['SUMMARY.md'] = summary(counts, routes)
    return outputs


def summary(counts, routes):
    rows = '\n'.join(f"| {k} | {v} |" for k, v in counts.items() if not isinstance(v, dict))
    suites = '\n'.join(f"| {k} | {v} |" for k, v in counts['yaml_suites'].items())
    no_candidates = ', '.join('`' + r['route'] + '`' for r in routes if not r['candidate_case_ids'])
    return f'''# Phase 1 coverage inventory

Generated by `inventory.py`. Sources are frozen in `manifest.json`.

**Inventory reconciled; migration equivalence and runtime conformance are not established.**

| Measurement | Count |
| --- | ---: |
{rows}

| YAML suite | Cases |
| --- | ---: |
{suites}

Each outline example is a separate case. Every explicit assertion action retains its
complete predicate parameters and implementation assertion sites. Helper-embedded
assertions are additional crosswalk entries, not additional YAML cases. Branch sites
are preserved for review; they are not claimed to execute on every invocation.

## Outstanding mapping work

All {counts['crosswalk_unresolved']} crosswalk entries are unresolved. A reviewed entry
must select `covered`, `extend existing scenario`, `new scenario`, or
`superseded by reviewed target decision`, with case/step evidence or a decision link.
The phase-1 gate permits this backlog; the phase-5 parity gate does not.

All 180 routes and 143 configuration paths retain explicit untested behavior and
blockers. Catalog feature-index links and textual configuration hits are discovery
candidates only. Requirement headings, context steps, source tags, and public/private
source surfaces are retained per shared case; exact requirement clauses, ordered RPCs,
fixture contracts, execution layers and dimensional applicability still need review.
No missing Node API has been converted into a host exclusion. `mapping-notes.json`
records the first three flush cases' proposed RPC sequences, concrete queue and
scheduling blockers, and two legacy empty-flush candidates whose protocol/preload
semantics still prevent a parity claim.

Routes without catalog public-feature candidates ({sum(not r['candidate_case_ids'] for r in routes)}):

{no_candidates}

Logs and traces have no dedicated acceptance features at this pin. Public features
such as flush still contain queue observations that require a genuine public
observation or a separately identified component fixture. Private source locations
are not automatically classified as component-only tests.

## Next gate

Phase 2 can define the core invocation/fixture slice for the three existing flush
cases. Full assertion migration remains phase 5; broader catalog gaps remain phase 6.
No adapter has run, and no SDK pass/fail result is recorded here.
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--specs-repo', type=Path, default=ROOT.parents[1])
    parser.add_argument('--harness-repo', type=Path, required=True)
    parser.add_argument('--check', action='store_true', help='Fail if generated artifacts differ; do not write')
    args = parser.parse_args()
    outputs = build(args.specs_repo, args.harness_repo)
    if args.check:
        stale = [name for name, text in outputs.items() if not (ROOT / name).exists() or (ROOT / name).read_text() != text]
        if stale:
            raise SystemExit('Stale inventory: ' + ', '.join(stale))
        print('Inventory reconciled; generated artifacts match.')
    else:
        for name, text in outputs.items():
            (ROOT / name).write_text(text)
        print(outputs['SUMMARY.md'])


if __name__ == '__main__':
    main()
