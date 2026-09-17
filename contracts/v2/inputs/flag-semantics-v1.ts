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
