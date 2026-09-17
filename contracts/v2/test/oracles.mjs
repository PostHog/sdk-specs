// Contract test oracles, not a host, client, SDK binding, or Gherkin runner.
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import Ajv from 'ajv';
import { parseTree } from 'jsonc-parser';

const load = file => JSON.parse(readFileSync(new URL(`../generated/${file}`, import.meta.url), 'utf8'));
export const catalog = load('catalog.schema.json');
export const protocol = load('protocol.schema.json');
export const operations = load('operations.json').operations;
export const ajv = new Ajv({ strict: true, allowUnionTypes: true, allErrors: true, strictNumbers: true, coerceTypes: false, useDefaults: false, removeAdditional: false });
ajv.addSchema(catalog, 'catalog');
ajv.addSchema(protocol, 'protocol');
export const validates = (name, data, group = 'protocol') => ajv.getSchema(`${group}#/definitions/${name}`)(data);
export function valid(name, data, group = 'protocol') {
  const validator = ajv.getSchema(`${group}#/definitions/${name}`);
  assert(validator(data), `${name}: ${ajv.errorsText(validator.errors)}`);
}
export function strictJson(text) {
  const errors = [];
  const tree = parseTree(text, errors, { allowTrailingComma: false, disallowComments: true });
  assert(tree && errors.length === 0, 'invalid JSON');
  function visit(node) {
    if (node.type === 'object') {
      const keys = node.children.map(property => property.children[0].value);
      assert.equal(keys.length, new Set(keys).size, 'duplicate JSON key');
    }
    if (node.type === 'number') assert(Number.isFinite(node.value), 'non-finite JSON number');
    node.children?.forEach(visit);
  }
  visit(tree);
  return JSON.parse(text);
}
export function negotiated(request, response) {
  valid('NegotiateRequest', request);
  valid('NegotiateResponse', response);
  return response.kind === 'accepted' && request.contract_version === '2.0.0' &&
    request.catalog_sha256 === response.catalog_sha256 && request.transport === 'http-json-v2';
}
const has = (object, key) => Object.hasOwn(object, key);
const tokens = pointer => {
  assert(/^\/(?:[^~]|~[01])*$/.test(pointer), 'invalid JSON Pointer');
  return pointer.slice(1).split('/').map(token => token.replaceAll('~1', '/').replaceAll('~0', '~'));
};
function deref(schema) {
  while (schema?.$ref) schema = catalog.definitions[decodeURIComponent(schema.$ref.split('/').at(-1))];
  return schema;
}
function atPath(schema, path) {
  schema = deref(schema);
  if (!schema) return [];
  if (schema.anyOf) return schema.anyOf.flatMap(branch => atPath(branch, path));
  if (schema.allOf) return schema.allOf.flatMap(branch => atPath(branch, path));
  if (!path.length) return [schema];
  const [key, ...tail] = path;
  if (schema.type === 'array' && /^(0|[1-9][0-9]*)$/.test(key)) return atPath(schema.items, tail);
  if (schema.type === 'object') return atPath(schema.properties?.[key] ?? schema.additionalProperties, tail);
  return [];
}
export function referenceEnvelope(invoke, liveReferences) {
  valid('Invoke', invoke);
  const operation = operations.find(op => op.route === invoke.route);
  const live = reference => {
    assert.equal(liveReferences.get(reference.id), reference.kind, 'unknown, expired or wrong-kind reference');
  };
  live(invoke.receiver);
  assert.equal(invoke.receiver.kind, operation.receiver_kind, 'wrong receiver kind');
  const entries = Object.entries(invoke.references ?? {}).map(([pointer, reference]) => ({ pointer, path: tokens(pointer), reference }));
  const arrays = new Map();
  for (const entry of entries) {
    live(entry.reference);
    for (const other of entries) if (entry !== other) {
      assert(!(entry.path.length <= other.path.length && entry.path.every((key, i) => key === other.path[i])), 'overlapping reference paths');
    }
    let parent = invoke.args;
    for (const key of entry.path.slice(0, -1)) {
      assert(parent !== null && typeof parent === 'object' && has(parent, key), 'missing reference parent');
      parent = parent[key];
    }
    assert(parent !== null && typeof parent === 'object', 'reference parent is not a container');
    const key = entry.path.at(-1);
    assert(!has(parent, key), 'reference collides with JSON slot');
    if (Array.isArray(parent)) {
      assert(/^(0|[1-9][0-9]*)$/.test(key), 'non-canonical array index');
      const indices = arrays.get(parent) ?? [];
      indices.push(Number(key)); arrays.set(parent, indices);
    }
    const schema = catalog.definitions[operation.arguments_schema.split('/').at(-1)];
    const targets = atPath(schema, entry.path);
    assert(targets.length, 'reference adds a parameter');
    if (entry.reference.kind !== 'value') {
      assert(targets.some(target => target.properties?.kind?.const === entry.reference.kind && target.properties?.id), 'not a typed reference position');
    }
  }
  for (const [array, indices] of arrays) {
    indices.sort((a, b) => a - b);
    assert(indices.every((index, offset) => index === array.length + offset), 'array reference gap');
  }
}
export function callbackPlan(plan) {
  valid('CallbackPlan', plan);
  const seen = new Set();
  const use = source => {
    if (source.source === 'call_retained' || source.source === 'call_outcome') assert(seen.has(source.step_id), 'unknown or forward plan dependency');
  };
  for (const call of plan.calls) {
    assert(!seen.has(call.step_id), 'duplicate plan step');
    use(call.receiver);
    Object.values(call.references ?? {}).forEach(use);
    seen.add(call.step_id);
  }
  use(plan.returns);
}
const key = value => JSON.stringify([value.case_id, value.profile_id]);
function unique(values) { assert.equal(values.length, new Set(values).size, 'duplicate identity'); }
export function strictSuccess(report) {
  try {
    valid('Report', report);
    unique(report.profiles.map(p => p.id));
    unique(report.inventory.map(key)); unique(report.results.map(key));
    unique(report.fixtures.map(f => f.fixture_id)); unique(report.calls.map(c => c.call_id));
    const profiles = new Set(report.profiles.map(p => p.id));
    const inventory = new Map(report.inventory.map(c => [key(c), c]));
    const fixtures = new Map(report.fixtures.map(f => [f.fixture_id, f]));
    const calls = new Map(report.calls.map(c => [c.call_id, c]));
    assert.equal(report.results.length, inventory.size, 'incomplete result inventory');
    for (const fixture of report.fixtures) assert(inventory.has(key(fixture)), 'unattributed fixture');
    for (const call of report.calls) {
      assert(fixtures.has(call.fixture_id), 'unattributed call');
      const visited = new Set([call.call_id]);
      let current = call;
      while (current.parent_call_id) {
        assert.equal(calls.get(current.parent_call_id)?.fixture_id, call.fixture_id, 'invalid parent call');
        assert(!visited.has(current.parent_call_id), 'cyclic parent call');
        visited.add(current.parent_call_id);
        current = calls.get(current.parent_call_id);
      }
    }
    let passed = 0;
    const attributed = new Set();
    for (const result of report.results) {
      const entry = inventory.get(key(result));
      assert(entry && profiles.has(result.profile_id), 'unknown case/profile');
      assert.deepEqual(entry.source, result.source);
      const disposition = result.result;
      if (!entry.selected) assert.equal(disposition.status, 'not_selected');
      else if (entry.applicability.kind === 'not_applicable') {
        assert.equal(disposition.status, 'not_applicable');
        assert.equal(disposition.applicability_rule, entry.applicability.rule);
      } else {
        assert(!['not_selected', 'not_applicable'].includes(disposition.status), 'applicable behavior hidden');
        if (disposition.status === 'passed') passed++;
      }
      const callIds = disposition.call_ids ?? disposition.failure?.call_ids ?? [];
      unique(callIds);
      assert(disposition.executed || callIds.length === 0, 'unexecuted case has calls');
      for (const id of callIds) {
        const call = calls.get(id);
        assert(call && key(fixtures.get(call.fixture_id)) === key(entry), 'wrong-case call attribution');
        assert(!attributed.has(id), 'multiply attributed call'); attributed.add(id);
        if (disposition.status === 'passed') assert.equal(call.completion.kind, 'sdk', 'harness failure hidden');
      }
      if (disposition.failure && disposition.executed) assert(disposition.failure.failed_step, 'missing failing step');
    }
    assert.equal(attributed.size, calls.size, 'orphan call');
    return report.errors.length === 0 && passed > 0 && report.results.every(r => ['passed', 'not_selected', 'not_applicable'].includes(r.result.status));
  } catch { return false; }
}
