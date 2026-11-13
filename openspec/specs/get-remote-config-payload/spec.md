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

## Requirements

### Requirement: Public surface

A server SDK SHALL expose a method on its client that reads the payload of one remote config feature flag by its key. The reference name is `getRemoteConfigPayload`. An SDK spells it in its own case convention and async style. The method takes the flag key and no other required argument. A client SDK SHALL NOT expose it, because the request needs a secret key.

In this spec, a payload is the JSON value that PostHog holds for the flag. No result is the outcome of a call that returns no payload. In a language where the method returns one value, no result is that language's empty value (`null`, `nil`, `None` or `undefined`). In a language where the method also returns an error, no result is the empty value or an error.

#### Scenario: One argument is enough
- **GIVEN** a server SDK client created with a project token and a secret key
- **WHEN** the caller reads the payload of `test-flag` and passes nothing else
- **THEN** the SDK sends one request for `test-flag`

### Requirement: Request

The SDK SHALL send `GET {host}/api/projects/@current/feature_flags/{flag key}/remote_config?token={project token}`. `{host}` is the client's configured host. `{flag key}` is the flag key as one path segment. "Flag key containment" requires that, and "Flag key encoding" recommends the exact encoding. The query holds the `token` parameter and no other parameter. The request has no body.

#### Scenario: A plain key reaches the remote config route
- **GIVEN** a client with project token `TEST_API_KEY`, host `http://example.com` and a secret key
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the mock server receives one `GET http://example.com/api/projects/@current/feature_flags/test-flag/remote_config?token=TEST_API_KEY`
- **AND** the request has no body

### Requirement: Flag key containment

The flag key SHALL NOT change the path outside its one segment, the query, or the fragment of the request. For every flag key, the path of a request that the SDK sends SHALL be `/api/projects/@current/feature_flags/{one segment}/remote_config`, and its query SHALL be `token={project token}`. The SDK SHALL meet this in one of two ways: it encodes the key so that it stays one path segment, or it refuses the key and sends no request. A refused key gives no result, and the SDK reports it as it reports a failure in "Request failure".

Percent-encoding does not change `.` and `..`, and an HTTP client resolves them as dot segments. An SDK that encodes the key SHALL also refuse a key that is `.` or `..`, or contain it in another way. The result for a flag key that is empty, `.` or `..` is not defined, but a request to a path of another form is not permitted.

#### Scenario Outline: A flag key does not leave the remote config route
- **GIVEN** a client with project token `TEST_API_KEY`, host `http://example.com` and a secret key
- **WHEN** the caller reads the payload of the flag key <key>
- **THEN** the mock server receives no request or one request
- **AND** the path as sent of every received request is `/api/projects/@current/feature_flags/`, then one path segment, then `/remote_config`
- **AND** the query of every received request is `token=TEST_API_KEY`

**Examples:**
  | key                    |
  | `../../../users/@me/#` |
  | `a/b`                  |
  | `a?b`                  |
  | `a#b`                  |
  | `..`                   |
  | `.`                    |

### Requirement: Flag key encoding

The SDK SHOULD percent-encode the flag key so that it stays one path segment, and an SDK that does SHALL use the encoding below. An SDK that does not use this exact encoding still conforms if it meets "Flag key containment". The encoding writes `/`, `?`, `#`, `%`, a space, and every byte of the key's UTF-8 form outside the ASCII range, as `%` and two uppercase hexadecimal digits. It writes a space as `%20`. It leaves a letter, a digit, `-`, `.`, `_` and `~` as they are. It can encode any other character that RFC 3986 permits in a path segment (for example `@`, `:`, `=` or `+`). With this encoding, a key that has `/`, `?`, `#` or `%` does not change the path or the query of the request. "Flag key containment" covers a flag key that is empty, `.` or `..`.

#### Scenario Outline: A key with reserved characters stays one path segment
- **GIVEN** an SDK that follows the flag key encoding recommendation
- **GIVEN** a client with project token `TEST_API_KEY`, host `http://example.com` and a secret key
- **WHEN** the caller reads the payload of the flag key <key>
- **THEN** the mock server receives one `GET` whose path as sent is `/api/projects/@current/feature_flags/<segment>/remote_config`
- **AND** the query of that request is `token=TEST_API_KEY`

**Examples:**
  | key           | segment             |
  | `a/b?c#d e`   | `a%2Fb%3Fc%23d%20e` |
  | `50%`         | `50%25`             |
  | `a%2Fb`       | `a%252Fb`           |
  | `café`        | `caf%C3%A9`         |

### Requirement: Authentication

The SDK SHALL send `Authorization: Bearer {secret key}`, with the secret key from the SDK's existing secret key option. The SDK SHALL NOT send the secret key in the URL. The SDK adds no new option for this method. The SDK MAY send other headers, such as its user agent.

#### Scenario: The secret key goes in the Authorization header only
- **GIVEN** a client with a secret key `phs_test`
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the request header `Authorization` equals `Bearer phs_test`
- **AND** the request URL does not contain `phs_test`

### Requirement: No distinct id

The method SHALL NOT take a distinct id. The SDK SHALL NOT send a distinct id in the request, and SHALL NOT read one from the request context.

#### Scenario: The request context does not reach the request
- **GIVEN** a request context whose distinct ID is `context_user`
- **WHEN** the caller reads the payload of `test-flag` inside that context
- **THEN** the request URL has no query parameter other than `token`
- **AND** no part of the request contains `context_user`

### Requirement: Disabled client or missing project token

A disabled client SHALL send no request and SHALL return no result. So SHALL a client whose project token is empty or has only whitespace. The SDK SHALL do this check before the secret key check.

#### Scenario: A disabled client sends nothing
- **GIVEN** a disabled client with a secret key
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the SDK returns no result
- **AND** no request is made

#### Scenario: A blank project token sends nothing
- **GIVEN** a client created with project token `  ` and a secret key
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the SDK returns no result
- **AND** no request is made

#### Scenario: A disabled client does not report a missing secret key
- **GIVEN** a disabled client with no secret key
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the SDK returns no result
- **AND** the SDK does not report a missing secret key
- **AND** no request is made

### Requirement: Missing secret key

A client with no secret key SHALL send no request and SHALL NOT return a payload. A secret key that is empty or has only whitespace counts as missing. The SDK SHALL tell the caller about the missing key in one of two ways: it reports an error through the error channel of the SDK, or it logs a warning and returns no result.

#### Scenario Outline: A missing secret key sends nothing
- **GIVEN** a client with a project token and the secret key <key>
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the caller gets no payload
- **AND** no request is made

**Examples:**
  | key      |
  | not set  |
  | ``       |
  | `   `    |

### Requirement: Payload decoding

The SDK SHALL decode the response body as JSON and return the value in the SDK's JSON value type, with the types and values that JSON gave. When the decoded value is a string, the SDK SHALL parse that string as JSON once more and return the result if it parses. The SDK SHALL NOT parse a second time when the decoded value is not a string. The endpoint answers with a JSON string that holds the payload's JSON text, and the SDK also accepts a body that is the payload itself.

#### Scenario Outline: The body decodes to the payload
- **GIVEN** a client with a secret key
- **AND** the mock server answers the request with the body <body>
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the returned payload equals the JSON value <payload>

**Examples:**
  | body                            | payload                     |
  | `{}`                            | `{}`                        |
  | `{"foo":["bar","baz"]}`         | `{"foo":["bar","baz"]}`     |
  | `"{ \"foo\":[\"bar\",\"baz\"]}"` | `{"foo":["bar","baz"]}`     |
  | `"[1,2]"`                       | `[1,2]`                     |
  | `"123"`                         | `123`                       |
  | `["{\"a\":1}"]`                 | `["{\"a\":1}"]`             |

### Requirement: String that is not JSON

When the body is a JSON string whose content is not valid JSON, the SDK SHALL return that string as is. It SHALL NOT fail and SHALL NOT return no result.

#### Scenario Outline: A string that is not JSON comes back unchanged
- **GIVEN** a client with a secret key
- **AND** the mock server answers the request with the body <body>
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the returned payload equals the string <payload>

**Examples:**
  | body             | payload       |
  | `"hello world"`  | `hello world` |
  | `"{broken"`      | `{broken`     |
  | `""`             | ``            |

### Requirement: Empty body

The SDK SHOULD return no result for a response with a status from 200 to 299 and an empty body, and an SDK that does SHALL NOT report a failure for that response: no error value, no error event and no error log. An SDK that fails on an empty body still conforms. PostHog answers a flag that has no payload with status 200 and an empty body.

#### Scenario: A flag with no payload gives no result
- **GIVEN** an SDK that follows the empty body recommendation
- **AND** a client with a secret key
- **AND** the mock server answers the request with the status 200 and an empty body
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the SDK returns no result
- **AND** the SDK does not report a failure
- **AND** no exception reaches the caller

### Requirement: Request failure

When the request does not complete, because of a connection error, a name lookup error, a TLS error or a timeout, the SDK SHALL NOT return a payload and SHALL return no result. It SHALL report the failure through a log line, an event on its error emitter, or an error value. It SHALL NOT raise an exception or reject to the caller. A failure does not change the result of later calls.

#### Scenario: An unreachable host gives no result
- **GIVEN** a client with a secret key whose host refuses connections
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the SDK returns no result
- **AND** no exception reaches the caller

#### Scenario: A later call works after a failure
- **GIVEN** a client with a secret key
- **AND** the first request fails because the mock server closes the connection
- **AND** the mock server answers the second request with the body `{"a":1}`
- **WHEN** the caller reads the payload of `test-flag` twice
- **THEN** the first call returns no result
- **AND** the second call returns the payload `{"a":1}`

### Requirement: Failure status

The SDK SHOULD treat a response with a status outside 200 to 299 as a failed request, and an SDK that does SHALL handle it as in "Request failure". The SDK SHOULD NOT return the response body as the payload, even when the body is valid JSON. An SDK that returns the body still conforms. The result for a response with a status from 200 to 299 whose body is not empty and is not JSON is not defined. "Empty body" covers an empty body.

#### Scenario Outline: A failure status gives no payload
- **GIVEN** an SDK that follows the failure status recommendation
- **GIVEN** a client with a secret key
- **AND** the mock server answers the request with the status <status> and the body <body>
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the SDK returns no result
- **AND** the SDK does not return <body> as the payload
- **AND** no exception reaches the caller
- **AND** the mock server receives 1 request

**Examples:**
  | status | body                                     |
  | 401    | `{"detail":"Authentication failed"}`     |
  | 404    | `{"detail":"Not found."}`                |
  | 500    | `{"detail":"Server error"}`              |

#### Scenario: A later call works after a failure status
- **GIVEN** an SDK that follows the failure status recommendation
- **GIVEN** a client with a secret key
- **AND** the mock server answers the first request with the status 401 and the body `{"detail":"Authentication failed"}`
- **AND** the mock server answers the second request with the body `{"a":1}`
- **WHEN** the caller reads the payload of `test-flag` twice
- **THEN** the first call returns no result
- **AND** the second call returns the payload `{"a":1}`

### Requirement: One request per call

Each call SHALL send one request. The SDK SHALL NOT retry a failed request and SHALL NOT send a second request for the same call.

#### Scenario: A successful call sends one request
- **GIVEN** a client with a secret key
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the mock server receives 1 request

#### Scenario: A failed call is not retried
- **GIVEN** a client with a secret key
- **AND** the mock server closes the connection on the first request
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the mock server receives 1 request

### Requirement: No caching

Each call SHALL read the payload from PostHog. The SDK SHALL NOT keep a result for a later call and SHALL NOT send a conditional request header such as `If-None-Match`.

#### Scenario: A second call sees a changed payload
- **GIVEN** a client with a secret key
- **AND** the mock server answers the first request with the body `{"v":1}` and the second with the body `{"v":2}`
- **WHEN** the caller reads the payload of `test-flag` twice
- **THEN** the first call returns `{"v":1}`
- **AND** the second call returns `{"v":2}`
- **AND** the mock server receives 2 requests
- **AND** neither request has an `If-None-Match` header

### Requirement: No events

A call SHALL NOT capture `$feature_flag_called` or any other event.

#### Scenario: A call captures no event
- **GIVEN** a client with a secret key
- **WHEN** the caller reads the payload of `test-flag` and then flushes
- **THEN** the mock server receives no capture request
- **AND** the mock server receives no event named `$feature_flag_called`

### Requirement: Independent of local evaluation

The method SHALL work on a client with local evaluation turned off. It SHALL NOT start, wait for or fetch flag definitions.

#### Scenario: Local evaluation off
- **GIVEN** a client with a secret key and local evaluation turned off
- **WHEN** the caller reads the payload of `test-flag`
- **THEN** the mock server receives 1 request
- **AND** that request is the remote config request for `test-flag`

