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
