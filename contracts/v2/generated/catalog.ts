// Generated from inputs/public-rpc-catalog.md (ac8165c607ea0d15e924d3984e4da49d68cdcb77d1d2fe8de18da142603870e3).
// Effective catalog c52ae7fac46f0395a78276bbc6c3b97ea83538005bcee11b60b2dc33879adfaa; amendments: capture-amendment-v1:6e088b69f00bf07c2129a85bb2f993502dbfa701248288ca66d468e02426c0d4, flag-semantics-v1:5831088033c377faaee005bfcb761a4be18b9f0d54dc8a9cd70cdaaf5384a892, local-evaluation-v1:0fda649d942134af6d6c80a9dcc44a0609f063e241b7113338be506f2abf3f53.
// Do not edit; npm run generate. Type schemas are semantic targets, not Invoke admission gates.
export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
export type Properties = Record<string, Json>;
/** @asType integer */
export type integer = number;
export type Identity = string;
export type GroupKey = string;
export type Groups = Record<string, GroupKey>;
export type GroupProperties = Record<string, Properties>;
/** @pattern ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?(Z|[+-][0-9]{2}:[0-9]{2})$ */
export type Timestamp = string;
export type DurationMs = number;
export type FlagValue = boolean | string;
export type FlagValues = Record<string, FlagValue>;
export type Payloads = Record<string, Json>;
export type HeaderValue = string | string[];
export type MetricAttributes = Record<string, string | number | boolean>;
export type SpanValue = Json;
export type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "fatal";
export type Transport = "XHR" | "fetch" | "sendBeacon";
export type RefKind = "instance" | "exception" | "stack" | "callback" | "snapshot" |
  "flag_result" | "span" | "subscription" | "context" | "cancellation" |
  "type" | "runtime" | "definition" | "cache_provider" | "storage" |
  "logger" | "metrics" | "diagnostic_logger" | "surveys_delegate" | "subject" | "batch_summary" | "value";
export interface Ref<K extends RefKind> { kind: K; id: string }
export type SpecialValueFixture = { value: "undefined" | "nan" | "positive_infinity" | "negative_infinity" } |
  { value: "bigint"; decimal: string };
export type Instance = Ref<"instance">;
export type ErrorRef = Ref<"exception">;
export type Stack = Ref<"stack">;
export type Callback = Ref<"callback">;
export type Snapshot = Ref<"snapshot">;
export type FlagResultRef = Ref<"flag_result">;
export type Span = Ref<"span">;
export type Subscription = Ref<"subscription">;
export type Context = Ref<"context">;
export type Cancellation = Ref<"cancellation">;
export type Type = Ref<"type">;
export type ExceptionInput = ErrorRef | Json;


export interface FlagResult {
  key: string;
  enabled: boolean;
  variant: string | null;
  payload: Json;
}
export interface FlagsAndPayloads { flags: FlagValues; payloads: Payloads }

export interface EventArgs {
  event: string;
  distinct_id?: Identity | null;
  properties?: Properties | null;
  groups?: Groups | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  set?: Properties | null;
  set_once?: Properties | null;
  unset?: string[];
  disable_geoip?: boolean;
  flags?: Snapshot | null;
  send_feature_flags?: SendFlags;
  send_instantly?: boolean;
  skip_client_rate_limiting?: boolean;
  transport?: Transport;
}
export type SendFlags = boolean | {
  only_evaluate_locally?: boolean;
  person_properties?: Properties;
  group_properties?: GroupProperties;
  flag_keys?: string[] | null;
  device_id?: string;
};
export interface IdentifyArgs {
  distinct_id: Identity;
  set?: Properties | null;
  set_once?: Properties | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
  cancellation?: Cancellation;
}
export interface PersonArgs {
  distinct_id?: Identity | null;
  set?: Properties | null;
  set_once?: Properties | null;
  reload_feature_flags?: boolean;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
}
export interface GroupArgs {
  group_type: string;
  group_key: GroupKey;
  properties?: Properties | null;
  distinct_id?: Identity | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
  cancellation?: Cancellation;
}
export interface AliasArgs {
  alias: Identity;
  distinct_id?: Identity | null;
  properties?: Properties | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
  cancellation?: Cancellation;
}
export interface ExceptionHint {
  mechanism?: {
    handled?: boolean;
    type?: "generic" | "onunhandledrejection" | "onuncaughtexception" | "onconsole" | "middleware";
    source?: string;
    synthetic?: boolean;
  };
  synthetic_exception?: ErrorRef | null;
  skip_first_lines?: integer;
}
export interface ExceptionArgs {
  error: ExceptionInput;
  distinct_id?: Identity | null;
  properties?: Properties | null;
  stack?: Stack;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  groups?: Groups | null;
  flags?: Snapshot | null;
  send_feature_flags?: SendFlags;
  disable_geoip?: boolean;
  hint?: ExceptionHint;
  trace_context?: { trace_id: string; span_id: string };
  fingerprint?: string;
  level?: LogLevel;
}
export interface Evaluation {
  distinct_id?: Identity | null;
  groups?: Groups;
  person_properties?: Properties;
  group_properties?: GroupProperties;
  only_evaluate_locally?: boolean;
  disable_geoip?: boolean;
  device_id?: string;
  flag_keys?: string[] | null;
  cancellation?: Cancellation;
}
export interface FlagRead extends Omit<Evaluation, "flag_keys"> {
  key: string;
  send_event?: boolean;
  fresh?: boolean;
}
export interface ValueRead extends FlagRead { default_value?: Json }
export interface EnabledRead extends FlagRead { default_value?: boolean }
export interface PayloadRead extends Omit<Evaluation, "flag_keys"> {
  key: string;
  match_value?: FlagValue;
  default_value?: Json;
  send_event?: boolean;
}
export interface ContextData {
  distinct_id?: string | null;
  session_id?: string | null;
  device_id?: string | null;
  properties?: Properties;
}
export interface StartSpan {
  kind?: "internal" | "server" | "client" | "producer" | "consumer";
  attributes?: Record<string, SpanValue>;
  parent?: Span | string | null;
  tracestate?: string;
  start_time?: Timestamp;
}
export interface LogArgs {
  body: string;
  level?: LogLevel;
  attributes?: Properties;
  trace_id?: string;
  span_id?: string;
  trace_flags?: integer;
}
export interface MetricArgs {
  name: string;
  value: number;
  unit?: string;
  attributes?: MetricAttributes;
}
export interface BatchArgs { events: EventArgs[]; historical_migration?: boolean }
export interface OptOutArgs { clear_persistence?: boolean }
export interface OptInArgs { capture_event_name?: string | null; capture_properties?: Properties }
export interface RegisterArgs { key: string; value: Json; days?: number | null }
export interface GroupFlagArgs { group_type: string; properties: Properties; reload_feature_flags?: boolean }
export interface ReplayStart {
  resume_current?: boolean;
  override?: {
    sampling?: boolean;
    linked_flag?: boolean;
    url_trigger?: boolean;
    event_trigger?: boolean;
  };
}

export interface SetupArgs {
  project_token: string;
  config?: SetupConfig;
  name?: string;
  runtime_context?: Ref<"runtime">;
}
export interface ResetArgs {
  reset_device_id?: boolean;
  bootstrap?: Bootstrap;
  keep_properties?: string[];
}

export interface Bootstrap {
  distinct_id?: string | null;
  is_identified_id?: boolean;
  feature_flags?: FlagValues | null;
  feature_flag_payloads?: Payloads | null;
  session_id?: string | null;
}

export type PersonProfiles = "always" | "identified_only" | "never";
export type Compression = "none" | "gzip" | "zstd" | "deflate" | "br";
export type CaptureMode = "legacy" | "analytics_v1";
export type Persistence = "memory" | "persistent";
export interface BaseSetupConfig {
  host?: string;
  flags_host?: string | null;
  assets_host?: string | null;
  ui_host?: string | null;
  secret_key?: string;
  flush_at?: integer;
  flush_interval_ms?: DurationMs;
  max_batch_size?: integer;
  max_queue_size?: integer;
  shutdown_timeout_ms?: DurationMs;
  request_timeout_ms?: DurationMs;
  max_retries?: integer;
  retry_delay_ms?: DurationMs;
  max_retry_delay_ms?: DurationMs;
  compression?: Compression;
  capture_mode?: CaptureMode;
  request_headers?: Record<string, string>;
  historical_migration?: boolean;
  enable_full_ai_capture?: boolean;
  preload_feature_flags?: boolean;
  send_feature_flag_events?: boolean;
  disable_remote_feature_flags?: boolean;
  enable_local_evaluation?: boolean;
  only_evaluate_locally?: boolean;
  feature_flags_poll_interval_ms?: DurationMs;
  feature_flag_request_timeout_ms?: DurationMs;
  feature_flag_request_max_retries?: integer;
  evaluation_contexts?: string[];
  flag_keys?: string[] | null;
  feature_flag_cache_ttl_ms?: DurationMs;
  flag_definition_cache_provider?: Ref<"cache_provider">;
  person_profiles?: PersonProfiles;
  opt_out_by_default?: boolean;
  disabled?: boolean;
  is_server?: boolean;
  reuse_anonymous_id?: boolean;
  bootstrap?: Bootstrap;
  super_properties?: Properties;
  anonymous_id_provider?: Callback;
  persistence?: Persistence;
  persistence_name?: string;
  disable_persistence?: boolean;
  storage?: Ref<"storage">;
  session_idle_timeout_ms?: DurationMs;
  persist_session_id_across_restart?: boolean;
  autocapture?: boolean | AutocaptureConfig;
  capture_pageview?: boolean | "history_change" | PageviewConfig;
  capture_pageleave?: boolean;
  capture_application_lifecycle_events?: boolean;
  capture_screen_views?: boolean;
  capture_element_interactions?: boolean;
  set_default_person_properties?: boolean;
  session_replay?: boolean;
  replay?: ReplayConfig;
  error_tracking?: ErrorTrackingConfig;
  logs?: LogsConfig;
  metrics?: MetricsConfig;
  traces?: TracesConfig;
  tracing_headers?: string[];
  surveys?: boolean;
  survey_config?: SurveysConfig;
  capture_push_notification_subscriptions?: boolean;
  capture_push_notification_opened?: boolean;
  push_identity_provider?: Callback;
  debug?: boolean;
  before_send?: Callback[];
  loaded?: Callback;
  on_feature_flags?: Callback;
  on_error?: Callback;
  logger?: Ref<"diagnostic_logger">;
}
export interface AutocaptureConfig {
  dom_event_allowlist?: string[];
  element_allowlist?: string[];
  css_selector_allowlist?: string[];
  url_allowlist?: string[];
  url_ignorelist?: string[];
  capture_copied_text?: boolean;
  capture_synthetic_events?: boolean;
}
export interface PageviewConfig { capture_history_changes?: boolean; capture_hash_changes?: boolean }
export interface ReplayConfig {
  mask_all_text_inputs?: boolean;
  mask_all_text?: boolean;
  mask_all_images?: boolean;
  mask_all_platform_views?: boolean;
  mask_custom_paint?: boolean;
  capture_touches?: boolean;
  capture_network_telemetry?: boolean;
  capture_logs?: boolean;
  capture_native_screens?: boolean;
  screenshot_mode?: boolean;
  throttle_delay_ms?: DurationMs;
  sample_rate?: number | null;
}
export interface ExceptionStepsConfig { enabled?: boolean; max_bytes?: integer }
export interface ExceptionAutoCaptureConfig {
  capture_unhandled_errors?: boolean;
  capture_unhandled_rejections?: boolean;
  capture_console_errors?: boolean;
}
export interface ErrorTrackingConfig {
  auto_capture?: boolean;
  in_app_includes?: string[];
  in_app_excludes?: string[];
  in_app_by_default?: boolean;
  ignored_exception_types?: string[];
  exception_steps?: ExceptionStepsConfig;
}
export interface LogRateCap { max_logs?: integer; window_ms?: DurationMs }
export interface LogsConfig {
  service_name?: string;
  service_version?: string;
  environment?: string;
  resource_attributes?: Properties;
  flush_interval_ms?: DurationMs;
  flush_at?: integer;
  max_queue_size?: integer;
  max_batch_records_per_post?: integer;
  rate_cap?: LogRateCap;
  before_send?: Callback[];
  capture_console_logs?: boolean;
}
export interface NetworkMetricsConfig { name?: string | Callback; attributes?: Callback }
export interface MetricsConfig {
  service_name?: string;
  service_version?: string;
  environment?: string;
  resource_attributes?: MetricAttributes;
  flush_interval_ms?: DurationMs;
  max_series_per_flush?: integer;
  before_send?: Callback[];
  network?: boolean | NetworkMetricsConfig;
}
export interface TracesConfig {
  service_name?: string;
  service_version?: string;
  environment?: string;
  resource_attributes?: Record<string, SpanValue>;
  flush_interval_ms?: DurationMs;
  max_export_batch_size?: integer;
  max_queue_size?: integer;
  max_attributes_per_span?: integer;
  max_events_per_span?: integer;
  max_attribute_value_length?: integer;
  max_live_spans?: integer;
  max_span_age_ms?: DurationMs;
  before_span_send?: Callback[];
}
export interface SurveysConfig {
  prefill_from_url?: boolean;
  delegate?: Ref<"surveys_delegate">;
  override_display_language?: string | null;
}

export type SetConfig = Omit<BaseSetupConfig,
  "secret_key" | "capture_mode" | "bootstrap" | "super_properties" |
  "anonymous_id_provider" | "persistence" | "persistence_name" | "storage" |
  "is_server" | "reuse_anonymous_id" | "persist_session_id_across_restart"
>;

export type EarlyAccessStage = "concept" | "alpha" | "beta" | "general-availability";
export type SurveyPosition = "top_left" | "top_center" | "top_right" |
  "middle_left" | "middle_center" | "middle_right" |
  "left" | "center" | "right" | "next_to_trigger";
export type SurveyResponse = string | string[] | number | null;
export interface DisplaySurveyBase {
  ignore_conditions?: boolean;
  ignore_delay?: boolean;
  properties?: Properties;
}
export type DisplaySurvey = DisplaySurveyBase & (
  { display_type?: "popover"; position?: SurveyPosition; selector?: string;
    initial_responses?: Record<QuestionIndex, SurveyResponse>; skip_shown_event?: boolean } |
  { display_type: "inline"; selector: string }
);
export interface Survey { id: string; name: string; questions: Properties[]; [field: string]: Json }
export type BatchSummary = Ref<"batch_summary">;
export interface SessionTransfer { __posthog?: { id: string; startTime: number } }
export interface SurveyRenderReason { visible: boolean; disabled_reason?: string }
export interface DeepLinkArgs { url: string; referrer?: string }
export interface PushOpenedArgs {
  title?: string | null;
  subtitle?: string | null;
  body?: string | null;
  payload?: Properties | null;
  action?: string | null;
}
export interface FlagOverrides { flags?: FlagValues | null; payloads?: Payloads | null }

/** @pattern ^(0|[1-9][0-9]*)$ */
export type QuestionIndex = string;

/** Approved capture-amendment-v1: initialization-wide GeoIP and analytics-v1 event controls.
 * Omitted fields retain native defaults; false is an explicitly supplied value.
 */
export interface SetupConfig extends BaseSetupConfig {
  disable_geoip?: boolean;
}

/** Analytics-v1 event-root options, separate from ordinary event properties. */
export interface CaptureOptions {
  cookieless_mode?: boolean;
  disable_skew_correction?: boolean;
  process_person_profile?: boolean;
  product_tour_id?: string;
}

/** Applies to /capture only; shared EventArgs consumers retain the base signature. */
export interface CaptureArgs extends EventArgs {
  options?: CaptureOptions;
}

/** Approved flag-semantics-v1 policy overlay.
 * /on_feature_flags delivers the native enabled keys, values/variants and optional
 * loading context, immediately when already loaded and on subsequent native
 * notifications (including changes/errors). It returns actual deregistration.
 * A notification is not evidence of a new successful HTTP response. Missing
 * arguments and undefined outcomes remain distinct from false. Undefined context
 * properties project to absent JSON properties; no getter fabricates arguments.
 * No-argument flush/reload completion callbacks retain the readiness signature.
 *
 * Native startup, getter and evaluated-result cache behavior supersedes the base
 * universal preload=true and TTL=300000 policy for ordinary flag operations.
 * Omitted settings retain native behavior; supported explicit native settings,
 * only_evaluate_locally and send_event retain their meaning. No adapter imposes
 * startup/cache defaults. Unavailable behavior is unsupported, not emulated.
 * Server lifecycle scenarios observe native initialization/capture silence.
 * Remote getter scenarios start with empty storage and no installed local
 * definitions/results; repeated remote getters require a native uncached getter.
 * Client scenarios explicitly load flags or prepare cached state before reading.
 * ExecutionProfile.sdk_type optionally declares client/server SDK type explicitly,
 * independently of runtime family, identity and wire API. Selected type-specific
 * cases with no declaration are blocked_contract; an opposite type is not applicable.
 * flags_v2 declares the wire API independently of SDK type/platform;
 * flags_getter_remote_uncached declares only a native remote getter without local
 * evaluation or evaluated-result caching, not startup/capture behavior.
 */
export interface FeatureFlagsCallbackContext {
  errorsLoading?: boolean;
}
export type FeatureFlagsCallbackArguments = [string[], FlagValues] | [string[], FlagValues, FeatureFlagsCallbackContext];

export type SDKType = "client" | "server";

/** Approved local-evaluation-v1 overlay.
 * For SDKs declaring feature_flags_local_evaluation_v1, /reload_feature_flags
 * may invoke the native public definitions refresh operation. Its arguments and
 * void result are unchanged. Client evaluation reloads/callbacks are unchanged.
 * Completion is not readiness: a local migration barrier additionally observes
 * public local readiness and a NEW authenticated definitions HTTP 200 after the
 * barrier starts, all within one 5000ms monotonic deadline. Both service paths
 * (flags/definitions and api/feature_flag/local_evaluation) are valid.
 * Setup personal_api_key maps only to config.secret_key; omitted inputs retain
 * the native defaults specified by flag-semantics-v1.
 *
 * flags.evaluation_provenance.v1 observes the actual native evaluator under the
 * owning public invocation, never an inferred result from inputs/no HTTP/counters.
 * Records are fixture-scoped, bounded to its lifetime and disposed on close.
 * Missing instrumentation is blocked_fixture. Unknown/foreign call IDs must not
 * borrow another call's record. Observation cannot invoke a getter or mutate state.
 * The plain public getter result is unchanged; no alternate getter is substituted.
 */
/** @minLength 1 */
export type EvaluationObservationId = string;
export interface EvaluationProvenanceCommand {
  kind: 'evaluation_provenance';
  call_id: EvaluationObservationId;
}
export type EvaluationProvenance = {
  layer: 'native_component';
  implementation: EvaluationObservationId;
  call_id: EvaluationObservationId;
  key: EvaluationObservationId;
} & (
  { resolution: 'local' | 'remote'; value: boolean | string } |
  { resolution: 'fallback' | 'not_evaluated' }
);

export type CatalogHash = "c52ae7fac46f0395a78276bbc6c3b97ea83538005bcee11b60b2dc33879adfaa";

export type OpSetupArgs = SetupArgs;
export type OpSetupResult = { kind: "void" };

export type OpShutdownArgs = { timeout_ms?: DurationMs; cancellation?: Cancellation };
export type OpShutdownResult = { kind: "void" };

export type OpFlushArgs = { timeout_ms?: DurationMs; callback?: Callback };
export type OpFlushResult = { kind: "void" };

export type OpDebugArgs = { enabled?: boolean };
export type OpDebugResult = { kind: "void" };

export type OpOptInArgs = OptInArgs;
export type OpOptInResult = { kind: "void" };

export type OpOptOutArgs = OptOutArgs;
export type OpOptOutResult = { kind: "void" };

export type OpIsOptOutArgs = Record<string, never>;
export type OpIsOptOutResult = { kind: "value"; value: boolean };

export type OpResetArgs = ResetArgs;
export type OpResetResult = { kind: "void" };

export type OpGetDistinctIdArgs = Record<string, never>;
export type OpGetDistinctIdResult = { kind: "value"; value: string };

export type OpGetAnonymousIdArgs = Record<string, never>;
export type OpGetAnonymousIdResult = { kind: "value"; value: string };

export type OpGetSessionIdArgs = Record<string, never>;
export type OpGetSessionIdResult = { kind: "value"; value: string | null };

export type OpCaptureArgs = CaptureArgs;
export type OpCaptureResult = { kind: "void" };

export type OpCaptureImmediateArgs = EventArgs;
export type OpCaptureImmediateResult = { kind: "void" };

export type OpCaptureAiArgs = EventArgs;
export type OpCaptureAiResult = { kind: "value"; value: string | null };

export type OpCaptureExceptionArgs = ExceptionArgs;
export type OpCaptureExceptionResult = { kind: "void" };

export type OpAddExceptionStepArgs = { message: string; properties?: Properties };
export type OpAddExceptionStepResult = { kind: "void" };

export type OpScreenArgs = { name: string; properties?: Properties; distinct_id?: Identity; timestamp?: Timestamp; uuid?: string; disable_geoip?: boolean };
export type OpScreenResult = { kind: "void" };

export type OpIdentifyArgs = IdentifyArgs;
export type OpIdentifyResult = { kind: "void" };

export type OpAliasArgs = AliasArgs;
export type OpAliasResult = { kind: "void" };

export type OpSetPersonPropertiesArgs = PersonArgs;
export type OpSetPersonPropertiesResult = { kind: "void" };

export type OpCreatePersonProfileArgs = Record<string, never>;
export type OpCreatePersonProfileResult = { kind: "void" };

export type OpGroupArgs = GroupArgs;
export type OpGroupResult = { kind: "void" };

export type OpGroupIdentifyArgs = GroupArgs;
export type OpGroupIdentifyResult = { kind: "void" };

export type OpRegisterArgs = RegisterArgs;
export type OpRegisterResult = { kind: "void" };

export type OpUnregisterArgs = { key: string };
export type OpUnregisterResult = { kind: "void" };

export type OpGetFeatureFlagArgs = ValueRead;
export type OpGetFeatureFlagResult = { kind: "value"; value: Json };

export type OpIsFeatureEnabledArgs = EnabledRead;
export type OpIsFeatureEnabledResult = { kind: "value"; value: boolean };

export type OpGetFeatureFlagPayloadArgs = PayloadRead;
export type OpGetFeatureFlagPayloadResult = { kind: "value"; value: Json };

export type OpGetFeatureFlagResultArgs = FlagRead;
export type OpGetFeatureFlagResultResult = { kind: "value"; value: FlagResult | null };

export type OpGetFeatureFlagsArgs = Evaluation;
export type OpGetFeatureFlagsResult = { kind: "value"; value: FlagValues };

export type OpGetFeatureFlagsAndPayloadsArgs = Evaluation;
export type OpGetFeatureFlagsAndPayloadsResult = { kind: "value"; value: FlagsAndPayloads };

export type OpEvaluateFlagsArgs = Evaluation;
export type OpEvaluateFlagsResult = { kind: "value"; value: Snapshot };

export type OpSnapshotIsEnabledArgs = { key: string; default_value?: boolean };
export type OpSnapshotIsEnabledResult = { kind: "value"; value: boolean };

export type OpSnapshotGetFlagArgs = { key: string };
export type OpSnapshotGetFlagResult = { kind: "value"; value: FlagValue | null };

export type OpSnapshotGetFlagPayloadArgs = { key: string };
export type OpSnapshotGetFlagPayloadResult = { kind: "value"; value: Json };

export type OpSnapshotKeysArgs = Record<string, never>;
export type OpSnapshotKeysResult = { kind: "value"; value: string[] };

export type OpSnapshotOnlyArgs = { keys: string[] };
export type OpSnapshotOnlyResult = { kind: "value"; value: Snapshot };

export type OpSnapshotOnlyAccessedArgs = Record<string, never>;
export type OpSnapshotOnlyAccessedResult = { kind: "value"; value: Snapshot };

export type OpReloadFeatureFlagsArgs = { callback?: Callback; distinct_id?: Identity; send_anonymous_distinct_id?: boolean };
export type OpReloadFeatureFlagsResult = { kind: "void" };

export type OpOnFeatureFlagsArgs = { callback: Callback };
export type OpOnFeatureFlagsResult = { kind: "value"; value: Subscription };

export type OpSubscriptionUnsubscribeArgs = Record<string, never>;
export type OpSubscriptionUnsubscribeResult = { kind: "void" };

export type OpSetPersonPropertiesForFlagsArgs = { properties: Properties; reload_feature_flags?: boolean };
export type OpSetPersonPropertiesForFlagsResult = { kind: "void" };

export type OpResetPersonPropertiesForFlagsArgs = { reload_feature_flags?: boolean };
export type OpResetPersonPropertiesForFlagsResult = { kind: "void" };

export type OpSetGroupPropertiesForFlagsArgs = GroupFlagArgs;
export type OpSetGroupPropertiesForFlagsResult = { kind: "void" };

export type OpResetGroupPropertiesForFlagsArgs = { group_type?: string | null; reload_feature_flags?: boolean };
export type OpResetGroupPropertiesForFlagsResult = { kind: "void" };

export type OpStartSessionRecordingArgs = ReplayStart;
export type OpStartSessionRecordingResult = { kind: "void" };

export type OpStopSessionRecordingArgs = Record<string, never>;
export type OpStopSessionRecordingResult = { kind: "void" };

export type OpIsSessionReplayActiveArgs = Record<string, never>;
export type OpIsSessionReplayActiveResult = { kind: "value"; value: boolean };

export type OpCaptureAiImmediateArgs = EventArgs;
export type OpCaptureAiImmediateResult = { kind: "value"; value: string | null };

export type OpIdentifyImmediateArgs = IdentifyArgs;
export type OpIdentifyImmediateResult = { kind: "void" };

export type OpAliasImmediateArgs = AliasArgs;
export type OpAliasImmediateResult = { kind: "void" };

export type OpGroupIdentifyImmediateArgs = GroupArgs;
export type OpGroupIdentifyImmediateResult = { kind: "void" };

export type OpCaptureExceptionImmediateArgs = ExceptionArgs;
export type OpCaptureExceptionImmediateResult = { kind: "void" };

export type OpCaptureBatchArgs = BatchArgs;
export type OpCaptureBatchResult = { kind: "void" };

export type OpCaptureBatchImmediateArgs = BatchArgs;
export type OpCaptureBatchImmediateResult = { kind: "value"; value: BatchSummary };

export type OpSetPersonPropertiesOnceArgs = { distinct_id?: Identity; properties?: Properties; timestamp?: Timestamp; uuid?: string; disable_geoip?: boolean };
export type OpSetPersonPropertiesOnceResult = { kind: "void" };

export type OpUnsetPersonPropertiesArgs = { keys: string[]; distinct_id?: Identity; reload_feature_flags?: boolean };
export type OpUnsetPersonPropertiesResult = { kind: "void" };

export type OpRegisterOnceArgs = { properties: Properties; default_value?: Json; days?: number | null };
export type OpRegisterOnceResult = { kind: "void" };

export type OpRegisterForSessionArgs = { properties: Properties };
export type OpRegisterForSessionResult = { kind: "void" };

export type OpUnregisterForSessionArgs = { key: string };
export type OpUnregisterForSessionResult = { kind: "void" };

export type OpGetPropertyArgs = { key: string };
export type OpGetPropertyResult = { kind: "value"; value: Json };

export type OpGetSessionPropertyArgs = { key: string };
export type OpGetSessionPropertyResult = { kind: "value"; value: Json };

export type OpSetGroupsArgs = { groups: Groups };
export type OpSetGroupsResult = { kind: "void" };

export type OpGetGroupsArgs = Record<string, never>;
export type OpGetGroupsResult = { kind: "value"; value: Groups };

export type OpResetGroupsArgs = Record<string, never>;
export type OpResetGroupsResult = { kind: "void" };

export type OpGetDeviceIdArgs = Record<string, never>;
export type OpGetDeviceIdResult = { kind: "value"; value: string };

export type OpResetSessionIdArgs = Record<string, never>;
export type OpResetSessionIdResult = { kind: "void" };

export type OpStartSessionArgs = Record<string, never>;
export type OpStartSessionResult = { kind: "void" };

export type OpEndSessionArgs = Record<string, never>;
export type OpEndSessionResult = { kind: "void" };

export type OpIsSessionActiveArgs = Record<string, never>;
export type OpIsSessionActiveResult = { kind: "value"; value: boolean };

export type OpGetSessionReplayUrlArgs = { with_timestamp?: boolean; timestamp_look_back?: number };
export type OpGetSessionReplayUrlResult = { kind: "value"; value: string };

export type OpSetConfigArgs = { config: SetConfig };
export type OpSetConfigResult = { kind: "void" };

export type OpIsInitializedArgs = Record<string, never>;
export type OpIsInitializedResult = { kind: "value"; value: boolean };

export type OpIsShutdownArgs = Record<string, never>;
export type OpIsShutdownResult = { kind: "value"; value: boolean };

export type OpPendingEventsArgs = Record<string, never>;
export type OpPendingEventsResult = { kind: "value"; value: integer };

export type OpJoinArgs = Record<string, never>;
export type OpJoinResult = { kind: "void" };

export type OpEnableArgs = Record<string, never>;
export type OpEnableResult = { kind: "void" };

export type OpDisableArgs = Record<string, never>;
export type OpDisableResult = { kind: "void" };

export type OpHasOptedInArgs = Record<string, never>;
export type OpHasOptedInResult = { kind: "value"; value: boolean };

export type OpGetExplicitConsentStatusArgs = Record<string, never>;
export type OpGetExplicitConsentStatusResult = { kind: "value"; value: "granted" | "denied" | "pending" };

export type OpIsCapturingArgs = Record<string, never>;
export type OpIsCapturingResult = { kind: "value"; value: boolean };

export type OpClearConsentArgs = Record<string, never>;
export type OpClearConsentResult = { kind: "void" };

export type OpSetIdentityArgs = { distinct_id: string; hash: string };
export type OpSetIdentityResult = { kind: "void" };

export type OpClearIdentityArgs = Record<string, never>;
export type OpClearIdentityResult = { kind: "void" };

export type OpSetInternalOrTestUserArgs = Record<string, never>;
export type OpSetInternalOrTestUserResult = { kind: "void" };

export type OpDisableGlobalArgs = Record<string, never>;
export type OpDisableGlobalResult = { kind: "void" };

export type OpGlobalIsDisabledArgs = Record<string, never>;
export type OpGlobalIsDisabledResult = { kind: "value"; value: boolean };

export type OpCaptureRawArgs = { message: Properties };
export type OpCaptureRawResult = { kind: "void" };

export type OpGetAllFeatureFlagResultsArgs = Evaluation;
export type OpGetAllFeatureFlagResultsResult = { kind: "value"; value: FlagResult[] };

export type OpGetFeatureFlagPayloadsArgs = Evaluation;
export type OpGetFeatureFlagPayloadsResult = { kind: "value"; value: Payloads };

export type OpGetFeatureFlagDetailsArgs = Record<string, never>;
export type OpGetFeatureFlagDetailsResult = { kind: "value"; value: Properties };

export type OpGetFlagsDecisionArgs = Evaluation;
export type OpGetFlagsDecisionResult = { kind: "value"; value: Properties | null };

export type OpGetRemoteConfigPayloadArgs = { key: string; cancellation?: Cancellation };
export type OpGetRemoteConfigPayloadResult = { kind: "value"; value: Json };

export type OpGetRemoteConfigArgs = Record<string, never>;
export type OpGetRemoteConfigResult = { kind: "value"; value: Properties | null };

export type OpReloadRemoteConfigArgs = Record<string, never>;
export type OpReloadRemoteConfigResult = { kind: "value"; value: Properties | null };

export type OpUpdateFlagsArgs = { flags: FlagValues; payloads?: Payloads; merge?: boolean };
export type OpUpdateFlagsResult = { kind: "void" };

export type OpOverrideFeatureFlagsArgs = { overrides: FlagOverrides | null };
export type OpOverrideFeatureFlagsResult = { kind: "void" };

export type OpClearLocalFlagsCacheArgs = Record<string, never>;
export type OpClearLocalFlagsCacheResult = { kind: "void" };

export type OpIsLocalEvaluationReadyArgs = Record<string, never>;
export type OpIsLocalEvaluationReadyResult = { kind: "value"; value: boolean };

export type OpWaitForLocalEvaluationReadyArgs = { timeout_ms?: DurationMs };
export type OpWaitForLocalEvaluationReadyResult = { kind: "value"; value: boolean };

export type OpEvaluateFeatureFlagLocallyArgs = { flag: Ref<"definition">; distinct_id: string; person_properties: Properties; groups: Groups; group_properties: GroupProperties };
export type OpEvaluateFeatureFlagLocallyResult = { kind: "value"; value: FlagValue | null };

export type OpSnapshotAccessedArgs = Record<string, never>;
export type OpSnapshotAccessedResult = { kind: "value"; value: string[] };

export type OpSnapshotEventPropertiesArgs = Record<string, never>;
export type OpSnapshotEventPropertiesResult = { kind: "value"; value: Properties };

export type OpFlagResultValueArgs = Record<string, never>;
export type OpFlagResultValueResult = { kind: "value"; value: FlagValue | null };

export type OpFlagResultGetVariantArgs = { default_value?: string | null };
export type OpFlagResultGetVariantResult = { kind: "value"; value: string | null };

export type OpFlagResultGetPayloadArgs = { type: Type; default_value?: Json };
export type OpFlagResultGetPayloadResult = { kind: "value"; value: Json };

export type OpOnArgs = { event: string; callback: Callback };
export type OpOnResult = { kind: "value"; value: Subscription };

export type OpOnFeatureFlagArgs = { key: string; callback: Callback };
export type OpOnFeatureFlagResult = { kind: "value"; value: Subscription };

export type OpOnSessionIdArgs = { callback: Callback };
export type OpOnSessionIdResult = { kind: "value"; value: Subscription };

export type OpOnSurveysLoadedArgs = { callback: Callback };
export type OpOnSurveysLoadedResult = { kind: "value"; value: Subscription };

export type OpGetSurveysArgs = { callback: Callback; force_reload?: boolean };
export type OpGetSurveysResult = { kind: "void" };

export type OpGetActiveMatchingSurveysArgs = { callback: Callback; force_reload?: boolean };
export type OpGetActiveMatchingSurveysResult = { kind: "void" };

export type OpRenderSurveyArgs = { survey_id: string; selector: string };
export type OpRenderSurveyResult = { kind: "void" };

export type OpDisplaySurveyArgs = { survey_id: string; options?: DisplaySurvey };
export type OpDisplaySurveyResult = { kind: "void" };

export type OpCancelPendingSurveyArgs = { survey_id: string };
export type OpCancelPendingSurveyResult = { kind: "void" };

export type OpCanRenderSurveyArgs = { survey_id: string };
export type OpCanRenderSurveyResult = { kind: "value"; value: SurveyRenderReason | null };

export type OpCanRenderSurveyAsyncArgs = { survey_id: string; force_reload?: boolean };
export type OpCanRenderSurveyAsyncResult = { kind: "value"; value: SurveyRenderReason };

export type OpGetEarlyAccessFeaturesArgs = { callback: Callback; force_reload?: boolean; stages?: EarlyAccessStage[] };
export type OpGetEarlyAccessFeaturesResult = { kind: "void" };

export type OpUpdateEarlyAccessFeatureEnrollmentArgs = { key: string; is_enrolled: boolean; stage?: EarlyAccessStage };
export type OpUpdateEarlyAccessFeatureEnrollmentResult = { kind: "void" };

export type OpCaptureFeatureViewArgs = { flag: string; variant?: string | null };
export type OpCaptureFeatureViewResult = { kind: "void" };

export type OpCaptureFeatureInteractionArgs = { flag: string; variant?: string | null };
export type OpCaptureFeatureInteractionResult = { kind: "void" };

export type OpStartExceptionAutocaptureArgs = { config?: ExceptionAutoCaptureConfig };
export type OpStartExceptionAutocaptureResult = { kind: "void" };

export type OpStopExceptionAutocaptureArgs = Record<string, never>;
export type OpStopExceptionAutocaptureResult = { kind: "void" };

export type OpCaptureRunZonedGuardedErrorArgs = { error: ExceptionInput; stack?: Stack; properties?: Properties };
export type OpCaptureRunZonedGuardedErrorResult = { kind: "void" };

export type OpIsAutocaptureActiveArgs = Record<string, never>;
export type OpIsAutocaptureActiveResult = { kind: "value"; value: boolean };

export type OpIsRageClickActiveArgs = Record<string, never>;
export type OpIsRageClickActiveResult = { kind: "value"; value: boolean };

export type OpWithContextArgs = { context: ContextData; callback: Callback; fresh?: boolean };
export type OpWithContextResult = { kind: "value"; value: Json };

export type OpEnterContextArgs = { context: ContextData; fresh?: boolean };
export type OpEnterContextResult = { kind: "void" };

export type OpGetContextArgs = Record<string, never>;
export type OpGetContextResult = { kind: "value"; value: ContextData | null };

export type OpNewContextArgs = { fresh?: boolean; capture_exceptions?: boolean };
export type OpNewContextResult = { kind: "value"; value: Context };

export type OpIdentifyContextArgs = { distinct_id: string };
export type OpIdentifyContextResult = { kind: "void" };

export type OpSetContextSessionArgs = { session_id: string };
export type OpSetContextSessionResult = { kind: "void" };

export type OpSetContextDeviceIdArgs = { device_id: string };
export type OpSetContextDeviceIdResult = { kind: "void" };

export type OpTagArgs = { name: string; value: Json };
export type OpTagResult = { kind: "void" };

export type OpGetTagsArgs = Record<string, never>;
export type OpGetTagsResult = { kind: "value"; value: Properties };

export type OpContextFromHeadersArgs = { headers: Record<string, HeaderValue> };
export type OpContextFromHeadersResult = { kind: "value"; value: ContextData };

export type OpSetContextArgs = { context: ContextData };
export type OpSetContextResult = { kind: "void" };

export type OpSetEventContextArgs = { event: string; context: Properties };
export type OpSetEventContextResult = { kind: "void" };

export type OpGetEventContextArgs = { event: string };
export type OpGetEventContextResult = { kind: "value"; value: Properties };

export type OpSetFlagsInContextArgs = { flags: Snapshot };
export type OpSetFlagsInContextResult = { kind: "void" };

export type OpBareCaptureArgs = { event: string; distinct_id: Identity; properties?: Properties };
export type OpBareCaptureResult = { kind: "void" };

export type OpGetLoggerArgs = Record<string, never>;
export type OpGetLoggerResult = { kind: "value"; value: Ref<"logger"> };

export type OpGetMetricsArgs = Record<string, never>;
export type OpGetMetricsResult = { kind: "value"; value: Ref<"metrics"> };

export type OpCaptureLogArgs = LogArgs;
export type OpCaptureLogResult = { kind: "void" };

export type OpLoggerTraceArgs = { body: string; attributes?: Properties };
export type OpLoggerTraceResult = { kind: "void" };

export type OpLoggerDebugArgs = { body: string; attributes?: Properties };
export type OpLoggerDebugResult = { kind: "void" };

export type OpLoggerInfoArgs = { body: string; attributes?: Properties };
export type OpLoggerInfoResult = { kind: "void" };

export type OpLoggerWarnArgs = { body: string; attributes?: Properties };
export type OpLoggerWarnResult = { kind: "void" };

export type OpLoggerErrorArgs = { body: string; attributes?: Properties };
export type OpLoggerErrorResult = { kind: "void" };

export type OpLoggerFatalArgs = { body: string; attributes?: Properties };
export type OpLoggerFatalResult = { kind: "void" };

export type OpFlushLogsArgs = Record<string, never>;
export type OpFlushLogsResult = { kind: "void" };

export type OpMetricsCountArgs = { name: string; value?: number; unit?: string; attributes?: MetricAttributes };
export type OpMetricsCountResult = { kind: "void" };

export type OpMetricsGaugeArgs = MetricArgs;
export type OpMetricsGaugeResult = { kind: "void" };

export type OpMetricsHistogramArgs = MetricArgs;
export type OpMetricsHistogramResult = { kind: "void" };

export type OpMetricsFlushArgs = { transport?: Transport };
export type OpMetricsFlushResult = { kind: "void" };

export type OpStartSpanArgs = { name: string; options?: StartSpan };
export type OpStartSpanResult = { kind: "value"; value: Span };

export type OpWithSpanArgs = { name: string; options?: StartSpan; callback: Callback };
export type OpWithSpanResult = { kind: "value"; value: Json };

export type OpGetActiveSpanArgs = Record<string, never>;
export type OpGetActiveSpanResult = { kind: "value"; value: Span | null };

export type OpSpanSetAttributeArgs = { key: string; value: SpanValue };
export type OpSpanSetAttributeResult = { kind: "value"; value: Span };

export type OpSpanSetAttributesArgs = { attributes: Record<string, SpanValue> };
export type OpSpanSetAttributesResult = { kind: "value"; value: Span };

export type OpSpanAddEventArgs = { name: string; attributes?: Record<string, SpanValue>; timestamp?: Timestamp };
export type OpSpanAddEventResult = { kind: "value"; value: Span };

export type OpSpanSetStatusArgs = { status: "ok" | "error"; message?: string };
export type OpSpanSetStatusResult = { kind: "value"; value: Span };

export type OpSpanRecordExceptionArgs = { error: ExceptionInput };
export type OpSpanRecordExceptionResult = { kind: "value"; value: Span };

export type OpSpanUpdateNameArgs = { name: string };
export type OpSpanUpdateNameResult = { kind: "value"; value: Span };

export type OpSpanTraceparentArgs = Record<string, never>;
export type OpSpanTraceparentResult = { kind: "value"; value: string | null };

export type OpSpanTracestateArgs = Record<string, never>;
export type OpSpanTracestateResult = { kind: "value"; value: string | null };

export type OpSpanEndArgs = { end_time?: Timestamp };
export type OpSpanEndResult = { kind: "void" };

export type OpCaptureTraceFeedbackArgs = { trace_id: string; feedback: string };
export type OpCaptureTraceFeedbackResult = { kind: "void" };

export type OpCaptureTraceMetricArgs = { trace_id: string; name: string; value: string | number | boolean };
export type OpCaptureTraceMetricResult = { kind: "void" };

export type OpRegisterPushNotificationTokenArgs = { device_token: string; app_id?: string };
export type OpRegisterPushNotificationTokenResult = { kind: "void" };

export type OpUnregisterPushNotificationTokenArgs = Record<string, never>;
export type OpUnregisterPushNotificationTokenResult = { kind: "void" };

export type OpCapturePushNotificationOpenedArgs = PushOpenedArgs;
export type OpCapturePushNotificationOpenedResult = { kind: "void" };

export type OpPrewarmPushNotificationOpenCaptureArgs = Record<string, never>;
export type OpPrewarmPushNotificationOpenCaptureResult = { kind: "void" };

export type OpCaptureDeepLinkArgs = DeepLinkArgs;
export type OpCaptureDeepLinkResult = { kind: "void" };

export type OpRecordNetworkRequestArgs = { method: string; url: string; status_code: integer; duration_ms: integer; response_size?: integer };
export type OpRecordNetworkRequestResult = { kind: "void" };

export type OpGetSessionTeleportDataArgs = { subject: Ref<"subject"> };
export type OpGetSessionTeleportDataResult = { kind: "value"; value: SessionTransfer };

export type OpBatchSummarySubmittedArgs = Record<string, never>;
export type OpBatchSummarySubmittedResult = { kind: "value"; value: integer };

export type OpBatchSummaryNotPersistedArgs = Record<string, never>;
export type OpBatchSummaryNotPersistedResult = { kind: "value"; value: integer };

export type OpBatchSummaryAllPersistedArgs = Record<string, never>;
export type OpBatchSummaryAllPersistedResult = { kind: "value"; value: boolean };

export type OpBatchSummaryEventResultsArgs = Record<string, never>;
export type OpBatchSummaryEventResultsResult = { kind: "value"; value: Record<string, Properties> };

export type OperationRoute = "/setup" | "/shutdown" | "/flush" | "/debug" | "/opt_in" | "/opt_out" | "/is_opt_out" | "/reset" | "/get_distinct_id" | "/get_anonymous_id" | "/get_session_id" | "/capture" | "/capture_immediate" | "/capture_ai" | "/capture_exception" | "/add_exception_step" | "/screen" | "/identify" | "/alias" | "/set_person_properties" | "/create_person_profile" | "/group" | "/group_identify" | "/register" | "/unregister" | "/get_feature_flag" | "/is_feature_enabled" | "/get_feature_flag_payload" | "/get_feature_flag_result" | "/get_feature_flags" | "/get_feature_flags_and_payloads" | "/evaluate_flags" | "/snapshot/is_enabled" | "/snapshot/get_flag" | "/snapshot/get_flag_payload" | "/snapshot/keys" | "/snapshot/only" | "/snapshot/only_accessed" | "/reload_feature_flags" | "/on_feature_flags" | "/subscription/unsubscribe" | "/set_person_properties_for_flags" | "/reset_person_properties_for_flags" | "/set_group_properties_for_flags" | "/reset_group_properties_for_flags" | "/start_session_recording" | "/stop_session_recording" | "/is_session_replay_active" | "/capture_ai_immediate" | "/identify_immediate" | "/alias_immediate" | "/group_identify_immediate" | "/capture_exception_immediate" | "/capture_batch" | "/capture_batch_immediate" | "/set_person_properties_once" | "/unset_person_properties" | "/register_once" | "/register_for_session" | "/unregister_for_session" | "/get_property" | "/get_session_property" | "/set_groups" | "/get_groups" | "/reset_groups" | "/get_device_id" | "/reset_session_id" | "/start_session" | "/end_session" | "/is_session_active" | "/get_session_replay_url" | "/set_config" | "/is_initialized" | "/is_shutdown" | "/pending_events" | "/join" | "/enable" | "/disable" | "/has_opted_in" | "/get_explicit_consent_status" | "/is_capturing" | "/clear_consent" | "/set_identity" | "/clear_identity" | "/set_internal_or_test_user" | "/disable_global" | "/global_is_disabled" | "/capture_raw" | "/get_all_feature_flag_results" | "/get_feature_flag_payloads" | "/get_feature_flag_details" | "/get_flags_decision" | "/get_remote_config_payload" | "/get_remote_config" | "/reload_remote_config" | "/update_flags" | "/override_feature_flags" | "/clear_local_flags_cache" | "/is_local_evaluation_ready" | "/wait_for_local_evaluation_ready" | "/evaluate_feature_flag_locally" | "/snapshot/accessed" | "/snapshot/event_properties" | "/flag_result/value" | "/flag_result/get_variant" | "/flag_result/get_payload" | "/on" | "/on_feature_flag" | "/on_session_id" | "/on_surveys_loaded" | "/get_surveys" | "/get_active_matching_surveys" | "/render_survey" | "/display_survey" | "/cancel_pending_survey" | "/can_render_survey" | "/can_render_survey_async" | "/get_early_access_features" | "/update_early_access_feature_enrollment" | "/capture_feature_view" | "/capture_feature_interaction" | "/start_exception_autocapture" | "/stop_exception_autocapture" | "/capture_run_zoned_guarded_error" | "/is_autocapture_active" | "/is_rage_click_active" | "/with_context" | "/enter_context" | "/get_context" | "/new_context" | "/identify_context" | "/set_context_session" | "/set_context_device_id" | "/tag" | "/get_tags" | "/context_from_headers" | "/set_context" | "/set_event_context" | "/get_event_context" | "/set_flags_in_context" | "/bare_capture" | "/get_logger" | "/get_metrics" | "/capture_log" | "/logger/trace" | "/logger/debug" | "/logger/info" | "/logger/warn" | "/logger/error" | "/logger/fatal" | "/flush_logs" | "/metrics/count" | "/metrics/gauge" | "/metrics/histogram" | "/metrics/flush" | "/start_span" | "/with_span" | "/get_active_span" | "/span/set_attribute" | "/span/set_attributes" | "/span/add_event" | "/span/set_status" | "/span/record_exception" | "/span/update_name" | "/span/traceparent" | "/span/tracestate" | "/span/end" | "/capture_trace_feedback" | "/capture_trace_metric" | "/register_push_notification_token" | "/unregister_push_notification_token" | "/capture_push_notification_opened" | "/prewarm_push_notification_open_capture" | "/capture_deep_link" | "/record_network_request" | "/get_session_teleport_data" | "/batch_summary/submitted" | "/batch_summary/not_persisted" | "/batch_summary/all_persisted" | "/batch_summary/event_results";
