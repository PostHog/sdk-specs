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
