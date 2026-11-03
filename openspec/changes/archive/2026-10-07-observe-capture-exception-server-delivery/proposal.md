## Why

Server SDKs already expose manual exception reporting, but the canonical `capture-exception` applicability describes only client SDKs and its acceptance scenarios are not executable through the Node adapter. Add public-call delivery coverage so exception normalization, caller identity, handled metadata, and additional properties are checked against traffic received by a mock PostHog server.

## What Changes

- Correct canonical applicability to include client and server SDKs exposing manual exception reporting, and document Node's existing public signature.
- Add two server delivery scenarios to `acceptance/public/capture-exception.feature`: a native handled exception with caller properties, and a native handled exception with properties omitted.
- Assert the primary type and message through `$exception_list[0].type` and `.value`, consistent with sdk-specs #103. Assert handled state and nonempty stack frames from the delivered event.
- Preserve existing acceptance coverage and give legacy scenarios their own setup so delivery cases do not require private queue, storage, or clock controls.
- Add a shared harness binding and a Node adapter route that constructs a native test exception and invokes public `captureException()`. Flush remains a separate public operation.
- Opt the new cases into the server integration suite after verification with a freshly built Node SDK.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture-exception`: recognize the existing server API and specify observable manual exception delivery through flush and mock-server assertions.

## Impact

Specs changes affect `openspec/specs/capture-exception/spec.md` and `acceptance/public/capture-exception.feature`, with the applied change archived on this branch before a PR is opened. The harness gains exception operation and received-envelope bindings, focused healthy/defective-host tests, documentation, and a changeset. The Node compliance adapter gains `/capture_exception`, argument-spy tests, installed-package delivery tests, and documentation; SDK production code remains unchanged.

Each follow-up branch builds on its repository's group-identify branch. Cross-repository dependencies and sdk-specs #103 remain explicit. Specs release pins, published harness images, and Node CI image pins are rolled out separately.
