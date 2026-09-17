import test from 'node:test';
import assert from 'node:assert/strict';
import { valid, validates } from './oracles.mjs';

const request = command => ({ fixture_id: 'case-1', timeout_ms: 5000, command });

test('flush fixture controls have typed inputs and bounded deadlines', () => {
  for (const command of [
    { kind: 'scheduler_manual' },
    { kind: 'storage_empty' },
    { kind: 'clock_fixed', timestamp: '2025-01-01T00:00:00Z' },
    { kind: 'queue_snapshot' },
  ]) valid('FlushFixtureRequest', request(command));
  for (const command of [
    { kind: 'clock_fixed' },
    { kind: 'clock_fixed', timestamp: 'yesterday' },
    { kind: 'queue_snapshot', count: 2 },
    { kind: '/capture', event: 'event' },
  ]) assert(!validates('FlushFixtureRequest', request(command)));
  assert(!validates('FlushFixtureRequest', { ...request({ kind: 'queue_snapshot' }), timeout_ms: 0 }));
});

test('queue observations retain component provenance and per-record identity', () => {
  const observation = { layer: 'native_component', implementation: 'queue.records',
    records: [{ record_id: 'record-1', event: { event: 'First', properties: { null: null, false: false, zero: 0 } } }] };
  const response = { kind: 'queue', fixture_id: 'case-1', command: 'queue_snapshot', observation };
  valid('FlushFixtureResponse', response);
  valid('FlushFixtureResponse', { ...response, observation: { ...observation, records: [] } });
  assert(!validates('FlushFixtureResponse', { ...response, observation: { ...observation, records: [{ event: {} }] } }));
  assert(!validates('FlushFixtureResponse', { ...response, observation: { records: [] } }));
  assert(!validates('FlushFixtureResponse', { ...response, observation: { ...observation, count: 1 } }));
});

test('fixture controls return fixture acknowledgments or attributed blockers', () => {
  valid('FlushFixtureResponse', { kind: 'applied', fixture_id: 'case-1', command: 'storage_empty' });
  valid('FlushFixtureResponse', { kind: 'failed', fixture_id: 'case-1', command: 'queue_snapshot',
    failure: { kind: 'blocked_fixture', code: 'component_unavailable', message: 'No quiescent queue observation' } });
  assert(!validates('FlushFixtureResponse', { kind: 'applied', fixture_id: 'case-1', command: 'queue_snapshot' }));
  assert(!validates('FlushFixtureResponse', { kind: 'void' }));
});
