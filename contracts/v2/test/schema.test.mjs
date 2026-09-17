import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { catalog, protocol, ajv, operations, valid, validates, strictJson, negotiated, referenceEnvelope, callbackPlan, strictSuccess } from './oracles.mjs';

const instance = { kind: 'instance', id: 'receiver-1' };
const call = (route = '/capture', args = { event: 'event' }) => ({ call_id: 'call-1', route, receiver: instance, args });
const live = () => new Map([['receiver-1', 'instance'], ['callback-1', 'callback'], ['span-1', 'span'], ['value-1', 'value'], ['error-1', 'exception']]);
const hash = JSON.parse(readFileSync(new URL('../generated/operations.json', import.meta.url))).catalog_sha256;
const profile = { id: 'profile-1', runtime: { family: 'server', name: 'test-host', version: '1', execution_context: 'async_local' }, identity: 'request_scoped', protocol: 'legacy', products: ['analytics'], module: { entry: 'test-host', format: 'commonjs', package: 'controlled-test-double', version: '1' }, fixture_capabilities: ['references.value', 'callbacks.continuation'] };
const source = { revision: '9cb330e3bac8868f39cc7dd665e42817285c9493', path: 'acceptance/public/flush.feature', line: 12 };
const identity = { case_id: 'gherkin:9cb330e:acceptance/public/flush.feature:L12', profile_id: profile.id, source };
function report() {
  return { contract_version: '2.0.0', catalog_sha256: hash, run_id: 'run-1', scope_id: 'contract-tests', profiles: [structuredClone(profile)],
    inventory: [{ ...identity, selected: true, applicability: { kind: 'applicable' } }],
    results: [{ ...identity, result: { status: 'passed', executed: true, call_ids: ['call-1'] } }],
    fixtures: [{ fixture_id: 'fixture-1', case_id: identity.case_id, profile_id: profile.id }],
    calls: [{ fixture_id: 'fixture-1', call_id: 'call-1', route: '/flush', completion: { kind: 'sdk', outcome: { kind: 'void' } } }], errors: [] };
}

test('optional SDK capabilities remain independent of runtime, products, protocol and fixtures', () => {
  valid('ExecutionProfile', profile);
  for (const family of ['server', 'browser', 'mobile', 'edge']) {
    valid('ExecutionProfile', { ...profile, runtime: { ...profile.runtime, family }, sdk_capabilities: ['capture_ai_v0'] });
  }
  valid('ExecutionProfile', { ...profile, sdk_capabilities: [] });
  assert(!validates('ExecutionProfile', { ...profile, sdk_capabilities: [''] }));
  assert(!validates('ExecutionProfile', { ...profile, sdk_capabilities: 'capture_ai_v0' }));
  assert(!Object.hasOwn(profile, 'sdk_capabilities'));
});

test('all 180 operations have compiling typed arguments/results and provenance; 144 configuration paths', () => {
  assert.equal(operations.length, 180);
  for (const op of operations) {
    assert(op.catalog_line > 0 && op.receiver_kind && op.behavior);
    for (const ref of [op.arguments_schema, op.result_schema]) {
      const name = ref.split('/').at(-1);
      assert(catalog.definitions[name]);
      assert(ajv.getSchema(`catalog#/definitions/${name}`));
    }
  }
  assert.equal(JSON.parse(readFileSync(new URL('../generated/configuration.json', import.meta.url))).paths.length, 144);
  for (const name of Object.keys(protocol.definitions)) assert(ajv.getSchema(`protocol#/definitions/${encodeURIComponent(name)}`));
});

test('Invoke envelope is strict but represents missing required and wrongly typed SDK arguments', () => {
  valid('Invoke', call('/capture', { event: 42, properties: null }));
  valid('Invoke', call('/identify', {}));
  assert(!validates('OpCaptureArgs', { event: 42 }, 'catalog'));
  assert(!validates('OpIdentifyArgs', {}, 'catalog'));
  assert(!validates('Invoke', { ...call(), surprise: true }));
  assert(!validates('Invoke', { ...call(), route: '/private/queue' }));
  assert(!validates('Invoke', { ...call(), receiver: null }));
  assert(!validates('Invoke', { ...call(), args: [] }));
  assert(!validates('Invoke', { ...call(), call_id: '' }));
});

test('catalog types preserve nested records, unions, inherited Omit, lists and integer limits', () => {
  valid('OpSetupArgs', { project_token: 'test', config: { flush_at: 0, bootstrap: { distinct_id: null, feature_flags: { off: false } }, replay: { sample_rate: null } } }, 'catalog');
  assert(!validates('OpSetupArgs', { project_token: 'test', config: { flush_at: 1.5 } }, 'catalog'));
  assert(!validates('OpSetupArgs', { project_token: 'test', config: { bootstrap: { is_identified_id: null } } }, 'catalog'));
  valid('OpGetFeatureFlagArgs', { key: 'flag', default_value: false, groups: { company: 'a' } }, 'catalog');
  assert(!validates('OpGetFeatureFlagArgs', { key: 'flag', flag_keys: [] }, 'catalog'));
  valid('OpDisplaySurveyArgs', { survey_id: 's', options: { display_type: 'inline', selector: '#survey' } }, 'catalog');
  assert(!validates('OpDisplaySurveyArgs', { survey_id: 's', options: { display_type: 'inline' } }, 'catalog'));
  assert(!validates('OpSetConfigArgs', { config: { bootstrap: {} } }, 'catalog'));
  assert(!validates('OpFlushArgs', { timeout_ms: '100' }, 'catalog'));
  valid('OpSnapshotKeysArgs', {}, 'catalog');
  assert(!validates('OpSnapshotKeysArgs', { extra: 1 }, 'catalog'));
});

test('timestamps preserve explicit offsets and nanosecond precision without conversion', () => {
  for (const timestamp of ['2026-03-01T12:34:56Z', '2026-03-01T12:34:56.123456789+05:30']) valid('Timestamp', timestamp, 'catalog');
  for (const timestamp of ['2026-03-01', '2026-03-01T12:34:56', '2026-03-01T12:34:56.1234567890Z']) assert(!validates('Timestamp', timestamp, 'catalog'));
});

test('false/zero/null/empty/omission are not coerced or defaulted', () => {
  const input = { event: '', properties: { a: false, b: 0, c: null, d: '', e: [], f: {} }, timestamp: null };
  const original = structuredClone(input);
  valid('OpCaptureArgs', input, 'catalog');
  assert.deepEqual(input, original);
  assert(!Object.hasOwn(input, 'send_instantly'));
  for (const value of [false, 0, null, '', [], {}]) valid('Outcome', { kind: 'value', value });
});

test('native void, undefined, null/value and thrown are disjoint; timeouts are not native outcomes', () => {
  for (const outcome of [{ kind: 'void' }, { kind: 'undefined' }, { kind: 'value', value: null }, { kind: 'thrown', error: { kind: 'exception', id: 'e' } }]) valid('Outcome', outcome);
  for (const outcome of [{ kind: 'void', value: null }, { kind: 'value' }, { kind: 'timeout' }, { kind: 'thrown', error: 'failure' }]) assert(!validates('Outcome', outcome));
  assert(!validates('OpCaptureResult', { kind: 'undefined' }, 'catalog'));
  assert(!validates('OpCaptureResult', { kind: 'value', value: null }, 'catalog'));
  valid('OpCaptureResult', { kind: 'void' }, 'catalog');
  valid('Completion', { kind: 'harness', failure: { kind: 'timeout', code: 'deadline', message: 'host deadline elapsed' } });
});

test('retained handle target schemas remain typed, while reference-looking JSON is data', () => {
  valid('OpEvaluateFlagsResult', { kind: 'value', value: { kind: 'snapshot', id: 's' } }, 'catalog');
  assert(!validates('OpEvaluateFlagsResult', { kind: 'value', value: { kind: 'span', id: 's' } }, 'catalog'));
  assert.deepEqual(operations.find(op => op.route === '/get_active_span').result_reference_kinds, ['span']);
  valid('Outcome', { kind: 'value', value: { kind: 'snapshot', id: 's' }, retained: { kind: 'snapshot', id: 's' } });
  const input = call('/capture', { event: 'event', properties: { object: { kind: 'callback', id: 'not-a-live-reference' } } });
  referenceEnvelope(input, live());
  valid('Outcome', { kind: 'value', value: { kind: 'exception', id: 'ordinary-data' } });
});

test('reference insertion requires absent slots, existing parents and typed positions', () => {
  const request = { ...call('/flush', {}), references: { '/callback': { kind: 'callback', id: 'callback-1' } } };
  referenceEnvelope(request, live());
  assert.throws(() => referenceEnvelope({ ...request, args: { callback: null } }, live()));
  assert.throws(() => referenceEnvelope({ ...request, references: { '/unknown': { kind: 'callback', id: 'callback-1' } } }, live()));
  assert.throws(() => referenceEnvelope({ ...call(), references: { '/properties/object': { kind: 'callback', id: 'callback-1' } } }, live()));
  assert.throws(() => referenceEnvelope({ ...call(), references: { 'callback': { kind: 'callback', id: 'callback-1' } } }, live()));
  assert.throws(() => referenceEnvelope({ ...call(), references: { '/bad~2escape': { kind: 'value', id: 'value-1' } } }, live()));
});

test('reference arrays append absent contiguous slots, never null placeholders', () => {
  const request = { ...call('/setup', { project_token: 'test', config: { before_send: [] } }), references: { '/config/before_send/0': { kind: 'callback', id: 'callback-1' } } };
  referenceEnvelope(request, live());
  assert.throws(() => referenceEnvelope({ ...request, references: { '/config/before_send/1': { kind: 'callback', id: 'callback-1' } } }, live()));
  assert.throws(() => referenceEnvelope({ ...request, args: { project_token: 'test', config: { before_send: [null] } } }, live()));
});

test('negative runtime values are injectable at the exact field, with escaped pointers', () => {
  referenceEnvelope({ ...call('/capture', { event: 'e', properties: {} }), references: { '/properties/a~1b~0c': { kind: 'value', id: 'value-1' } } }, live());
  valid('ReferenceRequest', { fixture_id: 'f', reference_id: 'v', fixture: { kind: 'value', value: { value: 'nan' } } });
  valid('ReferenceRequest', { fixture_id: 'f', reference_id: 'v', fixture: { kind: 'value', value: { value: 'undefined' } } });
  assert.throws(() => referenceEnvelope({ ...call(), references: { '/not_a_parameter': { kind: 'value', id: 'value-1' } } }, live()));
});

test('bigint fixture descriptors require lossless decimal integer syntax', () => {
  for (const decimal of ['0', '-0', '9007199254740993', '-9007199254740993']) {
    valid('ReferenceRequest', { fixture_id: 'f', reference_id: 'v', fixture: { kind: 'value', value: { value: 'bigint', decimal } } });
  }
  for (const decimal of ['abc', '', '+1', '01', '1.2', ' 1', '1e3']) {
    assert(!validates('ReferenceRequest', { fixture_id: 'f', reference_id: 'v', fixture: { kind: 'value', value: { value: 'bigint', decimal } } }));
  }
});

test('receiver kind and reference lifetime are envelope invariants', () => {
  const input = { ...call('/span/end', {}), receiver: { kind: 'span', id: 'span-1' } };
  referenceEnvelope(input, live());
  assert.throws(() => referenceEnvelope(call('/span/end', {}), live()));
  assert.throws(() => referenceEnvelope(input, new Map()));
  assert.throws(() => referenceEnvelope(input, new Map([['span-1', 'snapshot']])));
});

test('negotiation rejects v1, wrong catalog and unselected transport before allocation', () => {
  const request = { contract_version: '2.0.0', catalog_sha256: hash, transport: 'http-json-v2' };
  const response = { kind: 'accepted', ...request, session_id: 'session', adapter: { name: 'double', version: '1' }, profiles: [profile], supported_routes: ['/capture', '/flush'], max_timeout_ms: 10000 };
  assert(negotiated(request, response));
  assert(!negotiated({ ...request, contract_version: '1.4.0' }, response));
  assert(!negotiated({ ...request, catalog_sha256: 'wrong' }, response));
  assert(!negotiated({ ...request, transport: 'yaml-v1' }, response));
  assert(!validates('NegotiateResponse', { ...response, contract_version: '1.4.0' }));
});

test('fixture allocation/close and bounded deadlines are not setup/shutdown outcomes', () => {
  valid('AllocateRequest', { fixture_id: 'f', case_id: 'case', profile_id: profile.id, timeout_ms: 1000 });
  valid('AllocateResponse', { kind: 'allocated', fixture_id: 'f', receiver: instance });
  valid('CloseRequest', { fixture_id: 'f', timeout_ms: 1000 });
  valid('CloseResponse', { kind: 'closed', fixture_id: 'f' });
  for (const timeout_ms of [0, -1, 0.5, 300001, Infinity]) assert(!validates('InvokeRequest', { fixture_id: 'f', timeout_ms, invoke: call() }));
  valid('InvokeRequest', { fixture_id: 'f', timeout_ms: 1000, invoke: call('/flush', { timeout_ms: 0 }) });
  valid('CancelResponse', { fixture_id: 'f', call_id: 'c', state: 'cancelled' });
});

test('preinstalled callback plans carry signatures and ordered explicit nested calls', () => {
  const plan = { signature: 'with_span', max_invocations: 1, calls: [{ step_id: 'attribute', route: '/span/set_attribute', receiver: { source: 'callback_argument', index: 0 }, args: { key: 'count', value: 0 } }], returns: { source: 'literal', outcome: { kind: 'value', value: false } } };
  callbackPlan(plan);
  assert.throws(() => callbackPlan({ ...plan, calls: [plan.calls[0], plan.calls[0]] }));
  assert.throws(() => callbackPlan({ ...plan, calls: [{ ...plan.calls[0], receiver: { source: 'call_retained', step_id: 'later' } }] }));
  assert.throws(() => callbackPlan({ ...plan, max_invocations: 0 }));
  assert.throws(() => callbackPlan({ ...plan, calls: [], returns: { source: 'call_outcome', step_id: 'absent' } }));
  valid('CallReceipt', { fixture_id: 'f', call_id: '@callback/f/cb/0/attribute', parent_call_id: 'owner', callback_invocation_id: '@callback/f/cb/0', route: '/span/set_attribute', completion: { kind: 'sdk', outcome: { kind: 'value', value: { kind: 'span', id: 'span-1' }, retained: { kind: 'span', id: 'span-1' } } } });
});

test('JSON parsing rejects duplicate keys, nonfinite numbers, comments and trailing data', () => {
  for (const text of ['{"a":1,"a":2}', '{"a":1,"\\u0061":2}', '{"nested":{"a":1,"a":2}}', '{"x":NaN}', '{"x":Infinity}', '{"x":1e999}', '{"x":1,}', '{}{}', '/* hi */ {}']) assert.throws(() => strictJson(text));
  assert.deepEqual(strictJson('{"false":false,"zero":0,"null":null,"object":{"kind":"span","id":"data"}}'), { false: false, zero: 0, null: null, object: { kind: 'span', id: 'data' } });
  assert(!validates('Invoke', call('/capture', { event: 'e', properties: { number: NaN } })));
});

test('typed cells distinguish omission, JSON null, undefined runtime reference and literal strings', () => {
  for (const cell of [{ kind: 'omitted' }, { kind: 'json', value: null }, { kind: 'json', value: 'false' }, { kind: 'reference', reference: { kind: 'value', id: 'undefined' } }]) valid('TypedCell', cell);
  assert(!validates('TypedCell', { kind: 'omitted', value: null }));
  assert(!validates('TypedCell', { kind: 'json', value: undefined }));
});

test('profiles keep identity, protocol, products, runtime and modules independent', () => {
  valid('ExecutionProfile', profile);
  valid('ExecutionProfile', { ...profile, identity: 'stateful_installation', protocol: 'analytics_v1', products: ['traces'] });
  assert(!validates('ExecutionProfile', { ...profile, 'sdk-type': 'server' }));
});

test('strict report passes a complete selected applicable executed case', () => {
  valid('Report', report());
  assert(strictSuccess(report()));
});

test('all failure statuses need attribution and cannot be success', () => {
  for (const status of ['failed_assertion', 'unsupported_binding', 'blocked_fixture', 'blocked_contract', 'harness_error']) {
    const value = report();
    value.results[0].result = { status, executed: true, failure: { failed_step: { index: 0, source }, call_ids: ['call-1'], code: 'failure', message: 'specific cause' } };
    valid('Report', value); assert(!strictSuccess(value));
    delete value.results[0].result.failure;
    assert(!validates('Report', value));
  }
});

test('zero selection, only exclusions, duplicate/missing results and wrong-case calls fail closed', () => {
  const zero = report(); zero.inventory = []; zero.results = []; zero.fixtures = []; zero.calls = [];
  assert(!strictSuccess(zero));
  const notSelected = structuredClone(zero);
  notSelected.inventory = [{ ...identity, selected: false, applicability: { kind: 'applicable' } }];
  notSelected.results = [{ ...identity, result: { status: 'not_selected', executed: false, reason: 'selector' } }];
  assert(!strictSuccess(notSelected));
  const excluded = structuredClone(notSelected);
  excluded.inventory[0] = { ...identity, selected: true, applicability: { kind: 'not_applicable', rule: 'runtime-ui', reason: 'no UI host' } };
  excluded.results[0].result = { status: 'not_applicable', executed: false, reason: 'no UI host', applicability_rule: 'runtime-ui' };
  assert(!strictSuccess(excluded));
  for (const mutate of [r => r.results.push(r.results[0]), r => r.results.pop(), r => r.inventory.push(r.inventory[0]), r => r.calls.push(r.calls[0]), r => r.results[0].result.call_ids.push('missing'), r => r.fixtures[0].case_id = 'other', r => r.results[0].result.call_ids = [], r => r.results[0].source = { ...source, line: 99 }]) {
    const value = report(); mutate(value); assert(!strictSuccess(value));
  }
});

test('parent cycles and unexecuted cases cannot carry successful call receipts', () => {
  const cyclic = report();
  cyclic.calls[0].parent_call_id = 'second';
  cyclic.calls.push({ ...cyclic.calls[0], call_id: 'second', parent_call_id: 'call-1' });
  cyclic.results[0].result.call_ids.push('second');
  assert(!strictSuccess(cyclic));
  const unexecuted = report();
  unexecuted.results[0].result = { status: 'blocked_fixture', executed: false,
    failure: { failed_step: null, call_ids: ['call-1'], code: 'fixture', message: 'not executed' } };
  assert(!strictSuccess(unexecuted));
});

test('harness errors and hidden harness call failures cannot become passed results', () => {
  const withError = report(); withError.errors.push({ code: 'unknown_step', message: 'step not registered' }); assert(!strictSuccess(withError));
  const hidden = report(); hidden.calls[0].completion = { kind: 'harness', failure: { kind: 'timeout', code: 'deadline', message: 'timed out' } }; assert(!strictSuccess(hidden));
  const unsupported = report(); unsupported.results[0].result = { status: 'not_applicable', executed: false, reason: 'API absent', applicability_rule: 'unsupported-api' }; assert(!strictSuccess(unsupported));
  assert(!validates('Report', { ...report(), success: true }));
});

test('capture-amendment-v1 preserves optional false values and capture-only scope', () => {
  for (const disable_geoip of [true, false]) valid('OpSetupArgs', { project_token: 'test', config: { disable_geoip } }, 'catalog');
  const options = { cookieless_mode: false, disable_skew_correction: false, process_person_profile: false, product_tour_id: '' };
  for (const args of [{ event: 'x' }, { event: 'x', options: {} }, { event: 'x', options }]) {
    const original = structuredClone(args);
    valid('OpCaptureArgs', args, 'catalog');
    assert.deepEqual(args, original);
  }
  for (const options of [null, [], { cookieless_mode: 'false' }, { disable_skew_correction: 0 }, { process_person_profile: null }, { product_tour_id: false }, { extra: true }]) {
    assert(!validates('OpCaptureArgs', { event: 'x', options }, 'catalog'));
    valid('Invoke', call('/capture', { event: 'x', options }));
  }
  for (const name of ['OpCaptureAiArgs', 'OpCaptureImmediateArgs', 'OpCaptureAiImmediateArgs']) assert(!validates(name, { event: 'x', options }, 'catalog'));
  assert(!validates('OpSetConfigArgs', { config: { disable_geoip: false } }, 'catalog'));
});

test('effective catalog identity includes the ordered approved amendment hashes', async () => {
  const { createHash } = await import('node:crypto');
  const manifest = JSON.parse(readFileSync(new URL('../generated/operations.json', import.meta.url)));
  const identity = [manifest.base_catalog_sha256, ...manifest.amendments.map(a => `${a.id}:${a.sha256}`)].join('\n') + '\n';
  assert.equal(createHash('sha256').update(identity).digest('hex'), hash);
  assert.notEqual(manifest.base_catalog_sha256, hash);
  assert.equal(protocol.definitions.CatalogHash.const, hash);
  assert.equal(operations.find(op => op.route === '/capture').amendment, 'capture-amendment-v1');
  assert(!validates('Report', { ...report(), catalog_sha256: manifest.base_catalog_sha256 }));
});
