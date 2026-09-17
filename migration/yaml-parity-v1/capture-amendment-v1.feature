@public @acceptance @both @capture
Feature: Approved capture-amendment-v1 YAML cases
  Explicit encoding selection and typed capture controls retain original wire assertions.

  Background:
    Given an isolated SDK with empty persistent storage
    And the mock PostHog server is reset

  # Source: yaml:029a94a:capture_v1:compression:sends_gzip_content_encoding
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:sends_gzip_content_encoding @requires:capture_v1 @requires:encoding_gzip
  Scenario: sends_gzip_content_encoding
    Given the SDK is initialized with token "phc_test_key" and compression "gzip" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "gzip"

  # Source: yaml:029a94a:capture_v1:compression:sends_deflate_content_encoding
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:sends_deflate_content_encoding @requires:capture_v1 @requires:encoding_deflate
  Scenario: sends_deflate_content_encoding
    Given the SDK is initialized with token "phc_test_key" and compression "deflate" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "deflate"

  # Source: yaml:029a94a:capture_v1:compression:sends_br_content_encoding
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:sends_br_content_encoding @requires:capture_v1 @requires:encoding_br
  Scenario: sends_br_content_encoding
    Given the SDK is initialized with token "phc_test_key" and compression "br" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "br"

  # Source: yaml:029a94a:capture_v1:compression:sends_zstd_content_encoding
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:sends_zstd_content_encoding @requires:capture_v1 @requires:encoding_zstd
  Scenario: sends_zstd_content_encoding
    Given the SDK is initialized with token "phc_test_key" and compression "zstd" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "zstd"

  # Source: yaml:029a94a:capture_v1:compression:compressed_body_is_decompressible
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:compressed_body_is_decompressible @requires:capture_v1 @requires:encoding_gzip
  Scenario: compressed_body_is_decompressible
    Given the SDK is initialized with token "phc_test_key" and compression "gzip" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first encoded request should decompress to parseable events

  # Source: yaml:029a94a:capture_v1:event_options:cookieless_mode_override
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:cookieless_mode_override @requires:capture_v1
  Scenario: cookieless_mode_override
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"cookieless_mode":true}}
      """
    And pending captures are flushed
    Then the first received event option "cookieless_mode" should equal JSON true

  # Source: yaml:029a94a:capture_v1:event_options:disable_skew_correction_override
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:disable_skew_correction_override @requires:capture_v1
  Scenario: disable_skew_correction_override
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"disable_skew_correction":true}}
      """
    And pending captures are flushed
    Then the first received event option "disable_skew_correction" should equal JSON true

  # Source: yaml:029a94a:capture_v1:event_options:process_person_profile_override
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:process_person_profile_override @requires:capture_v1
  Scenario: process_person_profile_override
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"process_person_profile":false}}
      """
    And pending captures are flushed
    Then the first received event option "process_person_profile" should equal JSON false

  # Source: yaml:029a94a:capture_v1:event_options:product_tour_id_override
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:product_tour_id_override @requires:capture_v1
  Scenario: product_tour_id_override
    Given the SDK is initialized with token "phc_test_key" and flush threshold 1
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event","options":{"product_tour_id":"tour_123"}}
      """
    And pending captures are flushed
    Then the first received event option "product_tour_id" should equal JSON "tour_123"

  # Source: yaml:029a94a:capture_v1:event_options:options_override_in_batch
  @api_capture_v1
  @case:migration:yaml-parity-v1:capture_analytics_v1:options_override_in_batch @requires:capture_v1
  Scenario: options_override_in_batch
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
  @case:migration:yaml-parity-v1:capture_analytics_v1:geoip_disable_injected_into_properties @requires:capture_v1
  Scenario: geoip_disable_injected_into_properties
    Given the SDK is initialized with token "phc_test_key", flush threshold 1, and GeoIP disabled
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then the first received event property "$geoip_disable" should equal JSON true

  # Source: yaml:029a94a:capture:compression:sends_gzip_when_enabled
  @api_capture_v0
  @case:migration:yaml-parity-v1:capture:sends_gzip_when_enabled @requires:capture_v0 @requires:encoding_gzip
  Scenario: sends_gzip_when_enabled
    Given the SDK is initialized with token "phc_test_key" and compression "gzip"
    When capture is called with JSON arguments:
      """application/json
      {"distinct_id":"test_user","event":"test_event"}
      """
    And pending captures are flushed
    Then a received request header "Content-Encoding" should equal "gzip"
