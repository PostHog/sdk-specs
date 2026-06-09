# Group Identify Specification

## Purpose

`group-identify` creates or updates a **group profile** in PostHog by sending a `$groupidentify` event with the group's type, key, and properties.

Unlike `group(...)`, which sets ambient group membership for future client-side events, `group-identify` is the lower-level operation that writes metadata about the group itself.

## Applicability

`both` — server SDKs commonly expose this directly; some client SDKs expose it directly, while others only trigger it internally from `group(...)`.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Direct public API | Exposed directly in js-core-based clients; iOS/Android/Unity usually call it internally from `group(...)` rather than exposing a standalone public method. | Commonly exposed directly. |
| `distinct_id` on the wire | Usually the current ambient distinct id when a direct public method exists. | Optional in many SDKs; often defaults to a synthetic id like `$<group_type>_<group_key>` when omitted. |
| Ambient group membership | `groupIdentify(...)` by itself does not necessarily persist `$groups` membership; `group(...)` does. | No ambient group state exists. |
| Primary effect | Enqueue `$groupidentify`; may also update local group-properties-for-flags caches in some client wrappers. | Enqueue `$groupidentify` only. |

## Public signatures

### Canonical server-oriented signature

```ts
groupIdentify(
  groupType: string,
  groupKey: string | number,
  properties?: Record<string, unknown>,
  options?: {
    distinctId?: string,
    timestamp?: Date,
    uuid?: string,
    disableGeoip?: boolean,
  },
): string | boolean | void | null
```

### Client-side direct variant

```ts
groupIdentify(
  groupType: string,
  groupKey: string | number,
  groupProperties?: Record<string, unknown>,
  options?: CaptureOptions,
): void
```

### Surface variants

- **posthog-js core / react-native:** `groupIdentify(groupType, groupKey, groupProperties?, options?)`
- **Node:** `groupIdentify({ groupType, groupKey, properties, distinctId?, disableGeoip? })`
- **Python:** `group_identify(group_type, group_key, properties=None, timestamp=None, uuid=None, disable_geoip=None, distinct_id=None)`
- **Ruby:** `group_identify(group_type:, group_key:, properties:, distinct_id:, timestamp:)`
- **Go:** `client.Enqueue(posthog.GroupIdentify{Type, Key, Properties, DistinctId?, Timestamp, DisableGeoIP})`
- **.NET:** `GroupIdentifyAsync(type, key, properties, cancellationToken, distinctId?)`
- **PHP:** `PostHog::groupIdentify(['groupType' => ..., 'groupKey' => ..., 'properties' => ...])`
- **iOS / Android / Unity:** no standalone public `groupIdentify` in the audited client SDKs; `group(...)` emits `$groupidentify` internally.

## Behavior

1. **Validate group identity.** `groupType` and `groupKey` must be present and non-empty.
2. **Resolve `distinct_id` for the event.**
   - Client/stateful direct APIs typically use the current ambient distinct id.
   - Server/stateless APIs commonly accept an explicit `distinctId` and otherwise synthesize one from the group identity (for example `$company_acme`).
3. **Build a `$groupidentify` event** with properties:
   - `$group_type = <groupType>`
   - `$group_key = <groupKey>`
   - `$group_set = <properties>` (empty object/map when none are provided in many SDKs)
   - plus normal SDK enrichment such as `$lib`, `$lib_version`, timestamps, uuid, and optional `$geoip_disable`
4. **Optionally include extra context.** Some SDKs also include session id or other event-enrichment properties on the same event.
5. **Enqueue / send.** Route the event through the normal capture/batching pipeline.
6. **Do not imply ambient membership changes.** `group-identify` updates the group profile but does not, by itself, guarantee that future events will include `$groups` unless the SDK separately persists that mapping via `group(...)`.

## State & lifecycle

### Client-side state

- Direct js-core client `groupIdentify(...)` itself does not persist `$groups`; that is handled by `group(...)`.
- Some client wrappers update local group-properties-for-flags caches when group properties are supplied, but that behavior is more commonly attached to `group(...)` than to direct `groupIdentify(...)`.

### Server-side state

- None. Each call is independent apart from the shared outbound queue / worker.

### Lifecycle notes

- `group(...)` on client SDKs is often implemented as:
  1. persist ambient `$groups`
  2. emit `$groupidentify`
- Repeating `group-identify` for the same group updates the group's stored properties; it does not create a new logical group.

## Error handling

- Invalid or missing `groupType` / `groupKey` are dropped or raise validation errors depending on SDK.
- `before_send` can drop the event in SDKs that support it.
- Transport and queue failures follow the same rules as `capture(...)` in the respective SDK.
- Public methods usually do not throw in client SDKs; server SDKs vary between returning failure / `null` and raising validation errors.

## Concurrency & ordering guarantees

- `group-identify` uses the same queueing and synchronization model as `capture(...)`.
- Ordering relative to `group(...)` and `capture(...)` is only as strong as the SDK's normal queue ordering guarantees.
- If a client SDK calls `group(...)` and emits `$groupidentify` in the same logical operation, subsequent captures generally observe the new ambient `$groups` mapping once the local state write has completed, even if the `$groupidentify` event is still queued.

## Interactions

- **`group`** — higher-level client API that often persists `$groups` and then calls `group-identify` internally.
- **`capture`** — future events include `$groups` only if ambient membership was stored separately; `group-identify` alone does not guarantee this.
- **Feature flags** — some SDKs use group data and group-properties-for-flags caches to reload/evaluate flags after group changes.
- **`reset`** — clears ambient client-side group membership, but does not retract already-sent `$groupidentify` events.

## Requirements

### Requirement: Canonical group-identify behavior

The SDK SHALL implement the canonical `group-identify` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Group identify emits a group profile update event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group identify is called with type "company", key "company-123", and properties:
  | property | value |
  | plan     | pro   |
- **THEN** one event named "$groupidentify" should be enqueued
- **AND** the enqueued event properties should include:
  | property     | value       |
  | $group_type  | company     |
  | $group_key   | company-123 |
  | plan         | pro         |

#### Scenario: Group identify requires type and key (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group identify is called without a group key
- **THEN** no event named "$groupidentify" should be enqueued
- **AND** the SDK should record a validation warning

#### Scenario: Group identify does not replace registered group context (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group identify is called with type "company", key "company-123", and no properties
- **THEN** registered groups should not change
