## Divergence from the reference

posthog-js is the reference, and four requirements describe behavior that posthog-node does not have. One is mandatory: "Flag key containment". Three are recommendations (`SHOULD`): the exact flag key encoding, the failure status and the empty body. posthog-node has none of the four behaviors and no test for or against the first three. Its test for a flag with no payload mocks a response that PostHog does not send. No change to posthog-js comes with this spec.

Containment is mandatory because the request carries the secret key. With a raw key such as `../../../users/@me/#`, an HTTP client resolves the dot segments and drops the fragment, so the request goes to another API route with the `Authorization` header and without the `token` query. An application that passes an untrusted flag key then exposes other routes to the secret key. The shipped SDKs that do not contain the key do not conform ("Existing SDK conformance").

The three recommendations leave every shipped SDK conformant on those points. The spec recommends the exact encoding so that SDKs send the same request for the same key, the failure status because a caller cannot tell an error body from a payload, and the empty body because PostHog answers a flag that has no payload with an empty body.

| Requirement | What the requirement says | posthog-js | Covering test in posthog-js |
|---|---|---|---|
| Flag key containment | The flag key cannot change the path outside its one segment, the query, or the fragment of the request. Mandatory. | The key goes into the path as is (`packages/node/src/client.ts:3232`). | No covering test. |
| Flag key encoding | The SDK should use the exact percent-encoding of "Flag key encoding". | The key goes into the path as is (`packages/node/src/client.ts:3232`). | No covering test. |
| Failure status | A response with a status outside 200 to 299 should fail the call. The body should not be the payload. | No status check. A JSON error body is returned as the payload (`packages/node/src/client.ts:2187-2206`). | No covering test. |
| Empty body | For a response with a status from 200 to 299 and an empty body, the SDK should return no result and should not report a failure. | `response.json()` rejects on an empty body, and nothing catches it (`packages/node/src/client.ts:2192`). | "should return empty object when no payload is available" (`packages/node/src/__tests__/posthog-node.spec.ts:3531`) mocks a `{}` response, which PostHog does not send for this case. |

PostHog answers a remote config flag that has no payload with status 200 and an empty body. In PostHog/posthog at `786b3fefd40aa9153ff93f90fa7fb023735448d2`, `_remote_config_response` ends with `return Response(payloads.get("true") or None)` (`products/feature_flags/backend/api/feature_flag.py:6626`), and the Rust service documents "200 with an empty body and no Content-Type (NOT a JSON `null`)" (`rust/feature-flags/src/api/remote_config.rs:333`).

The posthog-js lines were read at posthog-js `origin/main` `9c9da5bf7a36842a0bea1b05dfd0bcfbe0714f92`. A plain key gives the same request in posthog-js and in an SDK that follows the recommendation. An SDK that does not follow a recommendation still conforms. "Existing SDK conformance" says which shipped SDKs follow each one.

## Context

Sources, in priority order:

1. The reference, posthog-node in PostHog/posthog-js at `9c9da5bf7a36842a0bea1b05dfd0bcfbe0714f92`: `packages/node/src/client.ts:2177-2206` (the method) and `:3227-3262` (the request), and the tests in `packages/node/src/__tests__/posthog-node.spec.ts:3487-3608`.
2. The four other shipped SDKs, read at their `origin/main`: posthog-python `f6f61834`, posthog-ruby `4aa70bd7`, posthog-go `1b4a007f`, posthog-dotnet `cc9fa5be`.
3. The tracker, PostHog/posthog-android#577.

This change was written against sdk-specs `main` at `57407963789cfc8ae411cf1895c09b1f7f8b575c`.

The method is not the client `/config` bootstrap. That feature belongs to the `remote-config` capability, and compliance rows such as `compliance/posthog-node.md` (row 56) and `compliance/posthog-python.md` (row 56) already say the per-flag method is unrelated to it. This change adds a sibling capability and does not touch `remote-config`. Open PR PostHog/sdk-specs#210 changes only `openspec/specs/remote-config/spec.md` and its own archive folder, so the two changes do not overlap.

## Goals / Non-Goals

**Goals:**

- One contract for a server SDK that adds the method, so the four SDKs without it (posthog-android `posthog-server`, posthog-php, posthog-elixir, posthog-rs) have something to implement against.
- Every requirement traces to posthog-node code. Where posthog-node has a test, the mapping names it. Where it has none, "Reference mapping" says so.

**Non-Goals:**

- Caching, background sync and ETag use. PostHog/posthog#69808 asks for them.
- The client `/config` bootstrap.
- Changing the five SDKs that already have the method.

## Decisions

- **A new capability.** `README.md` says a new capability is a new sibling folder. The name `get-remote-config-payload` follows the SDK method name and does not collide with `remote-config`.
- **Server SDKs only.** The request needs a secret key, which must never reach a client.
- **The requirements follow posthog-node, with one mandatory rule and three recommendations beyond it.** Where another shipped SDK agrees, the requirement is firm. Flag key containment is mandatory, and the exact flag key encoding, the failure status and the empty body are recommendations. posthog-node follows none of them (see "Divergence from the reference"). For the other points where the shipped SDKs disagree and posthog-node has no test, the requirement says only what all of the evidence supports, and the point is an open decision below.
- **A flag key cannot leave the remote config route.** The request carries the secret key, so the rule is mandatory. An SDK encodes the key as one path segment, or refuses it. Percent-encoding does not change `.` and `..`, so an SDK that encodes also refuses or contains those two keys. The four new ports encode the key as one segment and refuse a key that is empty, `.` or `..`, so they conform.
- **The recommended encoding keeps the flag key one path segment.** In that encoding, the RFC 3986 unreserved set is never encoded. `/`, `?`, `#`, `%`, a space and non-ASCII bytes are always encoded. The other characters that RFC 3986 permits in a path segment (the sub-delimiters, `:` and `@`) are optional, because path-segment builders differ: `Uri.EscapeDataString` in posthog-dotnet and `quote(key, safe='')` in the async client of posthog-python encode them, and the OkHttp and Rust `url` path-segment builders do not. Both forms name the same segment. A space becomes `%20`, never `+`, because the key is in a path.
- **A failure status should be a failed request.** The recommended result is the same as for a request that does not complete. This matches posthog-python, posthog-go and posthog-dotnet. A caller cannot tell an error object from a payload otherwise.
- **An empty body is a flag with no payload.** PostHog sends status 200 and an empty body for a flag that has no payload, so the recommended result is no result and no failure report.
- **The second parse stays.** posthog-node comments that the endpoint answers with a JSON string that holds the payload's JSON text, and that a single-encoded body is possible but not expected (`client.ts:2193-2195`). The requirement keeps both. The rule differs from `get-feature-flag-payload`, which forbids a second decode of a payload string from `/flags`, because that payload arrives in a different response. A consequence of the rule is that a string payload such as `"123"` comes back as the number `123`. posthog-node and posthog-dotnet do the same.
- **A string that is not JSON is returned, not dropped.** `get-feature-flag-payload` returns no payload for a malformed serialized payload. This endpoint is different: the body is already a JSON string, and posthog-node returns that string when the second parse fails (`client.ts:2200-2203`). The two rules apply to different sources.
- **"No result" covers error returns.** Go, Rust and Elixir return an error next to the value. The spec defines no result so that an error return and an empty value both count, and does not name a single type.
- **A disabled client is checked before the secret key.** posthog-node, posthog-python and posthog-dotnet check in that order (`client.ts:2178-2185`, `client.py:5150-5157`, `PostHogClient.cs:1008-1016`).
- **A missing project token is a disabled client.** posthog-node (`posthog-core-stateless.ts:426-433, 456`), posthog-python (`client.py:1403`), posthog-ruby (`client.rb:161`), posthog-dotnet (`PostHogClient.cs:115-116`) and posthog-go (`posthog.go:284-288`, a noop client) all treat it so.
- **Independent of local evaluation.** posthog-node has a test for it (`posthog-node.spec.ts:3565`). The port should not wait for flag definitions.

## Decided

| Date | Point | Decision |
|---|---|---|
| 2026-11-13 | Flag key containment | Mandatory. The flag key SHALL NOT change the path outside its one segment, the query, or the fragment of the request. Requirement "Flag key containment", with a scenario for `../../../users/@me/#`. |
| 2026-11-13 | Flag key encoding | Recommendation. The SDK SHOULD percent-encode the flag key as one path segment. Requirement "Flag key encoding", with a scenario for `a/b?c#d e`. |
| 2026-11-13 | Failure status | Recommendation. A response with a status outside 200 to 299 SHOULD be treated as a failed request, and the SDK SHOULD NOT return the body as the payload. Requirement "Failure status", with scenarios for 401, 404 and 500. |
| 2026-11-13 | Empty body | Recommendation. For a response with a status from 200 to 299 and an empty body, the SDK SHOULD return no result and SHOULD NOT report a failure. Requirement "Empty body", with one scenario. |
| 2026-11-13 | Strength of the three points and of the open points | Flag key encoding, failure status and empty body are recommendations, because posthog-node has none of these behaviors. Flag key containment is mandatory, because the request carries the secret key. The points below stay open and loose. |

## Open decisions

This change leaves each point below undefined. The requirements say nothing stronger than the evidence supports, and the spec does not define these points. A later change that decides a point adds the text to the spec, adds a scenario, and updates "Reference mapping".

The four new ports choose a behavior for each point. Where that behavior is not in a requirement, it is a design choice of the port and not part of the contract.

### OD1. A missing secret key

posthog-node throws (`client.ts:2183-2185`, test `posthog-node.spec.ts:3506`). The other four shipped SDKs differ from it and from each other.

| SDK | Behavior | Evidence |
|---|---|---|
| posthog-node | Throws `Error('Personal API key is required for remote config payload decryption')`. A blank key counts as missing. | `client.ts:2183-2185`, `:123-126`, `:271` |
| posthog-python | Logs a warning, returns `None`. | `client.py:5153-5157` |
| posthog-ruby | No guard. Sends `Authorization: Bearer ` with an empty credential. | `feature_flags.rb:1900`, `client.rb:571-574` |
| posthog-go | Logs a warning, returns `ErrNoSecretKey`. | `posthog.go:2014-2017` |
| posthog-dotnet | Logs a warning, returns `null`. | `PostHogClient.cs:1013-1016` |

The requirement lets the SDK report an error through its error channel, or log a warning and return no result. In both cases it sends no request. A thrown error counts as an error channel. This matches posthog-node, posthog-python, posthog-go and posthog-dotnet. Ruby does not conform.

Planned ports: posthog-rs returns `Err`, posthog-elixir returns `{:error, ...}`, and posthog-android and posthog-php log a warning and return `null`. The last two differ from posthog-node but match posthog-python and posthog-dotnet.

Options:

- **A (current).** Error channel or warning with no result. Throw is allowed.
- **B.** Same, but a throw is not allowed. posthog-node would not conform. This matches the acceptance rule that a public SDK method must not throw (`.agents/skills/writing-acceptance-tests/SKILL.md`, "Observe public behavior"). It needs a posthog-node change.
- **C.** Require an error or a throw, never a silent empty value. posthog-python and posthog-dotnet would not conform.

The acceptance feature does not accept a throw as a success outcome in either option. Its scenario only checks that no request is made and no payload is returned.

If B is chosen, replace the last sentence of the requirement with: "The SDK SHALL tell the caller about the missing key by returning an error value or by logging a warning and returning no result. It SHALL NOT throw or reject."

### OD2. A 2xx response whose body is not JSON

posthog-node reads the body with `response.json()` (`client.ts:2192`) and nothing catches a parse error, so the call rejects. No test covers it. The spec does not define the result. The failure status requirement covers a status outside 200 to 299 only. This point covers a complete body that is not empty. "Empty body" covers an empty body, and "Request failure" covers a connection that fails during the body read.

| SDK | Body that is not JSON | Evidence |
|---|---|---|
| posthog-node | The promise rejects | `client.ts:2192` |
| posthog-python | Raises, caught, `None` | `request.py:282-323`, `client.py:5173-5176` |
| posthog-ruby | Returns `{error: 'Invalid JSON response', body:, status:}` | `feature_flags.rb:1961-1964` |
| posthog-go | Returns an error | `posthog.go:2049-2051` |
| posthog-dotnet | Not read | |

The four new ports treat it as a failed request, with the same result as a request failure. A later change can add to "Failure status": "A response whose body is not JSON SHALL be treated as a failed request." posthog-node and posthog-ruby would not conform.

### OD3. Request timeout

posthog-node sets a timeout only when the `requestTimeout` option is set, and none otherwise (`client.ts:3243-3250`). The abort does not cover the read of the body. The option `remoteConfigRequestTimeoutMs`, default 3000, exists in the core (`posthog-core-stateless.ts:454`) but only the `/config` bootstrap uses it (`:787`). No test covers a timeout.

| SDK | Timeout | Evidence |
|---|---|---|
| posthog-node | None unless `requestTimeout` is set | `client.ts:3243-3250` |
| posthog-python | `feature_flags_request_timeout_seconds`, default 3 | `client.py:5170`, `:1134` |
| posthog-ruby | Flag request timeout, 3 seconds | `feature_flags.rb:1902`, `defaults.rb:21` |
| posthog-go | `BatchUploadTimeout`, 10 seconds. `DefaultFeatureFlagRequestTimeout` is 3 seconds and is not used. | `posthog.go:313, 316`, `config.go:300, 311-313` |
| posthog-dotnet | The method sets none. The `HttpClient` default applies. That default was not read. | `PostHogApiClient.cs:229` |

The spec sets no timeout requirement. posthog-android and posthog-elixir have no feature flag request timeout, so a rule that names one has no target there. The ports add nothing for them, and the HTTP client default applies. posthog-php and posthog-rs use their flag request timeout.

A later change can add: "The SDK SHALL bound the request with a timeout. A request that exceeds it SHALL fail as in 'Request failure'." It needs a scenario where the mock server delays the answer past the timeout and expects no result.

### OD4. The host of the request

posthog-node sends the request to the client's configured host (`client.ts:3232`). posthog-go sends it to `AppHost` when that is set, else to `Endpoint` (`config.go:355-360`). posthog-elixir sends the flag definitions request to `api_host`, but its only `@current` request, the emails request, goes to `app_host` and refuses a host that is not PostHog Cloud without an app host (`lib/posthog/emails.ex:827-847`; the `api_host` base URL of the definitions request, `lib/posthog/api.ex:29`, was not re-read). The requirement says "the client's configured host". It fits posthog-node, posthog-python, posthog-ruby and posthog-dotnet, and it fits posthog-go when no `AppHost` is set.

The four new ports use the host that the SDK already uses for the local evaluation definitions request, because that request also carries the secret key. The spec keeps the wording "the client's configured host" and does not choose between an API host and an app host.

### OD5. A flag key that is empty, `.` or `..`

posthog-node has no guard (`client.ts:3232`). No test covers it. Percent-encoding does not change `.`, so a key of `..` is still a dot segment. URL builders in OkHttp and the Rust `url` crate drop or rewrite those segments, and the request then goes to a different endpoint. posthog-go removes a segment for `..` (reported, from a local run of `url.JoinPath`).

The four new ports refuse such a key with no request and report it as each SDK reports a failure. The spec does not define the result for this key. "Flag key containment" forbids a request to a path of another form, so only the result is open. The repo's specs use `SHOULD` for guidance that an SDK can skip (63 uses in `openspec/specs` at the sdk-specs SHA above), so a `SHOULD` is possible later: "An SDK SHOULD refuse a flag key that is empty, `.` or `..` and send no request." This change keeps the result undefined.

### Headers are not an open decision

posthog-node sends `User-Agent`, `Content-Type: application/json` and `Authorization` (`client.ts:3236-3240`), and the test checks `Content-Type` and `Authorization` (`posthog-node.spec.ts:3601-3604`). posthog-python sends `Authorization` and `User-Agent` only (`request.py:476-479`). posthog-dotnet sends `Authorization` only per request (`PostHogApiClient.cs:226-227`). The four new ports send `Authorization` and `User-Agent` only, and dropping `Content-Type` is a divergence from posthog-node. The spec requires only `Authorization` and allows other headers. The ports can leave out `Content-Type`.

## Existing SDK conformance

The table says how each shipped SDK stands against the requirements. The spec does not change them. A row marked "No" is a gap to fix in that SDK, except in the rows "Flag key encoding", "Empty body" and "Failure status". Those three rows are recommendations. Their cells say if the SDK follows the recommendation, and a "No" there is not a conformance gap (see the lists after the table). All line numbers for these two rows were read at the SHAs below. "Not re-read" means an earlier read of the SDK reported the line, and it was not read again for this change.

| Requirement | posthog-node | posthog-python | posthog-ruby | posthog-go | posthog-dotnet |
|---|---|---|---|---|---|
| Public surface | Yes (`client.ts:2177`) | Yes (`client.py:5131`) | Yes (`client.rb:571`) | Yes (`posthog.go:2003`, interface line not re-read) | Yes (`PostHogClient.cs:1006`) |
| Request | Yes (`client.ts:3232-3235`) | Yes (`request.py:420`) | Yes (`feature_flags.rb:1896-1898`) | Yes when `AppHost` is not set (`posthog.go:2004`, `config.go:355-360`) | Yes (`PostHogApiClient.cs:206-209`) |
| Flag key containment | No. The raw key goes into the path (`client.ts:3232`) | No on the sync path: the raw key goes into the path (`request.py:420`). No on the async path for `.` and `..`: `quote(key, safe='')` contains `/`, `?` and `#` (`_async_request.py:184`), but a key of `..` gives the path `/api/projects/@current/remote_config` (from a local run with httpx 0.28.1) | No. The raw key goes into the path (`feature_flags.rb:1896`) | No. `url.JoinPath` with the raw key (`posthog.go:2004`). `?`, `#` and a space come out escaped, a `/` splits the path, and `..` removes a segment. The key `../../../users/@me/#` gives the path `/api/users/@me/%23/remote_config` (from a local run with go1.27.3) | No for `.` and `..`. `Uri.EscapeDataString` contains `/`, `?` and `#` (`PostHogApiClient.cs:206`), but a key of `..` gives the path `/api/projects/@current/remote_config` (from a local run with .NET 9.0.0) |
| Flag key encoding (follows the recommendation) | No. The key is not encoded (`client.ts:3232`) | No on the sync path (`request.py:420`). Yes on the async path (`_async_request.py:184`, `quote(key, safe='')`) | No. The key is not encoded (`feature_flags.rb:1896`) | No. `url.JoinPath` with the raw key. `?`, `#` and a space come out escaped, but a `/` splits the path (`posthog.go:2004`; the behavior of `/` is reported from a local run) | Yes (`PostHogApiClient.cs:206`, `Uri.EscapeDataString`) |
| Authentication | Yes (`client.ts:3239`) | Yes (`request.py:477`) | Yes (`feature_flags.rb:1900`) | Yes (`posthog.go:2029`) | Yes (`PostHogApiClient.cs:220-227`) |
| No distinct id | Yes | Yes | Yes | Yes | Yes |
| Disabled client or missing project token | Yes (`client.ts:2178-2181`; trims the token, `posthog-core-stateless.ts:426`) | Yes for an empty token. A whitespace-only token is not missing (`client.py:5150`, `:1403`) | Yes for an empty token. Whitespace-only is not missing (`client.rb:161`, `:572`) | Yes. Returns the error `ErrSDKDisabled` (`noop_posthog.go:44-46`, `posthog.go:284-288`) | Yes (`PostHogClient.cs:1008-1011`, `:115-116`). Trimming not re-read |
| Missing secret key | Yes under OD1 option A, by a throw (`client.ts:2183-2185`) | Yes (`client.py:5153-5157`) | No. Sends the request (`feature_flags.rb:1900`) | Yes (`posthog.go:2014-2017`) | Yes (`PostHogClient.cs:1013-1016`) |
| Blank secret key counts as missing | Yes (`client.ts:123-126`) | Not re-read | Not re-read | Not re-read | Not re-read |
| Payload decoding | Yes (`client.ts:2192-2205`) | No. Decodes once, so a string body stays a string (`request.py:284`, `:418-425`) | No. Decodes once, and merges `:status` into a Hash payload (`feature_flags.rb:1954-1958`) | No. Returns a Go `string` decoded once. A body that is not a JSON string is a parse error (`posthog.go:2048-2052`) | Yes (`PostHogClient.cs:1027-1034`), returns a `JsonDocument` |
| String that is not JSON | Yes (`client.ts:2200-2203`) | Yes, trivially | Yes, trivially | Yes for a string body | Yes (`PostHogClient.cs:1034`) |
| Empty body (follows the recommendation) | No. `response.json()` rejects on an empty body, nothing catches it, and the call rejects (`client.ts:2192`) | No. `res.json()` is not guarded (`request.py:284`). The caller catches the error, logs it and returns `None` (`client.py:5173-5176`). `json.loads('')` raises, from a local run. The SDK call was not run | No. `JSON.parse` raises `JSON::ParserError` on an empty string (`feature_flags.rb:1954`, from a local run of `JSON.parse`), and the call returns the Hash `{error: 'Invalid JSON response', body:, status:}` (`:1960-1964`). A `nil` body was not checked | No. `json.Unmarshal` of an empty body returns an error (from a local run), and the call returns it (`posthog.go:2049-2051`) | No. `ReadFromJsonAsync` is not guarded (`PostHogApiClient.cs:233-235`). The caller catches the exception, logs an error and returns `null` (`PostHogClient.cs:1036-1039`). Not run |
| Request failure | Yes for a failure before the response headers arrive: the helper catches it, emits `error`, and the call returns `undefined` (`client.ts:3254-3256`). No for a failure during the body read: `response.json()` is outside the `try` of the helper and nothing catches its rejection, so the call rejects (`client.ts:2192`) | Yes. Logs, returns `None` (`client.py:5173-5176`) | No. The exception reaches the caller (`feature_flags.rb:1975-1982`) | Yes. Returns an error (`posthog.go:2033-2036`) | Yes. Logs, returns `null`. An `ArgumentException` or `NullReferenceException` is not caught (`PostHogClient.cs:1036-1039`) |
| Failure status (follows the recommendation) | No. No status check, a JSON error body is returned as the payload (`client.ts:2187-2206`) | Yes. Only status 200 is a success, other statuses raise, are caught and logged, and the call returns `None` (`request.py:282-323`, `client.py:5173-5176`). Status 201 to 299 would also fail, which the recommendation does not ask for, but the endpoint does not answer with them | No. Returns the body as a Hash with `:status` merged in (`feature_flags.rb:1952-1958`). A body that is not a Hash comes back without `:status` | Yes. Any status other than 200 is an error (`posthog.go:2039-2041`). The same note on 201 to 299 applies | Yes. `EnsureSuccessfulApiCall` throws, the caller logs and returns `null` (`PostHogApiClient.cs:231`, `PostHogClient.cs:1036-1039`) |
| One request per call | Yes (`client.ts:3253`) | No. The session retries connect and read errors twice (`request.py:80-92`, `:118-121`, `:484`) | No. Retries a timeout or a reset up to the flag retry limit (`feature_flags.rb:1967-1974`) | Yes (`posthog.go:2033`) | Yes (`PostHogClient.cs:1020`). Handler retries not re-read |
| No caching | Yes (not re-read) | Yes (not re-read) | Yes (not re-read) | Yes (not re-read) | Yes (not re-read) |
| No events | Yes (`client.ts:2177-2206`) | Yes (`client.py:5150-5176`) | Yes (`client.rb:571-575`) | Yes (`posthog.go:2003-2053`) | Yes (`PostHogClient.cs:1006-1055`) |
| Independent of local evaluation | Yes (test `posthog-node.spec.ts:3565`) | Yes (`client.py:5150-5176`) | Calls through the poller object (`client.rb:574`). Not re-read whether it needs local evaluation | Yes (`posthog.go:2003-2053`) | Yes (`PostHogClient.cs:1020`) |

Differences between the five SDKs that the table shows:

- **Missing secret key.** Ruby sends the request. Node throws. The others log and return an empty value or an error.
- **Return type.** Node returns the JSON value. Python and Ruby return one decode. Go returns a Go `string`. .NET returns a `JsonDocument`. The spec names the JSON value type. Python, Ruby and Go would need a change to return the second-parsed value. The existing docs for them differ too: the page `contents/docs/feature-flags/remote-config.mdx` in posthog.com (at `54978bc1`) says Python returns a JSON encoded string to parse, and Ruby returns a parsed object. The Python docs match the code only for a string body.
- **Escaping.** Containment is mandatory, and no shipped SDK meets it for every key (row "Flag key containment"). The exact encoding is a recommendation. See "Shipped SDKs and the three recommendations".
- **Failure.** Ruby raises on a request that does not complete. Node and Ruby return the body of a non-2xx response as the payload. The spec recommends that a failure status fails the call. See "Shipped SDKs and the three recommendations".
- **Retries.** Python retries connect and read errors through its session. Ruby retries a timeout or a reset up to the flag retry limit, and a status in its retry list. Node, Go and .NET do not retry. The requirement "One request per call" holds for Node, Go and .NET only.

## Shipped SDKs and the three recommendations

Each line below was re-read with `git show origin/main:<path>` at the repository SHA shown. No shipped SDK is non-conformant on these three points. A shipped SDK can adopt a recommendation in a change of its own. This change modifies no SDK.

Flag key encoding (the key should be percent-encoded as one path segment):

- posthog-node, posthog-js `9c9da5bf7a36842a0bea1b05dfd0bcfbe0714f92`: does not follow the recommendation. `packages/node/src/client.ts:3232` puts `${flagKey}` into the path unencoded.
- posthog-python `f6f61834c8782e2b8c7ec6136af51c077d8bb22c`, sync path: does not follow the recommendation. `posthog/request.py:420` puts `{key}` into the path unencoded.
- posthog-ruby `4aa70bd73d7cd93eaa5b059a2f6a1fd76cbedeaf`: does not follow the recommendation. `lib/posthog/feature_flags.rb:1896` puts `#{flag_key}` into the path unencoded.
- posthog-go `1b4a007f9735fe5d08bbcc46165315d2546e28d1`: does not follow the recommendation. `posthog.go:2004` calls `url.JoinPath` with the raw key, so a `/` in the key splits the path.
- Follows the recommendation: posthog-dotnet `cc9fa5beafbe30252edb74959a97260d706facd2`, `src/PostHog/Api/PostHogApiClient.cs:206` (`Uri.EscapeDataString(key)`). posthog-python async path, `posthog/_async_request.py:184` (`quote(key, safe='')`).

Failure status (a status outside 200 to 299 should fail the call, and the body should not be the payload):

- posthog-node: does not follow the recommendation. `packages/node/src/client.ts:2187-2206` checks no status. The helper returns the response whatever its status (`:3253`) and the method returns its parsed body.
- posthog-ruby: does not follow the recommendation. `lib/posthog/feature_flags.rb:1952-1958` parses the body and returns it as a Hash with `:status` merged in. It checks no status except the retry list and 304.
- Follows the recommendation: posthog-python (`posthog/request.py:282-323`), posthog-go (`posthog.go:2039-2041`), posthog-dotnet (`src/PostHog/Api/PostHogApiClient.cs:231`).

Empty body (a response with a status from 200 to 299 and an empty body should give no result and no failure report):

- No shipped SDK follows the recommendation. The row "Empty body" of the table in "Existing SDK conformance" has each `file:line`.

Flag key containment is mandatory and is not one of the three recommendations. The row "Flag key containment" of the table in "Existing SDK conformance" has the gap of each shipped SDK.

## Reference mapping

References are posthog-js at `9c9da5bf7a36842a0bea1b05dfd0bcfbe0714f92`. `client.ts` is `packages/node/src/client.ts`. `spec.ts` is `packages/node/src/__tests__/posthog-node.spec.ts`. `core.ts` is `packages/core/src/posthog-core-stateless.ts`.

The tests at `spec.ts:3531`, `:3541`, `:3554` and `:3565` replace `_requestRemoteConfigPayload` with a mock (`:3532`, `:3543`, `:3556`, `:3577`). They check the decode step and the call argument, not the HTTP request. The tests at `:3506`, `:3518` and `:3589` run the real request helper.

| Requirement | posthog-js `file:line` | Covering test |
| --- | --- | --- |
| Public surface | `client.ts:2177` (one argument), `:2173-2175` (doc) | No covering test. Every test calls the method with one argument (for example `spec.ts:3536`), but none checks the signature. |
| Request | `client.ts:3232` (URL), `:3235` (`GET`) | `spec.ts:3589` "should include project API key in the remote config URL" covers method, path and `token` with the exact URL. It does not check that the request has no body. |
| Flag key containment | `client.ts:3232` (the key is put into the path as is, so a key can change the path, start a query or start a fragment) | No covering test. |
| Flag key encoding | `client.ts:3232` (the key is put into the path as is; only the project token goes through `encodeURIComponent`) | No covering test. `spec.ts:3589` uses the key `test-flag`, which has no reserved character. |
| Authentication | `client.ts:3239` (Bearer), `:123-126` and `:271` (key normalised, `secretKey` before `personalApiKey`), `packages/node/src/types.ts:265-269` | `spec.ts:3589` covers the `Authorization: Bearer TEST_PERSONAL_API_KEY` header and, by the exact URL, that the key is not in the URL. No covering test for the `secretKey` option (the tests use `personalApiKey`). |
| No distinct id | `client.ts:2177` (signature), `:3227-3262` (the request has none) | Partial. `spec.ts:3589` asserts the exact URL, so no extra query parameter. No covering test for an ambient context being ignored. |
| Disabled client or missing project token | `client.ts:2178-2181` (disabled), `:3228-3230` (helper guard), `core.ts:426-433` and `:456` (a blank project token disables the client) | `spec.ts:3518` "should return undefined without fetching when api key is missing" covers a whitespace-only project token. No covering test for `disabled: true`. No covering test for the order (disabled before secret key). |
| Missing secret key | `client.ts:2183-2185` (throws), `:3228` (helper guard), `:123-126` (blank is missing) | `spec.ts:3506` "should throw error when personalApiKey is not provided" covers the throw only. The spec also allows a warning with no result, and no posthog-js behavior or test covers that. No covering test for a whitespace-only secret key. |
| Payload decoding | `client.ts:2192` (decode), `:2196-2199` (second parse of a string), `:2205` (other values unchanged) | `spec.ts:3531` "should return empty object when no payload is available" (`{}`), `:3541` "should handle double-encoded JSON payload" (string body), `:3554` "should handle simple JSON payload" (object body). No covering test for an array in a string, a number in a string, or an array that holds a string. |
| String that is not JSON | `client.ts:2200-2203` | No covering test. |
| Empty body | `client.ts:2192` (`response.json()` is not guarded, so the call rejects on an empty body) | No covering test. `spec.ts:3531` "should return empty object when no payload is available" mocks a `{}` response, which PostHog does not send for a flag with no payload. |
| Request failure | `client.ts:3252-3256` (the helper catches, emits `error`, returns `undefined`), `:2188-2190` (the method returns `undefined`), `:2192` (`response.json()` is outside that `try`, so a connection that closes during the body read rejects to the caller) | No covering test. |
| Failure status | `client.ts:2187-2206` (no status check), `:3253` (the helper returns the response whatever its status), `:2192` (`response.json()` reads the error body as the payload) | No covering test. |
| One request per call | `client.ts:3253` (one `this.fetch` call, which is the platform fetch, not `fetchWithRetry`: `core.ts:1896`) | No covering test. `spec.ts:3597` uses `toHaveBeenCalledWith` and does not count calls. posthog-python and posthog-ruby retry ("Existing SDK conformance"). |
| No caching | `client.ts:2177-2206` and `:3227-3262` hold no cache read or write | No covering test. |
| No events | `client.ts:2177-2206` holds no `capture` call | No covering test. |
| Independent of local evaluation | `client.ts:2177-2206` does not use the flag poller | `spec.ts:3565` "should work without local evaluation enabled" checks the result and that no poller exists. |

Points left out of the requirements (see "Open decisions"):

| Point | posthog-js `file:line` | Covering test | Where |
| --- | --- | --- | --- |
| Missing secret key: error channel, or warning and no result | `client.ts:2183-2185` | `spec.ts:3506` | OD1 |
| A 2xx response whose body is not JSON | `client.ts:2192` (`response.json()` is not guarded, so the call rejects) | No covering test. | OD2 |
| Timeout | `client.ts:3243-3250` (only when `requestTimeout` is set) | No covering test. | OD3 |
| Host when the SDK has more than one | `client.ts:3232` (`this.host`) | `spec.ts:3598` checks the host `http://example.com` for the one configured host only. | OD4 |
| A flag key that is empty, `.` or `..` | `client.ts:3232` (no guard) | No covering test. | OD5 |

Requirements with no covering test in posthog-js: Public surface, Flag key containment, Flag key encoding, No distinct id (partial only), Disabled client (the `disabled: true` case and the order), Missing secret key (the warning-and-empty path and the blank key), String that is not JSON, Empty body, Request failure, Failure status, One request per call, No caching, No events. Payload decoding has no test for three of the six example rows.

## Notes

- The `secret key` is a Personal API Key or a Project Secret API Key. The docs page says a Project Secret API Key returns encrypted payloads redacted and that decryption needs a Personal API Key (`remote-config.mdx`, "Encrypted payloads"). The request is the same for both, and no SDK checks the key type. The spec does not mention encryption.
- posthog-node accepts the key as `secretKey`, with `personalApiKey` as a deprecated alias (`packages/node/src/types.ts:265-269`). The spec says "the SDK's existing secret key option" so that no port adds an option.

## Archive-time text

At archive, add these sections above `## Requirements` in `openspec/specs/get-remote-config-payload/spec.md`, as the `add-emails` change did.

```
# Get Remote Config Payload Specification

## Purpose

Read the payload of one remote config feature flag by its key, with one request to PostHog that needs a secret key and no distinct id. The result is the payload as a JSON value. The call does not cache the result and does not capture an event.

## Applicability

Server SDKs only. The request needs a secret key, which must never reach a client. The reference surface is `getRemoteConfigPayload` in posthog-node. Other SDKs can use native names, async conventions, return types and error channels, as the requirements allow.

Not covered: the client `/config` bootstrap (`remote-config`), caching and background sync of payloads.

## Public surface

| SDK | Name |
|---|---|
| posthog-node | `getRemoteConfigPayload(flagKey)` |
| posthog-python | `get_remote_config_payload(key)` |
| posthog-ruby | `get_remote_config_payload(flag_key)` |
| posthog-go | `GetRemoteConfigPayload(flagKey)` |
| posthog-dotnet | `GetRemoteConfigPayloadAsync(key, cancellationToken)` |
```

## Risks / Trade-offs

- Flag key containment is mandatory, and no shipped SDK meets it for every key. posthog-node, posthog-python (sync), posthog-ruby and posthog-go put the raw key into the path. posthog-dotnet and the async path of posthog-python do not contain `.` and `..`. Each one does not conform until it changes.
- posthog-node does not conform to "Request failure" for a connection that fails during the body read: the call rejects (`client.ts:2192`). It needs a change in posthog-js.
- The spec recommends two behaviors that posthog-node does not have: flag key encoding and failure status. They are recommendations, so the SDKs can differ. posthog-node, posthog-python (sync), posthog-ruby and posthog-go do not encode the key, and posthog-node and posthog-ruby return the body of a non-2xx response as the payload. A caller that moves between SDKs can see a different result for a key with reserved characters and for a failure status.
- No shipped SDK follows the empty body recommendation. A read of a flag that has no payload rejects in posthog-node, logs an error in posthog-python and posthog-dotnet, returns an error in posthog-go, and returns an error Hash in posthog-ruby.
- OD1 to OD5 are open. A port written to the spec alone can choose any behavior for them. If a later change picks a stricter rule for OD1 option B, OD2 or OD3, posthog-node can need a change.
- No harness binding exists for the acceptance phrases. The feature file states this in its header, as `emails.feature` does, and carries no `@sdk:server` tag.
