@public @acceptance @capture
Feature: Capture compression, event options, and GeoIP
  Explicit encoding selection and typed capture controls retain their wire assertions.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  # Source: yaml:029a94a:capture_v1:compression:sends_gzip_content_encoding
  @api_capture_v1
  @requires:capture_v1 @requires:encoding_gzip
  Scenario: Gzip capture sets the Content-Encoding header
    Given the SDK is initialized with token "phc_test_key" and compression "gzip" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "gzip"

  # Source: yaml:029a94a:capture_v1:compression:sends_deflate_content_encoding
  @api_capture_v1
  @requires:capture_v1 @requires:encoding_deflate
  Scenario: Deflate capture sets the Content-Encoding header
    Given the SDK is initialized with token "phc_test_key" and compression "deflate" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "deflate"

  # Source: yaml:029a94a:capture_v1:compression:sends_br_content_encoding
  @api_capture_v1
  @requires:capture_v1 @requires:encoding_br
  Scenario: Brotli capture sets the Content-Encoding header
    Given the SDK is initialized with token "phc_test_key" and compression "br" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "br"

  # Source: yaml:029a94a:capture_v1:compression:sends_zstd_content_encoding
  @api_capture_v1
  @requires:capture_v1 @requires:encoding_zstd
  Scenario: Zstandard capture sets the Content-Encoding header
    Given the SDK is initialized with token "phc_test_key" and compression "zstd" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "zstd"

  # Source: yaml:029a94a:capture_v1:compression:compressed_body_is_decompressible
  @api_capture_v1
  @requires:capture_v1 @requires:encoding_gzip
  Scenario: Compressed capture bodies contain parseable events
    Given the SDK is initialized with token "phc_test_key" and compression "gzip" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first encoded request should decompress to parseable events

  # Source: yaml:029a94a:capture_v1:event_options:cookieless_mode_override
  @api_capture_v1
  @requires:capture_v1
  Scenario: Capture preserves an explicit cookieless mode option
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"cookieless_mode":true}}
      """
    And pending captures are flushed
    Then the first received event option "cookieless_mode" should equal JSON true

  # Source: yaml:029a94a:capture_v1:event_options:disable_skew_correction_override
  @api_capture_v1
  @requires:capture_v1
  Scenario: Capture preserves an explicit skew correction option
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"disable_skew_correction":true}}
      """
    And pending captures are flushed
    Then the first received event option "disable_skew_correction" should equal JSON true

  # Source: yaml:029a94a:capture_v1:event_options:process_person_profile_override
  @api_capture_v1
  @requires:capture_v1
  Scenario: Capture preserves an explicit person profile option
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"process_person_profile":false}}
      """
    And pending captures are flushed
    Then the first received event option "process_person_profile" should equal JSON false

  # Source: yaml:029a94a:capture_v1:event_options:product_tour_id_override
  @api_capture_v1
  @requires:capture_v1
  Scenario: Capture preserves an explicit product tour ID
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"product_tour_id":"tour_123"}}
      """
    And pending captures are flushed
    Then the first received event option "product_tour_id" should equal JSON "tour_123"

  # Source: yaml:029a94a:capture_v1:event_options:options_override_in_batch
  @api_capture_v1
  @requires:capture_v1
  Scenario: Batched captures retain their per-event options
    Given the SDK is initialized with token "phc_test_key" and flush threshold 3
    When capture is called sequentially 3 times with zero-based top-level index substitution:
      """application/json
      {"distinct_id":"test_user_{index}","event":"test_event_{index}","options":{"cookieless_mode":true}}
      """
    And pending captures are flushed
    Then exactly 1 capture request should have been received
    Then the first request should contain exactly 3 parsed events
    Then the first received event option "cookieless_mode" should equal JSON true

  # Source: yaml:029a94a:capture_v1:geoip_and_historical_migration:geoip_disable_injected_into_properties
  @api_capture_v1
  @requires:capture_v1
  Scenario: Disabling GeoIP adds the event property
    Given the SDK is initialized with token "phc_test_key", flush threshold 1, and GeoIP disabled
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event property "$geoip_disable" should equal JSON true

  # Source: yaml:029a94a:capture:compression:sends_gzip_when_enabled
  @api_capture_v0
  @requires:capture_v0 @requires:encoding_gzip
  Scenario: Legacy capture sends gzip when enabled
    Given the SDK is initialized with token "phc_test_key" and compression "gzip"
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "gzip"
