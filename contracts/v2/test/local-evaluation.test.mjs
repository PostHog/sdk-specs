import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { valid, validates, operations } from './oracles.mjs';

const read = path => readFileSync(new URL('../' + path, import.meta.url));
test('native local reload is a policy amendment, not a new route or return envelope', () => {
  const manifest = JSON.parse(read('generated/operations.json'));
  const amendment = manifest.amendments.at(-1);
  assert.equal(amendment.id, 'local-evaluation-v1');
  assert.equal(createHash('sha256').update(read(amendment.path)).digest('hex'), amendment.sha256);
  const hash = createHash('sha256').update([manifest.base_catalog_sha256, ...manifest.amendments.map(a => `${a.id}:${a.sha256}`)].join('\n') + '\n').digest('hex');
  assert.equal(hash, manifest.catalog_sha256);
  assert.equal(operations.length, 180);
  const reload = operations.find(o => o.route === '/reload_feature_flags');
  assert.equal(reload.amendment, amendment.id);
  assert.equal(reload.result_kind, 'void');
  valid('OpReloadFeatureFlagsArgs', {}, 'catalog');
  valid('OpReloadFeatureFlagsResult', {kind: 'void'}, 'catalog');
  assert(!validates('OpReloadFeatureFlagsResult', {kind: 'value', value: {ready: true}}, 'catalog'));
});

test('evaluation provenance distinguishes native local, remote and inconclusive results', () => {
  valid('FlagStateRequest', {fixture_id: 'f', timeout_ms: 5000, command: {kind: 'evaluation_provenance', call_id: 'c'}});
  assert(!validates('FlagStateRequest', {fixture_id: 'f', timeout_ms: 5000, command: {kind: 'evaluation_provenance'}}));
  const base = {kind: 'provenance', fixture_id: 'f', command: 'evaluation_provenance'};
  const site = {layer: 'native_component', implementation: 'engine.evaluate', call_id: 'c', key: 'flag'};
  for (const resolution of ['local', 'remote']) for (const value of [true, false, '', 'variant']) {
    valid('FlagStateResponse', {...base, observation: {...site, resolution, value}});
  }
  for (const resolution of ['fallback', 'not_evaluated']) {
    valid('FlagStateResponse', {...base, observation: {...site, resolution}});
    assert(!validates('FlagStateResponse', {...base, observation: {...site, resolution, value: false}}));
  }
  for (const change of [{layer: 'adapter'}, {call_id: ''}, {key: ''}, {value: null}, {value: 1}, {resolution: 'cached'}]) {
    assert(!validates('FlagStateResponse', {...base, observation: {...site, resolution: 'local', value: false, ...change}}));
  }
});
