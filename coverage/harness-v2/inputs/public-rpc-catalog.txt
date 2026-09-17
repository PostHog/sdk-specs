# Public SDK RPC catalog

**Status: selected shared-contract baseline.** Each operation has one request shape, default policy, result, and behavior. Existing implementations are measured against this target; they do not select a different contract.

This is a documentation baseline, not a runtime-conformance claim. It retains all **174 named operations** from the source inventory and adds four explicit batch-summary accessors and two facade getters. The first 48 are feature-driven; the remaining 132 expose additional public operations. Product and runtime applicability determine which operations can run, not which result counts as correct. [Selection evidence and specification alignment](public-rpc-decisions.md) records the decisions; [the source inventory](public-rpc-source-inventory.md) preserves the pinned implementation observations.

## 1. Invocation and observation

- **One RPC invokes one public SDK operation.** Initialization, public getters, callbacks, and returned-object methods have explicit bindings. Name, argument-position, DTO, and lossless unit translations are allowed. Reserved-event synthesis, registration loops, extra identify/capture/reload/flush calls, and adapter-owned identity or exposure tracking are not.
- **The SDK implements defaults and effects.** Omitted arguments stay omitted; an adapter does not insert the defaults below. A missing option or different native effect/result is a binding gap, not an accepted alternative or a field to discard.
- Preserve omission, explicit null, false, zero, empty strings, maps, and lists. The schemas describe valid requests, not permission to intercept negative SDK tests. The fixture protocol reports an input that the runtime cannot represent separately from an SDK rejection.
- Await a returned asynchronous operation. Do not poll or append calls to extend its completion boundary. Plain returned data can be serialized with equivalent field names/types; serialization cannot invoke additional SDK operations or getters on retained handles. Do not collapse a returned UUID, false, null, undefined, and void into a fabricated success result.
- A stateful installation has ambient identity, super properties, and sessions. A request-scoped instance resolves per-request identity/context without changing installation identity. This is an explicit fixture/instance property, independent of analytics protocol and telemetry lane; `is_server` is attribution, not a switch between these models.
- Clock, storage preparation, restart, connectivity, HTTP responses, UI, and host lifecycle are fixture controls. They do not become SDK RPCs. Restart with retained storage is not `/reset`.

### Transport and references

Every call has a unique call ID, route, arguments, and explicit receiver reference. Omission is absence of a JSON key, never an inserted null. Genuine runtime argument references are encoded separately in `references`, keyed by JSON Pointer relative to args; the corresponding JSON slot is absent. Supplying both a reference and JSON data for the same slot is an invalid envelope. Normal calls use these entries only at reference-typed argument positions. Negative-input fixtures may additionally place a `value` reference at the exact argument location under test; they do not add new method parameters. A JSON object resembling a reference inside properties remains ordinary data. References are scoped to one fixture execution and cannot be reused after teardown. Setup binds an instance fixture; later operations use that receiver. A data result can additionally carry a retained-object reference for subsequent explicit method calls.

An outcome is one of **void**, **value**, **undefined**, or **thrown**. A value can itself be null. These tags preserve observations; the operation's result column determines which outcome conforms. `void` includes equivalent Unit/void-returning asynchronous completion, not a discarded data result. A runner timeout or unsupported binding is a harness outcome, not an SDK return value.

A callback fixture has a declared signature and records ordered invocations, arguments, returned values, and errors. Hooks execute in the SDK's call context. A context/span callback can run an explicit nested scenario continuation; every nested SDK call has its own call ID. An adapter cannot replay that continuation later in a different request context. An unsubscribe reference invokes actual deregistration, rather than hiding subsequent observations.

```typescript
type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Properties = Record<string, Json>;
type integer = number;
type Identity = string;
type GroupKey = string;
type Groups = Record<string, GroupKey>;
type GroupProperties = Record<string, Properties>;
type Timestamp = string;
type DurationMs = number;
type FlagValue = boolean | string;
type FlagValues = Record<string, FlagValue>;
type Payloads = Record<string, Json>;
type HeaderValue = string | string[];
type MetricAttributes = Record<string, string | number | boolean>;
type SpanValue = Json;
type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | "fatal";
type Transport = "XHR" | "fetch" | "sendBeacon";
type RefKind = "instance" | "exception" | "stack" | "callback" | "snapshot" |
  "flag_result" | "span" | "subscription" | "context" | "cancellation" |
  "type" | "runtime" | "definition" | "cache_provider" | "storage" |
  "logger" | "metrics" | "diagnostic_logger" | "surveys_delegate" | "subject" | "batch_summary" | "value";
interface Ref<K extends RefKind> { kind: K; id: string }
type SpecialValueFixture = { value: "undefined" | "nan" | "positive_infinity" | "negative_infinity" } |
  { value: "bigint"; decimal: string };
type Instance = Ref<"instance">;
type ErrorRef = Ref<"exception">;
type Stack = Ref<"stack">;
type Callback = Ref<"callback">;
type Snapshot = Ref<"snapshot">;
type FlagResultRef = Ref<"flag_result">;
type Span = Ref<"span">;
type Subscription = Ref<"subscription">;
type Context = Ref<"context">;
type Cancellation = Ref<"cancellation">;
type Type = Ref<"type">;
type ExceptionInput = ErrorRef | Json;
interface Invoke {
  call_id: string;
  route: string;
  receiver: Ref<RefKind>;
  args: Properties;
  references?: Record<string, Ref<RefKind>>;
}
type Outcome = { kind: "void" } | { kind: "undefined" } |
  { kind: "value"; value: Json | Ref<RefKind>; retained?: Ref<RefKind> } |
  { kind: "thrown"; error: ErrorRef };
interface FlagResult {
  key: string;
  enabled: boolean;
  variant: string | null;
  payload: Json;
}
interface FlagsAndPayloads { flags: FlagValues; payloads: Payloads }
```

Identities/group keys are strings, not stringified numbers or platform subjects. Identity strings supplied to identity-changing operations must be nonempty and non-whitespace. `Timestamp` is RFC 3339 with an explicit offset and up to nine fractional digits; serialization uses the equivalent UTC instant without dropping supplied precision. A duration is finite milliseconds; `integer` additionally excludes fractions. JSON numbers must be finite. References to actual exceptions/stacks preserve native capture paths; a JSON object with `type` and `message` is a non-error thrown value, not a manufactured runtime exception.

For flag results, no flag is `null`; a present false flag is `{key, enabled: false, variant: null, payload: ...}`. Missing payload is null; the payload maps retain presence so a present null-valued payload can still be distinguished from an absent key. Typed decoding is a separate operation, not implicit payload serialization.

## 2. Shared argument records

Optional fields use the defaults in §4 unless a record or operation states otherwise. A nullable property-map argument defaults to null (no supplied map); null members *inside* a supplied map remain values. Ordinary properties are not interpreted as extra configuration or argument aliases.

```typescript
interface EventArgs {
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
type SendFlags = boolean | {
  only_evaluate_locally?: boolean;
  person_properties?: Properties;
  group_properties?: GroupProperties;
  flag_keys?: string[] | null;
  device_id?: string;
};
interface IdentifyArgs {
  distinct_id: Identity;
  set?: Properties | null;
  set_once?: Properties | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
  cancellation?: Cancellation;
}
interface PersonArgs {
  distinct_id?: Identity | null;
  set?: Properties | null;
  set_once?: Properties | null;
  reload_feature_flags?: boolean;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
}
interface GroupArgs {
  group_type: string;
  group_key: GroupKey;
  properties?: Properties | null;
  distinct_id?: Identity | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
  cancellation?: Cancellation;
}
interface AliasArgs {
  alias: Identity;
  distinct_id?: Identity | null;
  properties?: Properties | null;
  timestamp?: Timestamp | null;
  uuid?: string | null;
  disable_geoip?: boolean;
  cancellation?: Cancellation;
}
interface ExceptionHint {
  mechanism?: {
    handled?: boolean;
    type?: "generic" | "onunhandledrejection" | "onuncaughtexception" | "onconsole" | "middleware";
    source?: string;
    synthetic?: boolean;
  };
  synthetic_exception?: ErrorRef | null;
  skip_first_lines?: integer;
}
interface ExceptionArgs {
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
interface Evaluation {
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
interface FlagRead extends Omit<Evaluation, "flag_keys"> {
  key: string;
  send_event?: boolean;
  fresh?: boolean;
}
interface ValueRead extends FlagRead { default_value?: Json }
interface EnabledRead extends FlagRead { default_value?: boolean }
interface PayloadRead extends Omit<Evaluation, "flag_keys"> {
  key: string;
  match_value?: FlagValue;
  default_value?: Json;
  send_event?: boolean;
}
interface ContextData {
  distinct_id?: string | null;
  session_id?: string | null;
  device_id?: string | null;
  properties?: Properties;
}
interface StartSpan {
  kind?: "internal" | "server" | "client" | "producer" | "consumer";
  attributes?: Record<string, SpanValue>;
  parent?: Span | string | null;
  tracestate?: string;
  start_time?: Timestamp;
}
interface LogArgs {
  body: string;
  level?: LogLevel;
  attributes?: Properties;
  trace_id?: string;
  span_id?: string;
  trace_flags?: integer;
}
interface MetricArgs {
  name: string;
  value: number;
  unit?: string;
  attributes?: MetricAttributes;
}
interface BatchArgs { events: EventArgs[]; historical_migration?: boolean }
interface OptOutArgs { clear_persistence?: boolean }
interface OptInArgs { capture_event_name?: string | null; capture_properties?: Properties }
interface RegisterArgs { key: string; value: Json; days?: number | null }
interface GroupFlagArgs { group_type: string; properties: Properties; reload_feature_flags?: boolean }
interface ReplayStart {
  resume_current?: boolean;
  override?: {
    sampling?: boolean;
    linked_flag?: boolean;
    url_trigger?: boolean;
    event_trigger?: boolean;
  };
}
```

`set` and `set_once` are separate person-property maps, not an additional ambiguous `properties` envelope on identify. `alias` is the target and `distinct_id` is the source. Group profile properties are stored under `$group_set`; membership is a distinct operation. `ExceptionArgs` has one identity/properties/groups location and a paired trace/span context; its level defaults to error. A supplied stack is used before stack synthesis.

## 3. Setup, configuration, and bootstrap

<a id="setupargs"></a>
### SetupArgs

Bootstrap identity is **`config.bootstrap.distinct_id`**; **`config.bootstrap.is_identified_id`** selects identified versus anonymous identity.

```typescript
interface SetupArgs {
  project_token: string;
  config?: SetupConfig;
  name?: string;
  runtime_context?: Ref<"runtime">;
}
interface ResetArgs {
  reset_device_id?: boolean;
  bootstrap?: Bootstrap;
  keep_properties?: string[];
}
```

<a id="bootstrap"></a>
### Bootstrap

```typescript
interface Bootstrap {
  distinct_id?: string | null;
  is_identified_id?: boolean;
  feature_flags?: FlagValues | null;
  feature_flag_payloads?: Payloads | null;
  session_id?: string | null;
}
```

- Omitted/null `distinct_id` supplies no identity seed; an empty/whitespace ID is ignored. Omitted `is_identified_id` is false. Null is not a valid boolean. A flag seed does not implicitly identify a user.
- Setup owns identity reconciliation. A persisted identified identity wins over a conflicting anonymous bootstrap; an identified bootstrap can replace an anonymous identity. A same-ID identified seed upgrades anonymous state without emitting a redundant `$identify` event. A different identified seed preserves an already-identified local user and warns; it merges an anonymous local user inside setup, including local reconciliation while opted out. Any identity event is suppressed by consent, not synthesized by an adapter.
- Enabled bootstrap flag values (true/nonempty variants) are immediately readable. A supplied nonempty enabled bootstrap snapshot replaces persisted flags. A complete remote response replaces the served flag/payload set, dropping absent keys and stale payloads. A partial response (requested key subset) or a response reporting computation errors merges the recomputed keys instead, retaining un-recomputed flags and their paired payloads. Flags/payloads remain paired; unavailable/orphan payloads do not invent enabled flags. Merely seeding flags emits no exposure.
- Applying served bootstrap flags fires the same no-argument readiness notification used for a successful load, before and independently of the first remote response.
- Omitted/null seed maps mean no seed. Empty maps are explicit empty seed inputs. False and empty-string flag members remain supplied inputs; the SDK applies the enabled-only bootstrap rule.
- A session seed continues an existing session. It must be a user-unique UUIDv7 whose timestamp is no later than the first event, and whose final event is less than 24 hours after that timestamp. Omitted/null means no session seed. A stateful SDK without continuation support has a gap, not a different Bootstrap type.
- Reset uses **`bootstrap`**, not `config.bootstrap`. Reset first clears resettable state and then applies the supplied seed. Fixture storage clearing is not part of binding either operation.

Identified bootstrap:

```json
{
  "project_token": "test-token",
  "config": {
    "bootstrap": {
      "distinct_id": "user-123",
      "is_identified_id": true,
      "feature_flags": {"beta-ui": true, "checkout": "blue"},
      "feature_flag_payloads": {"checkout": {"button": "Continue"}}
    }
  }
}
```

Anonymous bootstrap:

```json
{
  "project_token": "test-token",
  "config": {
    "bootstrap": {"distinct_id": "anonymous-123", "is_identified_id": false}
  }
}
```

<a id="setupconfig"></a>
### SetupConfig

All fields below belong to one schema. Definitions are not selected by implementation. Runtime-only inputs use the shared reference protocol. Configuration cannot contain arbitrary extra native-option dictionaries.

```typescript
type PersonProfiles = "always" | "identified_only" | "never";
type Compression = "none" | "gzip" | "zstd" | "deflate" | "br";
type CaptureMode = "legacy" | "analytics_v1";
type Persistence = "memory" | "persistent";
interface SetupConfig {
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
interface AutocaptureConfig {
  dom_event_allowlist?: string[];
  element_allowlist?: string[];
  css_selector_allowlist?: string[];
  url_allowlist?: string[];
  url_ignorelist?: string[];
  capture_copied_text?: boolean;
  capture_synthetic_events?: boolean;
}
interface PageviewConfig { capture_history_changes?: boolean; capture_hash_changes?: boolean }
interface ReplayConfig {
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
interface ExceptionStepsConfig { enabled?: boolean; max_bytes?: integer }
interface ExceptionAutoCaptureConfig {
  capture_unhandled_errors?: boolean;
  capture_unhandled_rejections?: boolean;
  capture_console_errors?: boolean;
}
interface ErrorTrackingConfig {
  auto_capture?: boolean;
  in_app_includes?: string[];
  in_app_excludes?: string[];
  in_app_by_default?: boolean;
  ignored_exception_types?: string[];
  exception_steps?: ExceptionStepsConfig;
}
interface LogRateCap { max_logs?: integer; window_ms?: DurationMs }
interface LogsConfig {
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
interface NetworkMetricsConfig { name?: string | Callback; attributes?: Callback }
interface MetricsConfig {
  service_name?: string;
  service_version?: string;
  environment?: string;
  resource_attributes?: MetricAttributes;
  flush_interval_ms?: DurationMs;
  max_series_per_flush?: integer;
  before_send?: Callback[];
  network?: boolean | NetworkMetricsConfig;
}
interface TracesConfig {
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
interface SurveysConfig {
  prefill_from_url?: boolean;
  delegate?: Ref<"surveys_delegate">;
  override_display_language?: string | null;
}
```

`logs.flush_at` is a send trigger; `logs.max_queue_size` is the hard retained-record bound; `logs.max_batch_records_per_post` bounds one POST. They are not aliases. Log overflow evicts oldest records. Protocol and compression remain independent; legacy analytics accepts none/gzip. Other algorithm choices apply to analytics-v1 and must not silently change the selected protocol. `persistence` selects storage lifetime, not a platform storage API: persistent state survives fixture restart; memory state does not.

<a id="setconfig"></a>
### SetConfig

`/set_config` changes live configuration in one SDK call, without reconstructing the client. Omitted top-level fields stay unchanged. Each supplied top-level field replaces its previous value, including maps, lists, and nested records. Omitted members of a replacement nested record use the documented defaults. A null resets only a field explicitly declared nullable. Identity bootstrapping, storage selection, credentials, and ingestion protocol are initialization-time choices rather than live identity/reset operations.

```typescript
type SetConfig = Omit<SetupConfig,
  "secret_key" | "capture_mode" | "bootstrap" | "super_properties" |
  "anonymous_id_provider" | "persistence" | "persistence_name" | "storage" |
  "is_server" | "reuse_anonymous_id" | "persist_session_id_across_restart"
>;
```

## 4. Defaults and completion

These are target defaults, not values for an adapter to fill. A reference to a configured value means the same precedence rule on every implementation. When evidence did not establish a plurality, a concrete initial policy was selected; the decision ledger distinguishes that from measured consensus.

| Field or family | Default / interpretation |
|---|---|
| Setup host | `https://us.i.posthog.com`; flags/assets/UI host omitted/null inherit host |
| Setup name | `default`; receiver selection remains explicit |
| Secret key, instance providers, storage/logger/delegate references | Absent; use the SDK's built-in provider for the declared role. No fabricated callback |
| Queue | `flush_at=20`, `flush_interval_ms=30000`, `max_batch_size=50`, `max_queue_size=1000` |
| Timeouts | `request_timeout_ms=10000`, `shutdown_timeout_ms=30000`; flush `timeout_ms=30000` |
| Retry | `max_retries=3`, `retry_delay_ms=3000`, `max_retry_delay_ms=30000`; counts exclude the initial attempt, exponential backoff, zero retries disables |
| Protocol / headers | capture_mode=legacy, compression=gzip, request_headers={}, historical_migration=false; a supplied header map merges with required protocol headers, not over them |
| Flag requests | One retry, initial backoff 300ms; `feature_flag_request_timeout_ms=10000`; same input on retry |
| Flag startup/tracking | `preload_feature_flags=true`, `send_feature_flag_events=true`, `disable_remote_feature_flags=false` |
| Local evaluation | Enabled when secret_key is supplied; otherwise false. `only_evaluate_locally=false` permits fallback, not forced remote evaluation |
| Flag definitions/cache | Poll every 30000ms; evaluated-result `feature_flag_cache_ttl_ms=300000`; contexts omitted/empty impose no environment filter |
| `flag_keys` | Omitted/null unscoped; empty list evaluates none; nonempty scopes evaluation, not just the returned map |
| Person processing | `person_profiles=identified_only`, `reuse_anonymous_id=false`, `is_server=false` (attribution only) |
| Consent/diagnostics | `opt_out_by_default=false`, `disabled=false`, `debug=false`; calling `/debug` with enabled omitted enables diagnostics |
| Persistence | `persistent`, `persistence_name=""` (project-scoped default namespace), `disable_persistence=false` |
| Sessions | Idle timeout 1800000ms; `persist_session_id_across_restart=false`; reset_device_id=false; keep_properties=[] |
| Automatic capture | `autocapture=true`, `capture_pageview=true`, `capture_pageleave=true`, lifecycle/screen/default-person properties=true; element interactions=false |
| Autocapture record | Missing allowlists impose no extra restriction; ignorelist=[]; copied text and synthetic events=false |
| Pageview record | history changes=true; hash changes=false. Boolean true captures initial view; `history_change` also captures history navigation |
| Replay | `session_replay=false`; mask inputs/text/images/platform views=true; custom paint=false; touches/network=true; logs/native screens/screenshot mode=false; throttle=1000ms; sample_rate=null uses remote sampling |
| Error tracking | auto_capture=false; in_app_by_default=true; include/exclude/ignored-type lists=[]; includes win over excludes |
| Exception steps | enabled=true, max_bytes=32768 (UTF-8 bytes) |
| Exception hint | mechanism handled=true, type=generic, synthetic=false; skip_first_lines=0; source/synthetic_exception absent |
| Exception autocapture start | All three error/rejection/console switches=true when config is omitted; explicit false disables that source |
| Logs | flush 30000ms; threshold 20; capacity 1000; records/POST 50; rate cap 500 per 10000ms; console capture=false |
| Metrics | flush 10000ms; max_series_per_flush=1000; network=false; count value=1; no unit or attributes supplied |
| Traces | Disabled when config is absent; a traces record enables it. Flush 5000ms; batch 512; queue 2048; attributes/span 128; events/span 128; value length 8192; live spans 10000; max age 3600000ms |
| Telemetry resource fields | service_name resolves host application identity; service_version resolves application version or empty string; environment absent; resource_attributes={} |
| Surveys | enabled=true; prefill_from_url=false; display language omitted/null uses host locale |
| Push | automatic subscriptions/open capture=true; provider callback absent; app_id resolves the host application's push-provider identity |
| Tracing headers | `[]`: disabled. Normalize hostname case and remove a terminal dot; exact hostname membership only, not substring matching |
| Full AI capture | false; wrapper-only routing/media/truncation change; privacy mode takes precedence; manual AI payloads are unaffected |
| Hooks | before_send/before_span_send=[]; other callbacks absent. A hook returning null or throwing drops the item and stops the chain |
| Capture options | send_instantly=false, skip_client_rate_limiting=false, send_feature_flags=false, transport=fetch, disable_geoip=false; unset=[] |
| Missing timestamp / UUID | Omitted/null timestamp uses call-time clock; omitted/null UUID generates UUIDv7 inside the SDK |
| Per-call flag tracking | Ordinary value/enabled/result reads inherit send_feature_flag_events; payload send_event=false; bulk getters are silent |
| Flag fallback / refresh | get value/payload default=null; enabled default=false; fresh=false; override setters reload_feature_flags=true |
| Register | No per-call expiration by default (days=null); explicit positive days is expiration from the call. register_once default_value="None" |
| Opt in/out | clear_persistence=false; opt-in emits no consent event unless capture_event_name is a supplied nonempty name |
| Replay start | resume_current=true; all override gates=false |
| Span | kind=internal; parent omitted inherits active span, null starts a root; start/end/event timestamps use call-time clock |
| Force/merge/context switches | force_reload=false, merge=false, fresh=false, capture_exceptions=true; historical_migration=false; send_anonymous_distinct_id=true |
| Survey display | popover; ignore_conditions=false; ignore_delay=false; position=right; initial_responses={}; skip_shown_event=false |
| Trace feedback/metrics | Trace IDs are strings; no coercion from numeric IDs. No optional metric value when a value is required |
| Network/replay URL helpers | response_size=0; with_timestamp=false; timestamp_look_back=10 seconds |
| Remaining optional data | Properties/attributes/tags/resource maps={}, unset/keep key lists=[], send-flags object maps={}; absent IDs, matching value, unit, stage, referrer, trace fields, and status text supply no override. No automatic dummy values are supplied. |

Positive limits and intervals must be finite; capacities/counts must be integral. Zero retries disables retries; zero timeout means no waiting; zero sample rate means no sampling; zero log rate-cap max disables that cap. Other zero/negative limits are invalid, not replacements for omission. Empty strings/maps/lists retain their field-specific meanings. Setup numeric/type validation errors leave the instance uninitialized; capture/query invalid-value behavior follows the operation's no-throw or fallback rule.

**Completion:** ordinary capture/profile/log/metric calls return void after synchronous SDK admission/validation work; they are not delivery receipts. AI capture returns the admitted UUID or null when rejected. Immediate calls complete after their own send attempt; batch-immediate returns a retained summary with separate accessors. Flush returns void after attempting the bounded set of eligible records present at its start across events, replay, logs, and traces; it does not wait for concurrent future producers or guarantee server ingestion. Failure retains/drops data according to the relevant pipeline's retry policy. Shutdown attempts that bounded drain, closes resources, and then completes. No adapter retries or polling are implied. Configuration and identity mutations are visible to subsequent calls in the same execution context once the operation completes.

## 5. Shared behavior

### Identity, consent, profiles, and capture

- Capture identity precedence: explicit per-call identity, then active request/installation context. A request-scoped capture with neither uses an SDK-generated event-local personless ID and disables person processing. This does not identify anyone or create persistent client identity. Explicit empty identity is invalid, not a fallback request.
- Identify requires an ID. Omission/empty/whitespace causes no identity mutation or event. A stateful anonymous-to-new-ID transition links identities; same anonymous ID transitions through `$set`; repeated identified ID with no properties is a no-op. A different already-identified ID requires reset first. Request-scoped identify is a stateless profile operation.
- Alias uses an explicit source when supplied, otherwise ambient client identity. A request-scoped alias requires a resolved source. Target is always `alias`; source is always `distinct_id`. Both are emitted as `$create_alias` source/target data, including `properties.distinct_id`; alias does not change current identity. The optional properties map supplies ordinary alias-event properties; authoritative `properties.alias` and `properties.distinct_id` overwrite conflicting caller keys.
- Register sets **one key/value**. A map-based native call can receive a single-entry map as a shape translation; an adapter cannot implement a bulk request by looping. Per-event properties win over registered properties. SDK-owned identity/session/envelope fields retain their specified authority.
- Group changes membership; group_identify updates a group profile without changing membership. Profile properties live under `$group_set`, not duplicated at the event-property root. Group flag overrides take one group type plus properties and do not establish or change a group key.
- Screen emits `$screen` and remembers current screen context for subsequent events/replay until the next screen or reset. It is runtime context, not persistent user identity across restart.
- Opt-out persists consent, blocks capture, and stops capture integrations. Default opt-out retains identity/super properties; clear_persistence=true removes them while retaining the denial. Opt-in permits future capture; dropped items are not recreated. Repeated transitions are harmless. `/clear_consent` removes the explicit choice and restores the configured default.
- Reset clears current identified identity, super properties except kept keys, groups, flag overrides/results, and session context. It returns to anonymous state, preserving device ID unless reset_device_id=true. reuse_anonymous_id controls reuse versus a new anonymous ID. Reset clears explicit consent and restores opt_out_by_default, including on restart. Queued logs and exception-step history follow their dedicated retention rules, not fixture teardown.
- Null-valued object properties are removed by the SDK's capture serializer recursively; array positions are retained. Evaluation-context nulls remain meaningful. Hooks receive assembled data and may modify/drop it before admission. SDK failures in event/error/log capture do not throw into the host application.

### Flags and snapshots

- Stateful getters read cached values. Request-scoped getters perform evaluation for the explicit/active context. Local-only forbids remote fallback. Bulk getters return empty maps when unavailable and never emit per-flag exposure events.
- A value read returns its bool/string or the supplied fallback (null by default). An enabled read returns true for true/nonempty variants, false for false/empty variants, and its fallback for an unavailable flag (false by default). A present value wins over the fallback.
- `fresh=true` is a remote-readiness gate, not a force-fetch operation: use only values loaded from a remote flags response since setup/reset, not bootstrap, persisted startup values, or local-only evaluations. With no qualifying result, return the getter's fallback (null for a result lookup) immediately, without starting/waiting for a request or emitting exposure. Once eligible, normal cache-expiry handling still applies: an expired entry returns fallback and schedules the SDK's ordinary background refresh, without waiting for it. Combining fresh with only_evaluate_locally returns fallback without remote I/O. `fresh=false` follows ordinary cached/local/remote behavior.
- Payload reads return decoded JSON or the supplied fallback. They are silent by default; explicit tracking requests use the SDK tracker.
  - `match_value` selects the boolean/variant entry in a locally available definition's payload map, without recomputing the flag value merely to choose that entry. Thus a supplied `red` selects the local red payload even if ordinary evaluation would choose blue; it does not replace the cached evaluated value. Omitted match_value uses normal evaluation. A known local value with no payload returns fallback, without remote evaluation merely to seek a payload.
  - If local definition/evaluation is unavailable, a stateful getter reads its cached paired payload; a request-scoped getter with remote fallback enabled evaluates remotely and uses that response's paired payload. only_evaluate_locally prevents that remote evaluation. match_value is a local selector, not an instruction to force remote assignment to that variant. Cached/remote paired payloads retain their evaluated value.
  - A null/unavailable payload uses default_value (null by default); false, zero, empty strings/maps/lists remain payload values. When explicitly enabled, tracking reports the selected local value or the remote/cached evaluated value through normal deduplication. The adapter does not pre-read the flag.
- Atomic result reads return the shared FlagResult or null, without extra getter calls.
- Evaluate flags returns a retained snapshot; creation is silent. Omitted/null keys evaluate all; [] immediately returns an empty snapshot without cache/local/remote evaluation. Nonempty keys scope the entire evaluation path.
- Snapshot value/enablement reads mark access and use normal exposure deduplication. Payload reads never mark access, evaluate, or emit exposure. keys, only, only_accessed, accessed, and event_properties are in-memory operations without network/exposure.
- only_accessed before any value/enablement read returns empty; payload-only reads do not change that. Explicit filtering intersects present keys. Filtered bookkeeping does not mutate its parent's access set. Capture uses a supplied snapshot without reevaluation; it takes precedence over deprecated capture-time flag evaluation.
- Flag notifications are **readiness signals with no arguments**. Setup on_feature_flags observes successful loads. Runtime on_feature_flags registration notifies immediately if values are already available and then on each successful load; it returns a subscription with idempotent removal. Observing values requires an explicit separate SDK read in the scenario. Reload callbacks are also no-argument completion signals, including failed/skipped attempts; no invented data result is attached.

### Other products and callbacks

- Unified flush includes all applicable event/replay/log/trace queues. Dedicated telemetry flush routes address only their own queue. Ended spans, not live spans, are eligible for export. On a host with configured keep-alive, ending a span registers its drain with that host even if no analytics event was captured.
- Tracing-header injection is opt-in through tracing_headers and uses current identity/session at request time for exactly allowed destinations. A host fixture installs any required interceptor; it cannot inject the headers itself. Server parsing is separate from entering context.
- Survey getters notify their supplied callback with a survey list. Display performs real UI behavior; inline display requires a selector and has no initial response seeding. Popover responses use zero-based question indexes. Rendering conditions return SurveyRenderReason; the synchronous query returns null before survey data is available.
- Context calls modify SDK-owned execution-local state. with_context and with_span invoke a callback in that scope and return its value; fresh starts without inherited context. new_context returns a scope handle; entering/exiting that scope is a visible runtime-protocol action. No ambient context is stored in an RPC adapter.
- Callback signatures: loaded(instance); on_error(error); before_send(event) → event/null; log hook(log) → log/null; span hook(span data) → span data/null; on_feature_flag(value/null); on_session_id(session_id/null); on_surveys_loaded(surveys); on(event) receives the emitted event data; with_context() and with_span(span) run continuations. push_identity_provider(distinct_id, app_id) returns a string/null. anonymous_id_provider(generated_id) returns an ID. Hooks are ordered and their completion is awaited by their owning operation.

## 6. Survey and result data

```typescript
type EarlyAccessStage = "concept" | "alpha" | "beta" | "general-availability";
type SurveyPosition = "top_left" | "top_center" | "top_right" |
  "middle_left" | "middle_center" | "middle_right" |
  "left" | "center" | "right" | "next_to_trigger";
type SurveyResponse = string | string[] | number | null;
interface DisplaySurveyBase {
  ignore_conditions?: boolean;
  ignore_delay?: boolean;
  properties?: Properties;
}
type DisplaySurvey = DisplaySurveyBase & (
  { display_type?: "popover"; position?: SurveyPosition; selector?: string;
    initial_responses?: Record<integer, SurveyResponse>; skip_shown_event?: boolean } |
  { display_type: "inline"; selector: string }
);
interface Survey { id: string; name: string; questions: Properties[]; [field: string]: Json }
type BatchSummary = Ref<"batch_summary">;
interface SessionTransfer { __posthog?: { id: string; startTime: number } }
interface SurveyRenderReason { visible: boolean; disabled_reason?: string }
interface DeepLinkArgs { url: string; referrer?: string }
interface PushOpenedArgs {
  title?: string | null;
  subtitle?: string | null;
  body?: string | null;
  payload?: Properties | null;
  action?: string | null;
}
interface FlagOverrides { flags?: FlagValues | null; payloads?: Payloads | null }
```

Remote configuration/decision/detail data is JSON protocol data, not an SDK-selected opaque object. Its server-owned fields follow the pinned remote-config and flags wire schemas. Survey additional fields likewise carry service-owned survey data. BatchSummary retains the native immediate-batch result. Submitted counts events sent after filtering; not_persisted counts submitted events without an accepted server verdict. No summary accessor runs during serialization. SessionTransfer is empty without a session; startTime is Unix seconds and retains the continuation protocol's field name. Deep-link and push callbacks with host objects must supply their data through a real integration fixture; the ordinary RPCs have the records above.

## 7. Operations

`receiver` defaults to the selected SDK instance. A row naming another receiver operates on that retained object. `none` is an empty argument record. All defaults and effects above apply to these rows; no native subset is implicit. Immediate variants use the same ordinary event/profile argument record as their queued counterpart, with the explicit immediate completion boundary.

### Feature-driven operations (48)

| Route | Arguments | Result | Receiver / effect |
|---|---|---|---|
| `/setup` | `SetupArgs` | `void` | Initialize the selected instance; completion is local initialization, not remote flag readiness. |
| `/shutdown` | `timeout_ms?: DurationMs; cancellation?: Cancellation` | `void` | Bounded unified drain and terminal resource shutdown. |
| `/flush` | `timeout_ms?: DurationMs; callback?: Callback` | `void` | Bounded unified event/replay/log/trace flush; callback signals completion without arguments. |
| `/debug` | `enabled?: boolean` | `void` | Set SDK diagnostic logging; omitted enabled=true. |
| `/opt_in` | `OptInArgs` | `void` | Persist consent granted; optional explicit consent event. |
| `/opt_out` | `OptOutArgs` | `void` | Persist consent denied; optionally clear identity/super properties. |
| `/is_opt_out` | `none` | `boolean` | True when opted out or unavailable. |
| `/reset` | `ResetArgs` | `void` | Reset installation identity/context; apply an optional new bootstrap. |
| `/get_distinct_id` | `none` | `string` | Read the named identity; empty string if uninitialized. |
| `/get_anonymous_id` | `none` | `string` | Read the named identity; empty string if uninitialized. |
| `/get_session_id` | `none` | `string &#124; null` | Read current session ID without creating or rotating a session. |
| `/capture` | `EventArgs` | `void` | Validate/enrich/admit analytics; no delivery receipt. |
| `/capture_immediate` | `EventArgs` | `void` | Send analytics through the immediate path; complete after its send attempt. |
| `/capture_ai` | `EventArgs` | `string &#124; null` | Admit to the isolated AI lane; return event UUID or null. |
| `/capture_exception` | `ExceptionArgs` | `void` | Capture handled exception through the error pipeline. |
| `/add_exception_step` | `message: string; properties?: Properties` | `void` | Record a call-time, byte-bounded exception step. |
| `/screen` | `name: string; properties?: Properties; distinct_id?: Identity; timestamp?: Timestamp; uuid?: string; disable_geoip?: boolean` | `void` | Capture a screen view and update current screen context. |
| `/identify` | `IdentifyArgs` | `void` | Stateful identify transition or request-scoped profile update. |
| `/alias` | `AliasArgs` | `void` | Link source distinct_id to target alias without changing identity. |
| `/set_person_properties` | `PersonArgs` | `void` | Update set/set_once person maps without replacing identity. |
| `/create_person_profile` | `none` | `void` | Enable person processing for current client identity. |
| `/group` | `GroupArgs` | `void` | Set membership and optionally update the group profile. |
| `/group_identify` | `GroupArgs` | `void` | Update a group profile under $group_set without changing membership. |
| `/register` | `RegisterArgs` | `void` | Persist exactly one super-property key/value. |
| `/unregister` | `key: string` | `void` | Remove one super-property; absent key is a no-op. |
| `/get_feature_flag` | `ValueRead` | `Json` | Read a bool/string value, or default_value (null by default). |
| `/is_feature_enabled` | `EnabledRead` | `boolean` | Read boolean enablement; default false only when unavailable. |
| `/get_feature_flag_payload` | `PayloadRead` | `Json` | Read decoded payload or default; silent unless tracking explicitly requested. |
| `/get_feature_flag_result` | `FlagRead` | `FlagResult &#124; null` | Read value, enabled state, and payload atomically. |
| `/get_feature_flags` | `Evaluation` | `FlagValues` | Silent bulk values; empty map when unavailable. |
| `/get_feature_flags_and_payloads` | `Evaluation` | `FlagsAndPayloads` | Silent paired values/payloads; empty maps when unavailable. |
| `/evaluate_flags` | `Evaluation` | `Snapshot` | Evaluate once and retain a silent snapshot. |
| `/snapshot/is_enabled` | `key: string; default_value?: boolean` | `boolean` | **snapshot** — Enabled read; default false, mark access, normal exposure dedupe. |
| `/snapshot/get_flag` | `key: string` | `FlagValue &#124; null` | **snapshot** — Value read; mark access, normal exposure dedupe. |
| `/snapshot/get_flag_payload` | `key: string` | `Json` | **snapshot** — Silent payload; no access bookkeeping or evaluation. |
| `/snapshot/keys` | `none` | `string[]` | **snapshot** — Return the unique present key set; order is not significant. |
| `/snapshot/only` | `keys: string[]` | `Snapshot` | **snapshot** — Intersect present keys; no evaluation/network/exposure. |
| `/snapshot/only_accessed` | `none` | `Snapshot` | **snapshot** — Project accessed present keys; empty before value/enablement reads. |
| `/reload_feature_flags` | `callback?: Callback; distinct_id?: Identity; send_anonymous_distinct_id?: boolean` | `void` | Refresh evaluations for current/explicit context; signal completion after attempt. |
| `/on_feature_flags` | `callback: Callback` | `Subscription` | Readiness-only notifications; immediate notification when already loaded. |
| `/subscription/unsubscribe` | `none` | `void` | **subscription** — Idempotently remove the actual listener. |
| `/set_person_properties_for_flags` | `properties: Properties; reload_feature_flags?: boolean` | `void` | Merge flag-only person overrides; reload by default. |
| `/reset_person_properties_for_flags` | `reload_feature_flags?: boolean` | `void` | Clear all person overrides; reload by default. |
| `/set_group_properties_for_flags` | `GroupFlagArgs` | `void` | Merge flag-only overrides for one type; membership is unchanged. |
| `/reset_group_properties_for_flags` | `group_type?: string &#124; null; reload_feature_flags?: boolean` | `void` | Clear one type or all when omitted/null; reload by default. |
| `/start_session_recording` | `ReplayStart` | `void` | Resume current recording by default; explicit eligibility overrides are independent. |
| `/stop_session_recording` | `none` | `void` | Stop recording; no flush is implied. |
| `/is_session_replay_active` | `none` | `boolean` | Read actual recording activity; false when unavailable. |

### Additional public operations (132)

| Route | Arguments | Result | Receiver / effect |
|---|---|---|---|
| `/capture_ai_immediate` | `EventArgs` | `string &#124; null` | Immediate isolated AI send; UUID on admission, null on rejection; send failures are observable. |
| `/identify_immediate` | `IdentifyArgs` | `void` | Immediate counterpart; one operation and one send-attempt completion boundary. |
| `/alias_immediate` | `AliasArgs` | `void` | Immediate counterpart; one operation and one send-attempt completion boundary. |
| `/group_identify_immediate` | `GroupArgs` | `void` | Immediate counterpart; one operation and one send-attempt completion boundary. |
| `/capture_exception_immediate` | `ExceptionArgs` | `void` | Immediate counterpart; one operation and one send-attempt completion boundary. |
| `/capture_batch` | `BatchArgs` | `void` | Admit a batch through one public batch operation. |
| `/capture_batch_immediate` | `BatchArgs` | `BatchSummary` | Immediate native batch operation; return its summary. |
| `/set_person_properties_once` | `distinct_id?: Identity; properties?: Properties; timestamp?: Timestamp; uuid?: string; disable_geoip?: boolean` | `void` | Set only previously unset person properties. |
| `/unset_person_properties` | `keys: string[]; distinct_id?: Identity; reload_feature_flags?: boolean` | `void` | Remove the named person properties in one operation; reload by default. |
| `/register_once` | `properties: Properties; default_value?: Json; days?: number &#124; null` | `void` | Bulk first-write registration; replace a value matching default_value, default "None". |
| `/register_for_session` | `properties: Properties` | `void` | Bulk merge super properties for the current session only. |
| `/unregister_for_session` | `key: string` | `void` | Remove a session super property. |
| `/get_property` | `key: string` | `Json` | Return persisted super property or null. |
| `/get_session_property` | `key: string` | `Json` | Return session super property or null. |
| `/set_groups` | `groups: Groups` | `void` | Merge supplied group memberships; new keys replace matching types; retain other types. |
| `/get_groups` | `none` | `Groups` | Return membership map; empty when unavailable. |
| `/reset_groups` | `none` | `void` | Clear all membership. |
| `/get_device_id` | `none` | `string` | Read stable device ID; empty before initialization. |
| `/reset_session_id` | `none` | `void` | End the current session; the next qualifying activity creates another. |
| `/start_session` | `none` | `void` | Start a session if none is active; otherwise retain it. |
| `/end_session` | `none` | `void` | End the current session without flushing. |
| `/is_session_active` | `none` | `boolean` | Read analytics session activity, independently of recording. |
| `/get_session_replay_url` | `with_timestamp?: boolean; timestamp_look_back?: number` | `string` | Return replay URL, or empty when no session; look-back is seconds. |
| `/set_config` | `config: SetConfig` | `void` | Patch live configuration without reinitializing. |
| `/is_initialized` | `none` | `boolean` | Read successful local initialization, not network readiness. |
| `/is_shutdown` | `none` | `boolean` | Read terminal shutdown state. |
| `/pending_events` | `none` | `integer` | Count analytics records pending in the SDK queue. |
| `/join` | `none` | `void` | Wait for queued analytics work to finish; do not shut down or enqueue a send. |
| `/enable` | `none` | `void` | Clear SDK disabled state without changing consent. |
| `/disable` | `none` | `void` | Set SDK disabled state without changing consent. |
| `/has_opted_in` | `none` | `boolean` | Read explicit granted consent; false for pending/denied. |
| `/get_explicit_consent_status` | `none` | `"granted" &#124; "denied" &#124; "pending"` | Read the explicit consent choice, independently of configured defaults. |
| `/is_capturing` | `none` | `boolean` | Read effective capture eligibility, including lifecycle/consent/disabled gates. |
| `/clear_consent` | `none` | `void` | Remove explicit consent and restore the configured default. |
| `/set_identity` | `distinct_id: string; hash: string` | `void` | Set authenticated identity verification data; not identify. |
| `/clear_identity` | `none` | `void` | Clear identity verification data without resetting identity. |
| `/set_internal_or_test_user` | `none` | `void` | Mark the current person as an internal/test user. |
| `/disable_global` | `none` | `void` | Permanently prohibit future global initialization; existing clients are unchanged. |
| `/global_is_disabled` | `none` | `boolean` | Read the global initialization gate. |
| `/capture_raw` | `message: Properties` | `void` | Submit explicitly prepared raw event data, not a replacement for named identity operations. |
| `/get_all_feature_flag_results` | `Evaluation` | `FlagResult[]` | Silent collection of structured flag results; empty when unavailable. |
| `/get_feature_flag_payloads` | `Evaluation` | `Payloads` | Silent bulk decoded payload map. |
| `/get_feature_flag_details` | `none` | `Properties` | Read cached flag metadata; empty when unavailable. |
| `/get_flags_decision` | `Evaluation` | `Properties &#124; null` | Return the full flags protocol response or null on failure. |
| `/get_remote_config_payload` | `key: string; cancellation?: Cancellation` | `Json` | Fetch secret remote-config payload; not an evaluated flag payload. |
| `/get_remote_config` | `none` | `Properties &#124; null` | Read cached project remote configuration. |
| `/reload_remote_config` | `none` | `Properties &#124; null` | Attempt remote configuration refresh and return the resulting response. |
| `/update_flags` | `flags: FlagValues; payloads?: Payloads; merge?: boolean` | `void` | Replace cached flags/payloads by default; merge only when true; notify listeners. |
| `/override_feature_flags` | `overrides: FlagOverrides &#124; null` | `void` | Set local flag/payload overrides; null clears all; omitted submaps stay unchanged. |
| `/clear_local_flags_cache` | `none` | `void` | Clear the local flag-definition cache. |
| `/is_local_evaluation_ready` | `none` | `boolean` | Read whether local definitions are available. |
| `/wait_for_local_evaluation_ready` | `timeout_ms?: DurationMs` | `boolean` | Wait for definitions; default 30000ms; false on timeout. |
| `/evaluate_feature_flag_locally` | `flag: Ref<"definition">; distinct_id: string; person_properties: Properties; groups: Groups; group_properties: GroupProperties` | `FlagValue &#124; null` | Evaluate a supplied definition locally without remote fallback. |
| `/snapshot/accessed` | `none` | `string[]` | **snapshot** — Return accessed key set; order is not significant. |
| `/snapshot/event_properties` | `none` | `Properties` | **snapshot** — Return capture enrichment from this snapshot without evaluating or tracking. |
| `/flag_result/value` | `none` | `FlagValue &#124; null` | **flag_result** — Read the retained result value without evaluation. |
| `/flag_result/get_variant` | `default_value?: string &#124; null` | `string &#124; null` | **flag_result** — Return variant or default (null); no evaluation. |
| `/flag_result/get_payload` | `type: Type; default_value?: Json` | `Json` | **flag_result** — Decode/cast retained payload to the declared fixture type; default null on failure. |
| `/on` | `event: string; callback: Callback` | `Subscription` | Subscribe to future named SDK notifications; callback receives emitted data. |
| `/on_feature_flag` | `key: string; callback: Callback` | `Subscription` | Subscribe to future values of one flag; callback gets value/null. |
| `/on_session_id` | `callback: Callback` | `Subscription` | Notify with current session ID, then subsequent changes. |
| `/on_surveys_loaded` | `callback: Callback` | `Subscription` | Subscribe to successful survey loads; callback receives survey list. |
| `/get_surveys` | `callback: Callback; force_reload?: boolean` | `void` | Deliver surveys through callback; use cache unless force_reload=true. |
| `/get_active_matching_surveys` | `callback: Callback; force_reload?: boolean` | `void` | Deliver currently matching surveys through callback. |
| `/render_survey` | `survey_id: string; selector: string` | `void` | Render a real inline survey in the selected host element. |
| `/display_survey` | `survey_id: string; options?: DisplaySurvey` | `void` | Display a real survey, popover by default. |
| `/cancel_pending_survey` | `survey_id: string` | `void` | Cancel pending display; already-displayed UI is unchanged. |
| `/can_render_survey` | `survey_id: string` | `SurveyRenderReason &#124; null` | Check cached render eligibility; null until survey data is available. |
| `/can_render_survey_async` | `survey_id: string; force_reload?: boolean` | `SurveyRenderReason` | Check render eligibility, optionally refreshing first within the SDK. |
| `/get_early_access_features` | `callback: Callback; force_reload?: boolean; stages?: EarlyAccessStage[]` | `void` | Deliver early-access feature list; omitted stages means all stages. |
| `/update_early_access_feature_enrollment` | `key: string; is_enrolled: boolean; stage?: EarlyAccessStage` | `void` | Update enrollment and its SDK-owned analytics/flag state. |
| `/capture_feature_view` | `flag: string; variant?: string &#124; null` | `void` | Capture feature usage; omitted/null variant uses the cached flag value inside this call. |
| `/capture_feature_interaction` | `flag: string; variant?: string &#124; null` | `void` | Capture feature usage; omitted/null variant uses the cached flag value inside this call. |
| `/start_exception_autocapture` | `config?: ExceptionAutoCaptureConfig` | `void` | Install automatic exception capture sources. |
| `/stop_exception_autocapture` | `none` | `void` | Remove automatic exception capture sources. |
| `/capture_run_zoned_guarded_error` | `error: ExceptionInput; stack?: Stack; properties?: Properties` | `void` | Capture an unhandled guarded-zone failure, distinct from manual handled capture. |
| `/is_autocapture_active` | `none` | `boolean` | Read autocapture activity. |
| `/is_rage_click_active` | `none` | `boolean` | Read rage-click instrumentation activity. |
| `/with_context` | `context: ContextData; callback: Callback; fresh?: boolean` | `Json` | Run an explicit continuation in request context; return its result. |
| `/enter_context` | `context: ContextData; fresh?: boolean` | `void` | Enter SDK execution-local context for the current continuation. |
| `/get_context` | `none` | `ContextData &#124; null` | Read active SDK request-context data, not installation identity. |
| `/new_context` | `fresh?: boolean; capture_exceptions?: boolean` | `Context` | Create a context scope handle; entry/exit are explicit fixture protocol actions. |
| `/identify_context` | `distinct_id: string` | `void` | Set request-context identity without a person event. |
| `/set_context_session` | `session_id: string` | `void` | Set request-context session ID. |
| `/set_context_device_id` | `device_id: string` | `void` | Set request-context device ID. |
| `/tag` | `name: string; value: Json` | `void` | Set one request-context tag. |
| `/get_tags` | `none` | `Properties` | Return current request-context tags. |
| `/context_from_headers` | `headers: Record<string, HeaderValue>` | `ContextData` | Parse case-insensitive correlation headers without entering context. |
| `/set_context` | `context: ContextData` | `void` | Merge SDK execution-local context data. |
| `/set_event_context` | `event: string; context: Properties` | `void` | Merge event-name-scoped context properties. |
| `/get_event_context` | `event: string` | `Properties` | Return context properties for the named event. |
| `/set_flags_in_context` | `flags: Snapshot` | `void` | Attach a retained snapshot to the active request context. |
| `/bare_capture` | `event: string; distinct_id: Identity; properties?: Properties` | `void` | Capture without request-context property enrichment. |
| `/get_logger` | `none` | `Ref<"logger">` | Obtain the retained product logger facade, without initializing the SDK. Its capture methods safely no-op when the SDK is unavailable. |
| `/get_metrics` | `none` | `Ref<"metrics">` | Obtain the retained metrics facade, without initializing the SDK. Its capture methods safely no-op when the SDK is unavailable. |
| `/capture_log` | `LogArgs` | `void` | Admit a structured log; level defaults to info. |
| `/logger/trace` | `body: string; attributes?: Properties` | `void` | **logger** — Capture a structured log at trace severity. |
| `/logger/debug` | `body: string; attributes?: Properties` | `void` | **logger** — Capture a structured log at debug severity. |
| `/logger/info` | `body: string; attributes?: Properties` | `void` | **logger** — Capture a structured log at info severity. |
| `/logger/warn` | `body: string; attributes?: Properties` | `void` | **logger** — Capture a structured log at warn severity. |
| `/logger/error` | `body: string; attributes?: Properties` | `void` | **logger** — Capture a structured log at error severity. |
| `/logger/fatal` | `body: string; attributes?: Properties` | `void` | **logger** — Capture a structured log at fatal severity. |
| `/flush_logs` | `none` | `void` | Flush only the logs queue. |
| `/metrics/count` | `name: string; value?: number; unit?: string; attributes?: MetricAttributes` | `void` | **metrics** — Accumulate count; default increment 1. |
| `/metrics/gauge` | `MetricArgs` | `void` | **metrics** — Record a gauge measurement. |
| `/metrics/histogram` | `MetricArgs` | `void` | **metrics** — Record a histogram measurement. |
| `/metrics/flush` | `transport?: Transport` | `void` | **metrics** — Flush metric aggregates only. |
| `/start_span` | `name: string; options?: StartSpan` | `Span` | Start a retained span; inherited parent by default. |
| `/with_span` | `name: string; options?: StartSpan; callback: Callback` | `Json` | Run continuation with an active span; end it inside the SDK when continuation completes. |
| `/get_active_span` | `none` | `Span &#124; null` | Read active span without creating one. |
| `/span/set_attribute` | `key: string; value: SpanValue` | `Span` | **span** — Set one attribute. Return the same handle. |
| `/span/set_attributes` | `attributes: Record<string, SpanValue>` | `Span` | **span** — Bulk set attributes. Return the same handle. |
| `/span/add_event` | `name: string; attributes?: Record<string, SpanValue>; timestamp?: Timestamp` | `Span` | **span** — Append one timestamped span event. Return the same handle. |
| `/span/set_status` | `status: "ok" &#124; "error"; message?: string` | `Span` | **span** — Set status; omitted message has no text. Return the same handle. |
| `/span/record_exception` | `error: ExceptionInput` | `Span` | **span** — Record an exception on the span, not as a separate analytics event. Return the same handle. |
| `/span/update_name` | `name: string` | `Span` | **span** — Replace span name. Return the same handle. |
| `/span/traceparent` | `none` | `string &#124; null` | **span** — Read traceparent propagation data; null when unavailable. |
| `/span/tracestate` | `none` | `string &#124; null` | **span** — Read tracestate propagation data; null when unavailable. |
| `/span/end` | `end_time?: Timestamp` | `void` | **span** — Idempotently end/enqueue the span; register host keep-alive if configured. |
| `/capture_trace_feedback` | `trace_id: string; feedback: string` | `void` | Capture analytics trace feedback, not an OTLP span. |
| `/capture_trace_metric` | `trace_id: string; name: string; value: string &#124; number &#124; boolean` | `void` | Capture analytics trace metric, not an OTLP metric. |
| `/register_push_notification_token` | `device_token: string; app_id?: string` | `void` | Register token for current identity/provider; preserve SDK retry intent. |
| `/unregister_push_notification_token` | `none` | `void` | Remove token registration; distinct from user reset. |
| `/capture_push_notification_opened` | `PushOpenedArgs` | `void` | Capture one explicit notification-open event. |
| `/prewarm_push_notification_open_capture` | `none` | `void` | Install pre-setup push-open capture; retain the initial open until setup. |
| `/capture_deep_link` | `DeepLinkArgs` | `void` | Capture one app deep link; not a fixture navigation action. |
| `/record_network_request` | `method: string; url: string; status_code: integer; duration_ms: integer; response_size?: integer` | `void` | Record completed-request replay telemetry; do not make a network request. |
| `/get_session_teleport_data` | `subject: Ref<"subject">` | `SessionTransfer` | Return portable session-continuation data for the supplied subject. |
| `/batch_summary/submitted` | `none` | `integer` | **batch_summary** — Return number of events submitted after hook filtering. |
| `/batch_summary/not_persisted` | `none` | `integer` | **batch_summary** — Return submitted count without accepted server verdicts, including missing verdicts. |
| `/batch_summary/all_persisted` | `none` | `boolean` | **batch_summary** — True when not_persisted is zero, including an empty submitted batch. |
| `/batch_summary/event_results` | `none` | `Record<string, Properties>` | **batch_summary** — Return per-event analytics-v1 verdicts; empty for legacy analytics. |

## 8. Requirement and fixture index

This is a discovery index, not a claim that every scenario already executes through these requests. The selected changes to cardinality, callback data and results require the explicit spec/feature alignment listed in [the decisions](public-rpc-decisions.md). Internal algorithms remain SDK behavior; fixture stimuli and native component tests are not extra public SDK operations.

The source baseline has 40 public and 20 private feature files, with 395 scenario/outline declarations. It also has 62 OpenSpec capabilities. Logs and traces have canonical prose requirements but no Gherkin files at the pinned revision. Source and type counts alone do not prove semantic coverage.

### Public features

| Capability | Operations | Pinned requirement |
|---|---|---|
| alias | `/alias` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/alias/spec.md) |
| bootstrap | `/setup`, `/reset`, `/get_feature_flag`, `/get_feature_flag_payload`, `/get_anonymous_id`, `/get_distinct_id`, `/get_session_id`, `/on_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/bootstrap/spec.md) |
| capture | `/capture`, `/capture_immediate`, `/flush`, `/opt_out` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/capture/spec.md) |
| capture-ai | `/capture_ai`, `/capture`, `/flush` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/capture-ai/spec.md) |
| capture-exception | `/capture_exception`, `/flush` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/capture-exception/spec.md) |
| create-person-profile | `/create_person_profile` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/create-person-profile/spec.md) |
| debug | `/debug` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/debug/spec.md) |
| evaluate-flags | `/evaluate_flags`, `/snapshot/is_enabled`, `/snapshot/get_flag`, `/snapshot/get_flag_payload`, `/snapshot/keys`, `/snapshot/only`, `/snapshot/only_accessed`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/evaluate-flags/spec.md) |
| exception-steps | `/add_exception_step`, `/capture_exception`, `/reset` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/exception-steps/spec.md) |
| flush | `/flush` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/flush/spec.md) |
| get-anonymous-id | `/get_anonymous_id`, `/identify`, `/get_distinct_id`, `/reset` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-anonymous-id/spec.md) |
| get-distinct-id | `/get_distinct_id`, `/identify` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-distinct-id/spec.md) |
| get-feature-flag | `/get_feature_flag` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-feature-flag/spec.md) |
| get-feature-flag-payload | `/get_feature_flag_payload` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-feature-flag-payload/spec.md) |
| get-feature-flag-result | `/get_feature_flag_result` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-feature-flag-result/spec.md) |
| get-feature-flags | `/get_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-feature-flags/spec.md) |
| get-feature-flags-and-payloads | `/get_feature_flags_and_payloads` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-feature-flags-and-payloads/spec.md) |
| get-session-id | `/get_session_id`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/get-session-id/spec.md) |
| group | `/group`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/group/spec.md) |
| group-identify | `/group_identify` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/group-identify/spec.md) |
| identify | `/identify`, `/get_distinct_id` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/identify/spec.md) |
| is-feature-enabled | `/is_feature_enabled` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/is-feature-enabled/spec.md) |
| is-opt-out | `/is_opt_out`, `/opt_out` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/is-opt-out/spec.md) |
| is-session-replay-active | `/is_session_replay_active`, `/start_session_recording`, `/stop_session_recording` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/is-session-replay-active/spec.md) |
| on-feature-flags | `/on_feature_flags`, `/subscription/unsubscribe` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/on-feature-flags/spec.md) |
| opt-in | `/opt_in`, `/opt_out`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/opt-in/spec.md) |
| register | `/register`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/register/spec.md) |
| reload-feature-flags | `/reload_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/reload-feature-flags/spec.md) |
| reset | `/reset`, `/get_distinct_id`, `/get_anonymous_id`, `/get_session_id` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/reset/spec.md) |
| reset-group-properties-for-flags | `/reset_group_properties_for_flags`, `/reload_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/reset-group-properties-for-flags/spec.md) |
| reset-person-properties-for-flags | `/reset_person_properties_for_flags`, `/reload_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/reset-person-properties-for-flags/spec.md) |
| screen | `/screen` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/screen/spec.md) |
| set-group-properties-for-flags | `/set_group_properties_for_flags`, `/reload_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/set-group-properties-for-flags/spec.md) |
| set-person-properties | `/set_person_properties` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/set-person-properties/spec.md) |
| set-person-properties-for-flags | `/set_person_properties_for_flags`, `/reload_feature_flags` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/set-person-properties-for-flags/spec.md) |
| setup | `/setup`, `/get_distinct_id` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/setup/spec.md) |
| shutdown | `/shutdown`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/shutdown/spec.md) |
| start-session-recording | `/start_session_recording`, `/is_session_replay_active` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/start-session-recording/spec.md) |
| stop-session-recording | `/stop_session_recording`, `/is_session_replay_active` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/stop-session-recording/spec.md) |
| unregister | `/unregister`, `/capture` | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/unregister/spec.md) |

### Private features

| Capability | Public boundary and fixture stimuli | Pinned requirement |
|---|---|---|
| application-lifecycle | setup; runtime lifecycle stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/application-lifecycle/spec.md) |
| autocapture | setup; UI interaction stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/autocapture/spec.md) |
| before-send-hook | setup/set_config with callback reference; capture; callback/queue observations | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/before-send-hook/spec.md) |
| consent-gating | setup, opt_in, opt_out, capture | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/consent-gating/spec.md) |
| device-id-generator | setup, reset; storage/id observations | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/device-id-generator/spec.md) |
| event-batcher | setup, capture; scheduler stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/event-batcher/spec.md) |
| exception-event-metadata | capture_exception; runtime error fixtures and integration/crash stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/exception-event-metadata/spec.md) |
| feature-flag-cache | setup, reload_feature_flags, get_feature_flag, reset; response fixtures | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/feature-flag-cache/spec.md) |
| feature-flag-called-tracker | get_feature_flag, reset, shutdown; response/clock fixtures | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/feature-flag-called-tracker/spec.md) |
| flag-definition-loader | setup, shutdown; definition responses, cache-provider callbacks and clock stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/flag-definition-loader/spec.md) |
| http-client | setup, capture, flush, reload_feature_flags/get_feature_flag; HTTP fixtures | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/http-client/spec.md) |
| local-feature-flag-evaluator | local-only flag reads/evaluate_flags; definition, context and clock fixtures; native component tests for internal operators | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/local-feature-flag-evaluator/spec.md) |
| persistent-storage | setup, register, capture, get_anonymous_id; restart and storage fault stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/persistent-storage/spec.md) |
| remote-config | get_remote_config/reload_remote_config; controlled config responses | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/remote-config/spec.md) |
| retry-queue | setup, capture, flush; scheduler/network/storage/queue-identity stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/retry-queue/spec.md) |
| session-manager | get_session_id, reset_session_id, start_session, end_session; activity and clock stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/session-manager/spec.md) |
| session-replay-ingestion-controls | setup, capture, start_session_recording, stop_session_recording, is_session_replay_active; remote config/UI/runtime stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/session-replay-ingestion-controls/spec.md) |
| session-replay-privacy | setup, start_session_recording; UI/privacy stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/session-replay-privacy/spec.md) |
| surveys | get_surveys/get_active_matching_surveys/display_survey; real presentation, dismissal and response stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/surveys/spec.md) |
| tracing-headers | setup, capture, evaluate_flags; request-context and outgoing-request integration stimuli | [spec](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/tracing-headers/spec.md) |

### Product pipelines and integrations

- [Logs](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/logs/spec.md): capture_log/logger, unified and dedicated flush, resource configuration, before-send hooks, durable queue and lifecycle fixtures.
- [Traces](https://github.com/PostHog/sdk-specs/blob/4f2f48f48e2e6dfafb8383fb679af4e69ffdceb0/openspec/specs/traces/spec.md): explicit span methods, limits, before-span-send hooks, unified flush, propagation and keep-alive host fixtures.
- Framework providers/hooks, view masks, navigation observers, logging exporters, AI wrappers, context managers, extension hosts, and the separate LLM context-stack family remain indexed in [the source inventory](public-rpc-source-inventory.md). They require explicit integration/fixture contracts, not a generic private-method RPC. Their ordinary SDK calls use the operations above; mounting a component or receiving a host event is not a renamed capture call.
- Runtime fixtures must use the same declared callback signatures, reference lifetimes, storage/restart semantics, and host stimuli for every binding. Cache-provider fixtures expose shared read/write/refresh decisions and failure/timing observations; the adapter must not substitute its own feature-flag cache. Negative-value fixtures record when a language cannot express the requested native input rather than claiming a passing SDK test.

## 9. Validation and next boundary

The documentary gate is: every route has one declared request/result shape; every referenced type resolves; bootstrap examples type-check; the original 174 routes are retained; the four batch-summary methods and two facade getters are explicit; all 60 feature names are indexed; and the source inventory retains its pinned references.

The baseline is ready to use for a binding/gap assessment. It does not assert current SDK support. That assessment must test actual public-entry behavior against these choices, including omitted/default/null cases, invalid input, lifecycle completion, callbacks, and public returned-object methods. A mismatch may require an SDK API/default migration; the adapter cannot repair it. Canonical OpenSpec/acceptance alignment and SDK implementation remain separate work.
