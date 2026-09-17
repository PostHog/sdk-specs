import test from 'node:test';
import assert from 'node:assert/strict';
import { valid, validates } from './oracles.mjs';

const request = command => ({ fixture_id: 'f', timeout_ms: 50, command });
const site = { layer: 'native_component', implementation: 'engine.actual_store' };

test('flag state fixtures preserve values, payload presence and context', () => {
  valid('FlagStateRequest', request({ kind: 'definitions_install', definitions: { flags: [] } }));
  valid('FlagStateRequest', request({ kind: 'evaluation_cache_put', distinct_id: 'user',
    flags: { boolean: false, variant: '' }, payloads: { a: null, b: false, c: 0, d: [], e: {} } }));
  for (const command of [
    { kind: 'evaluation_cache_put', flags: {}, payloads: {} },
    { kind: 'evaluation_cache_put', distinct_id: 'user', flags: { a: 0 }, payloads: {} },
    { kind: 'definitions_install', definitions: [] },
    { kind: 'evaluation_activity', count: 0 },
  ]) assert(!validates('FlagStateRequest', request(command)));
  assert(!validates('FlagStateRequest', { ...request({ kind: 'evaluation_activity' }), timeout_ms: 0 }));
});

test('native activity has component provenance and nonnegative integer counts', () => {
  const response = { kind: 'activity', fixture_id: 'f', command: 'evaluation_activity',
    observation: { ...site, cache_lookups: 0, local_evaluations: 2 } };
  valid('FlagStateResponse', response);
  for (const change of [{ cache_lookups: -1 }, { local_evaluations: 0.5 }, { implementation: '' }, { layer: 'adapter' }]) {
    assert(!validates('FlagStateResponse', { ...response, observation: { ...response.observation, ...change } }));
  }
  assert(!validates('FlagStateResponse', { ...response, kind: 'applied' }));
});

test('fixture preparation acknowledges the actual component or reports a blocker', () => {
  valid('FlagStateResponse', { kind: 'applied', fixture_id: 'f', command: 'definitions_install', observation: site });
  valid('FlagStateResponse', { kind: 'failed', fixture_id: 'f', command: 'evaluation_cache_put',
    failure: { kind: 'blocked_fixture', code: 'unavailable', message: 'No native cache fixture' } });
  assert(!validates('FlagStateResponse', { kind: 'applied', fixture_id: 'f', command: 'definitions_install' }));
  assert(!validates('FlagStateResponse', { kind: 'void' }));
});
