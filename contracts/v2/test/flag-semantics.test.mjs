import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { protocol, valid, validates } from './oracles.mjs';

const read = path => readFileSync(new URL('../' + path, import.meta.url));
test('native flag callback has enabled keys, typed variants and optional loading context; readiness remains noarg', () => {
  const schema = protocol.definitions.CallbackArguments.properties;
  const name = schema.on_feature_flags.$ref.split('/').at(-1);
  for (const args of [[[], {}], [['x'], {x: true}, {}], [['x'], {x: 'blue'}, {errorsLoading: false}], [[], {}, {errorsLoading: true}]]) valid(name, args);
  for (const args of [[], [[], {}, false], [[], {x: 1}], [[], {}, {errorsLoading: null}]]) assert(!validates(name, args));
  assert.equal(schema.readiness.maxItems, 0);
  valid('CallbackPlan', {signature: 'on_feature_flags', max_invocations: 4, calls: [], returns: {source: 'literal', outcome: {kind: 'void'}}});
  valid('CallbackObservation', {kind: 'callback', sequence: 1, fixture_id: 'f', callback: {kind: 'callback', id: 'cb'}, invocation_id: '@callback/f/cb/0', invocation_index: 0, owner_call_id: null, args: [{kind: 'value', value: []}, {kind: 'value', value: {}}, {kind: 'undefined'}], completion: {kind: 'sdk', outcome: {kind: 'void'}}, call_ids: []});
});

test('flag policy and callback amendment participates in negotiated effective identity', () => {
  const manifest = JSON.parse(read('generated/operations.json'));
  assert.deepEqual(manifest.amendments.map(a => a.id), ['capture-amendment-v1', 'flag-semantics-v1', 'local-evaluation-v1']);
  const amendment = manifest.amendments[1];
  assert.equal(createHash('sha256').update(read(amendment.path)).digest('hex'), amendment.sha256);
  const hash = createHash('sha256').update([manifest.base_catalog_sha256, ...manifest.amendments.map(a => `${a.id}:${a.sha256}`)].join('\n') + '\n').digest('hex');
  assert.equal(manifest.catalog_sha256, hash);
  assert.notEqual(hash, '7b2e0eddfb9c72ac80c938de70bf4025eb58fc1d655d380df42cc7544734f145');
  assert.deepEqual(manifest.policy_overrides, ['inputs/flag-semantics-v1.ts', 'inputs/local-evaluation-v1.ts']);
  assert.equal(manifest.operations.find(o => o.route === '/on_feature_flags').amendment, 'flag-semantics-v1');
});

test('optional SDK type remains independent of runtime and prior profiles remain valid', () => {
  const profile = {id: 'p', runtime: {family: 'edge', name: 'controlled', version: '1', execution_context: 'async_local'}, identity: 'request_scoped', protocol: 'legacy', products: ['flags'], module: {entry: 'test', format: 'native', package: 'controlled', version: '1'}, fixture_capabilities: []};
  valid('ExecutionProfile', profile);
  for (const family of ['edge', 'desktop']) for (const sdk_type of ['server', 'client']) valid('ExecutionProfile', {...profile, runtime: {...profile.runtime, family}, sdk_type});
  assert(!validates('ExecutionProfile', {...profile, sdk_type: 'browser'}));
});
