import test from 'node:test';
import assert from 'node:assert/strict';
import { valid, validates } from './oracles.mjs';

const invoke = call_id => ({ call_id, route: '/evaluate_flags', receiver: { kind: 'instance', id: 'sdk' },
  args: { distinct_id: 'user', flag_keys: [] } });

test('concurrent groups have bounded size and preserve ordinary invocation arguments', () => {
  const base = { fixture_id: 'f', timeout_ms: 50, invokes: [invoke('a'), invoke('b')] };
  valid('ConcurrentInvokeRequest', base);
  for (const invokes of [[], [invoke('a')], Array.from({ length: 33 }, (_, i) => invoke(String(i)))]) {
    assert(!validates('ConcurrentInvokeRequest', { ...base, invokes }));
  }
  assert(!validates('ConcurrentInvokeRequest', { ...base, timeout_ms: 0 }));
});

test('concurrent results retain individual native and harness completions', () => {
  const calls = ['a', 'b'].map(call_id => ({ fixture_id: 'f', call_id, route: '/evaluate_flags',
    completion: { kind: 'sdk', outcome: { kind: 'value', value: { kind: 'snapshot', id: call_id } } } }));
  valid('ConcurrentInvokeResponse', { fixture_id: 'f', calls });
  calls[1].completion = { kind: 'harness', failure: { kind: 'timeout', code: 'deadline', message: 'Expired' } };
  valid('ConcurrentInvokeResponse', { fixture_id: 'f', calls });
  assert(!validates('ConcurrentInvokeResponse', { fixture_id: 'f', calls: calls.slice(0, 1) }));
});
