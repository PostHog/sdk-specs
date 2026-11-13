## 1. Verification

- [x] 1.1 Read the posthog-node method, its request helper and its tests, and map each requirement to a `file:line` and a covering test (`design.md`, "Reference mapping")
- [x] 1.2 Read the same method in posthog-python, posthog-ruby, posthog-go and posthog-dotnet
- [x] 1.3 List where the five SDKs differ and which points the evidence does not decide (`design.md`, "Open decisions" and "Existing SDK conformance")
- [x] 1.4 Make flag key encoding and failure status recommendations (`design.md`, "Decided")
- [ ] 1.5 Decide OD1 to OD5 in `design.md` in a later change, or leave them undefined

## 2. Spec delta

- [x] 2.1 Write the `get-remote-config-payload` delta
- [x] 2.2 Add the flag key encoding and failure status recommendations to the delta, with scenarios
- [ ] 2.3 Add the text of each open decision that a later change decides to the delta, with a scenario
- [ ] 2.4 Review the delta: every requirement has at least one scenario, scenarios use WHEN/THEN, and a wrong implementation fails each scenario

## 3. Acceptance feature

- [x] 3.1 Add `acceptance/public/get-remote-config-payload.feature` with server scenarios for the request, authentication, a disabled client, a missing secret key, decoding, failure, no caching, no events and local evaluation off
- [ ] 3.2 Leave `@sdk:server` off until a harness binding exists and a real SDK adapter has run the scenarios end to end

## 4. Archive

- [x] 4.1 Run `openspec validate --specs --strict`
- [x] 4.2 Archive the change, add the Purpose, Applicability and Public surface sections to `openspec/specs/get-remote-config-payload/spec.md` (text in `design.md`, "Archive-time text"), add the capability to the `README.md` table (`public API (server)`, before "Get Session ID") and add it to the public API list in `openspec/project.md`
- [x] 4.3 Leave `openspec/specs/remote-config/spec.md`, `acceptance/private/remote-config.feature` and the `compliance/` files unchanged. The compliance rows that call the per-flag method unrelated to `remote-config` stay true. The weekly audit adds the new capability to each SDK file.

## 5. Downstream follow-up (SDK repositories, separate changes, not this one)

Tracker: https://github.com/PostHog/posthog-android/issues/577. The repositories ask contributors to agree a new public method before they implement it. A published spec counts as that agreement (`CONTRIBUTING.md`, "Public API changes", in posthog-android and posthog-elixir). Start after this change merges. OD1 to OD5 can stay undefined.

- [ ] 5.1 posthog-android, module `posthog-server`: add the request to `posthog/src/main/java/com/posthog/internal/PostHogApi.kt` next to `localEvaluation`, add the method to `PostHogInterface.kt` and `PostHog.kt` in `posthog-server/src/main/java/com/posthog/server/`, regenerate `posthog-server/api/posthog-server.api` with `make api`, add tests with MockWebServer, add a changeset with `pnpm changeset`. Follow the spec for a missing secret key (`personalApiKey` is the existing option), flag key encoding, decoding, failure and failure status. Log and return `null` on failure, as the other flag methods do. Check that `posthog/api/posthog.api` does not change, or update it.
- [ ] 5.2 posthog-php: add `getRemoteConfigPayload` to `lib/Client.php` and the static facade in `lib/PostHog.php`, model the request on the Bearer request in `localFlags`, use the existing `$secretKey` with its `$personalAPIKey` fallback, log with `error_log` and return `null` on failure, update `api/public-api.json` and run `composer api:check`, add PHPUnit tests with `MockedHttpClient`, add a changeset with `pnpm change`.
- [ ] 5.3 posthog-elixir: add the request to `lib/posthog/api.ex` next to `flag_definitions/4`, add the function to the public module with `{:ok, value} | {:error, error}` and a bang variant, use the existing `secret_key` option, decide the host first (OD4), update `public_api.snapshot`, add Mox tests, add a changeset with `sampo add`, run `mix format --check-formatted`, `mix credo --strict` and `mix test`.
- [ ] 5.4 posthog-rs: add the method to the async client in `src/client/async_client.rs` and the blocking client in `src/client/blocking.rs`, return a `Result` with `Ok(None)` for a disabled client and an `Err` for a missing secret key, use the existing `secret_key` option, update `api/public-api.txt` with `scripts/check-public-api.sh`, add httpmock tests, add a changeset with `sampo add`. Read posthog-rs#350 and #359 first, because #359 adds a different `/config` request in the same area.
- [ ] 5.5 posthog.com, `contents/docs/feature-flags/remote-config.mdx`: add Java, PHP, Elixir and Rust tabs to the `<MultiLanguage>` block in "Step 3: Use remote config flags", which has Node, Python, Go, Ruby and C# today. Fix the Python and Go comments to match each SDK's return value. Land it after the SDK releases.
- [ ] 5.6 The five SDKs that already have the method: open one issue per gap listed in `design.md`, "Existing SDK conformance", and link it to PostHog/posthog-android#577. This change modifies none of these SDKs. The two recommendations add no gap. As an optional follow-up, a shipped SDK can adopt them (lines read at the SHAs in `design.md`, "Shipped SDKs and the two recommendations"):
  - [ ] 5.6.1 Optional. posthog-js, `packages/node/src/client.ts`: encode the flag key (`:3232`, key not encoded) and fail the call on a failure status (`:2187-2206`, no status check, a JSON error body is returned as the payload).
  - [ ] 5.6.2 Optional. posthog-python: encode the flag key on the sync path (`posthog/request.py:420`). The async path (`posthog/_async_request.py:184`) follows the recommendation. The failure status handling follows the recommendation too.
  - [ ] 5.6.3 Optional. posthog-ruby: encode the flag key (`lib/posthog/feature_flags.rb:1896`) and fail the call on a failure status (`:1952-1958`, returns a Hash with the body and `:status`).
  - [ ] 5.6.4 Optional. posthog-go: encode the flag key (`posthog.go:2004`, `url.JoinPath` with the raw key, a `/` splits the path). The failure status handling follows the recommendation (`posthog.go:2039-2041`).
  - [ ] 5.6.5 posthog-dotnet: nothing to do. It follows both recommendations (`src/PostHog/Api/PostHogApiClient.cs:206` and `:231`).
