// Transport-only records. Catalog types and identity include the approved amendments.
import type { Json, Properties, Ref, RefKind, SpecialValueFixture, OperationRoute, Survey, Timestamp, FlagValues, Payloads, FeatureFlagsCallbackArguments, SDKType, EvaluationProvenanceCommand, EvaluationProvenance } from './generated/catalog.js';

/** @minLength 1 */
export type Id = string;
/** @asType integer @minimum 0 */
export type Natural = number;
/** @asType integer @minimum 1 @maximum 300000 */
export type DeadlineMs = number;
export type Version = '2.0.0';
export type { CatalogHash } from './generated/catalog.js';
import type { CatalogHash } from './generated/catalog.js';
export interface Reference { kind: RefKind; id: Id }
export interface InstanceReference { kind: 'instance'; id: Id }
export interface ExceptionReference { kind: 'exception'; id: Id }
/** Non-root RFC 6901 pointer. Array slots follow README's absent-slot rules. */
export type ArgumentReferences = Record<string, Reference>;
export interface Invoke {
  call_id: Id;
  route: OperationRoute;
  receiver: Reference;
  args: Properties;
  references?: ArgumentReferences;
}
// Reference-valued operations use their catalog-typed Ref in value. At data-only
// result positions, reference-shaped objects remain ordinary JSON. retained is explicit identity.
export type Outcome = { kind: 'void' } | { kind: 'undefined' } |
  { kind: 'value'; value: Json | Reference; retained?: Reference } |
  { kind: 'thrown'; error: ExceptionReference };
export type FailureKind = 'unsupported_binding' | 'blocked_fixture' | 'blocked_contract' |
  'timeout' | 'cancelled' | 'harness_error';
export interface HarnessFailure { kind: FailureKind; code: Id; message: Id }
export type Completion = { kind: 'sdk'; outcome: Outcome } | { kind: 'harness'; failure: HarnessFailure };
export interface CallReceipt {
  fixture_id: Id;
  call_id: Id;
  parent_call_id?: Id;
  callback_invocation_id?: Id;
  route: OperationRoute;
  completion: Completion;
}
export interface InvokeRequest { fixture_id: Id; timeout_ms: DeadlineMs; invoke: Invoke }
export interface InvokeResponse { receipt: CallReceipt }

/** Optional concurrent-invocation-v1 fixture; ordinary Invoke remains serial. */
export interface ConcurrentInvokeRequest {
  fixture_id: Id;
  timeout_ms: DeadlineMs;
  /** @minItems 2 @maxItems 32 */
  invokes: Invoke[];
}
export interface ConcurrentInvokeResponse {
  fixture_id: Id;
  /** One terminal receipt per requested call, in request order. @minItems 2 @maxItems 32 */
  calls: CallReceipt[];
}

export interface ExecutionProfile {
  id: Id;
  /** Native SDK client/server type, independent of runtime and wire API. */
  sdk_type?: SDKType;
  runtime: { family: 'server' | 'browser' | 'mobile' | 'desktop' | 'edge' | 'game'; name: Id; version: Id; execution_context: 'synchronous' | 'async_local' | 'thread_local' | 'host_managed' };
  identity: 'stateful_installation' | 'request_scoped';
  protocol: 'legacy' | 'analytics_v1';
  products: ('analytics' | 'ai' | 'flags' | 'replay' | 'logs' | 'metrics' | 'traces' | 'surveys' | 'errors' | 'push')[];
  module: { entry: Id; format: 'esm' | 'commonjs' | 'native'; package: Id; version: Id };
  fixture_capabilities: Id[];
  /** Optional SDK feature/API declarations, independent of runtime and host fixtures. */
  sdk_capabilities?: Id[];
}
export interface NegotiateRequest { contract_version: string; catalog_sha256: string; transport: string }
export type NegotiateResponse = {
  kind: 'accepted'; contract_version: Version; catalog_sha256: CatalogHash;
  transport: 'http-json-v2'; session_id: Id; adapter: { name: Id; version: Id };
  profiles: ExecutionProfile[]; supported_routes: OperationRoute[];
  max_timeout_ms: DeadlineMs;
} | { kind: 'rejected'; code: 'incompatible_version' | 'catalog_mismatch' | 'unsupported_transport'; message: Id };
export interface AllocateRequest { fixture_id: Id; case_id: Id; profile_id: Id; timeout_ms: DeadlineMs }
export type AllocateResponse = { kind: 'allocated'; fixture_id: Id; receiver: InstanceReference } |
  { kind: 'failed'; fixture_id: Id; failure: HarnessFailure };
export interface CloseRequest { fixture_id: Id; timeout_ms: DeadlineMs }
export type CloseResponse = { kind: 'closed'; fixture_id: Id } |
  { kind: 'failed'; fixture_id: Id; failure: HarnessFailure };
export interface CancelRequest { fixture_id: Id; call_id: Id; reason: Id }
export interface CancelResponse { fixture_id: Id; call_id: Id; state: 'cancelled' | 'already_completed' }

// Plans are finite straight-line continuations, not a scenario language.
export type ReferenceSource = { source: 'reference'; reference: Reference } |
  { source: 'callback_argument'; index: Natural } |
  { source: 'call_retained'; step_id: Id };
export interface PlanCall {
  step_id: Id;
  route: OperationRoute;
  receiver: ReferenceSource;
  args: Properties;
  references?: Record<string, ReferenceSource>;
}
export type CallbackReturn = { source: 'literal'; outcome: Outcome } |
  { source: 'callback_argument'; index: Natural } |
  { source: 'call_outcome'; step_id: Id };
export type CallbackSignature = 'loaded' | 'on_error' | 'before_send' | 'log_hook' | 'span_hook' |
  'readiness' | 'on_feature_flags' | 'on_feature_flag' | 'on_session_id' | 'on_surveys_loaded' | 'on_event' |
  'with_context' | 'with_span' | 'push_identity_provider' | 'anonymous_id_provider' | 'early_access';
export interface CallbackArguments {
  loaded: [Ref<'instance'>];
  on_error: [Ref<'exception'>];
  before_send: [Properties];
  log_hook: [Properties];
  span_hook: [Properties];
  readiness: [];
  on_feature_flags: FeatureFlagsCallbackArguments;
  on_feature_flag: [boolean | string | null];
  on_session_id: [string | null];
  on_surveys_loaded: [Survey[]];
  on_event: [Json];
  with_context: [];
  with_span: [Ref<'span'>];
  push_identity_provider: [string, string];
  anonymous_id_provider: [string];
  early_access: [Properties[]];
}
export interface CallbackPlan {
  signature: CallbackSignature;
  /** @asType integer @minimum 1 @maximum 1000 */
  max_invocations: number;
  calls: PlanCall[];
  returns: CallbackReturn;
}
/** @pattern ^-?(0|[1-9][0-9]*)$ */
export type BigIntDecimal = string;
export type ValueFixture = Exclude<SpecialValueFixture, { value: 'bigint' }> |
  { value: 'bigint'; decimal: BigIntDecimal };
export type ReferenceFixture = { kind: 'value'; value: ValueFixture } |
  { kind: 'exception'; name: Id; message: string } |
  { kind: 'callback'; plan: CallbackPlan };
export interface ReferenceRequest { fixture_id: Id; reference_id: Id; fixture: ReferenceFixture }
export type ReferenceResponse = { kind: 'created'; fixture_id: Id; reference: Reference } |
  { kind: 'failed'; fixture_id: Id; failure: HarnessFailure };
export interface CallbackObservation {
  kind: 'callback'; sequence: Natural; fixture_id: Id; callback: Ref<'callback'>;
  invocation_id: Id; invocation_index: Natural; owner_call_id: Id | null;
  args: Outcome[]; completion: Completion; call_ids: Id[];
}
export interface CallObservation { kind: 'call'; sequence: Natural; receipt: CallReceipt }
export type Observation = CallbackObservation | CallObservation;
export interface ObservationsRequest { fixture_id: Id; after_sequence: Natural }
export interface ObservationsResponse { fixture_id: Id; cursor: Natural; observations: Observation[] }
// Entry/exit must surround these calls in one host request, not across HTTP handlers.
export interface ContextScopeRequest {
  fixture_id: Id; scope_id: Id; context: Ref<'context'>; timeout_ms: DeadlineMs; calls: Invoke[];
}
export interface ContextScopeResponse {
  fixture_id: Id; scope_id: Id; calls: CallReceipt[];
  result: { kind: 'completed' } | { kind: 'failed'; failure: HarnessFailure };
}
export interface ProtocolError { kind: 'protocol_error'; code: 'invalid_json' | 'invalid_envelope' | 'invalid_reference' | 'unknown_session' | 'unknown_fixture' | 'duplicate_id' | 'invalid_state'; message: Id }

/** @asType integer @minimum 1 */
export type LineNumber = number;
export interface SourceLocation { revision: Id; path: Id; line: LineNumber }
export interface CaseIdentity { case_id: Id; source: SourceLocation; profile_id: Id }
export interface SelectedCase extends CaseIdentity {
  selected: boolean;
  applicability: { kind: 'applicable' } | { kind: 'not_applicable'; rule: Id; reason: Id };
}
export interface FixtureAttribution { fixture_id: Id; case_id: Id; profile_id: Id }
export interface FailureAttribution {
  failed_step: { index: Natural; source: SourceLocation } | null;
  call_ids: Id[];
  code: Id;
  message: Id;
}
export type CaseDisposition =
  { status: 'passed'; executed: true; call_ids: Id[] } |
  { status: 'failed_assertion' | 'unsupported_binding' | 'blocked_fixture' | 'blocked_contract' | 'harness_error'; executed: boolean; failure: FailureAttribution } |
  { status: 'not_applicable'; executed: false; reason: Id; applicability_rule: Id } |
  { status: 'not_selected'; executed: false; reason: Id };
export interface CaseResult extends CaseIdentity { result: CaseDisposition }
export interface RunError { code: Id; message: Id; case_id?: Id; call_id?: Id }
export interface Report {
  contract_version: Version;
  catalog_sha256: CatalogHash;
  run_id: Id;
  scope_id: Id;
  profiles: ExecutionProfile[];
  inventory: SelectedCase[];
  results: CaseResult[];
  fixtures: FixtureAttribution[];
  calls: CallReceipt[];
  errors: RunError[];
}
// Optional flush-fixture-v1 extension. Each command requires its named profile
// capability; these controls are not SDK operations or a generic private RPC API.
export type FlushFixtureCommand =
  { kind: 'clock_fixed'; timestamp: Timestamp } |
  { kind: 'storage_empty' } |
  { kind: 'scheduler_manual' } |
  { kind: 'queue_snapshot' };
export interface FlushFixtureRequest {
  fixture_id: Id; timeout_ms: DeadlineMs; command: FlushFixtureCommand;
}
export interface QueueRecord { record_id: Id; event: Properties }
export interface QueueSnapshot {
  layer: 'native_component'; implementation: Id; records: QueueRecord[];
}
export type FlushFixtureResponse =
  { kind: 'applied'; fixture_id: Id; command: 'clock_fixed' | 'storage_empty' | 'scheduler_manual' } |
  { kind: 'queue'; fixture_id: Id; command: 'queue_snapshot'; observation: QueueSnapshot } |
  { kind: 'failed'; fixture_id: Id; command: FlushFixtureCommand['kind']; failure: HarnessFailure };

// Optional flags-state-fixture-v1: native-component preparation and activity.
export type FlagStateCommand =
  { kind: 'definitions_install'; definitions: Properties } |
  { kind: 'evaluation_cache_put'; distinct_id: Id; flags: FlagValues; payloads: Payloads } |
  { kind: 'evaluation_activity' } | EvaluationProvenanceCommand;
export interface FlagStateRequest { fixture_id: Id; timeout_ms: DeadlineMs; command: FlagStateCommand }
export interface ComponentSite { layer: 'native_component'; implementation: Id }
export interface EvaluationActivity extends ComponentSite { cache_lookups: Natural; local_evaluations: Natural }
export type FlagStateResponse =
  { kind: 'applied'; fixture_id: Id; command: 'definitions_install' | 'evaluation_cache_put'; observation: ComponentSite } |
  { kind: 'activity'; fixture_id: Id; command: 'evaluation_activity'; observation: EvaluationActivity } |
  { kind: 'provenance'; fixture_id: Id; command: 'evaluation_provenance'; observation: EvaluationProvenance } |
  { kind: 'failed'; fixture_id: Id; command: FlagStateCommand['kind']; failure: HarnessFailure };

// Typed data is a runner input utility, not a Gherkin step/action format.
export type TypedCell = { kind: 'omitted' } | { kind: 'json'; value: Json } |
  { kind: 'reference'; reference: Reference };
