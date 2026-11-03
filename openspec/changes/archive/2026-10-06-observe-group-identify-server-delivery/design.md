## Context

Server identify and alias acceptance cases already call public SDK methods, flush, and inspect isolated receiver traffic. Group identify can use the same path. The existing group-identify happy-path assertion instead places `plan` at the event-property root, contrary to the SDK implementations and ingestion.

This is a canonical specification correction to the supplied-property assertion. Node, Python, Ruby, Go, PHP, .NET, Java, Rust, and the inspected JS clients already nest supplied properties under `$group_set`; none needs a production change for that correction. Ingestion accepts missing or null `$group_set` and supplies an empty property update internally.

## Goals / Non-Goals

**Goals:**

- Check received `$groupidentify` events, group type and key, explicit distinct ID, and exact supplied JSON group properties.
- Exercise scalar and nested values, including false, zero, null, and reserved-looking property names.
- Check that a call with omitted properties still delivers the group identity.
- Preserve existing client-state and invalid-input scenarios.

**Non-Goals:**

- SDK implementation changes, client group-context migration, or invalid-input standardization.
- Private queue, clock, or storage controls for the server delivery cases.
- Harness publication or CI image-pin updates in the initial coverage changes.

## Decisions

### Use the existing acceptance feature

Add an opted-in server outline with scalar and nested examples and a separate no-properties delivery scenario. Give the preserved legacy scenarios their own setup rather than inheriting a feature-wide Background. Correct the existing happy-path `plan` assertion to `$group_set.plan` without changing its client applicability.

### Translate one public operation

The harness invokes `/group_identify` with `group_type`, `group_key`, `properties`, `distinct_id`, and optional `disable_geoip`. The Node adapter renames those fields to the public `groupIdentify` object parameter. It preserves omission and literal JSON values and returns the native completion. It does not build capture events or perform an implicit flush.

### Observe delivery through existing receiver assertions

Reuse request count, parsed-event count, root-field, and exact JSON property assertions. Each scenario allocates an isolated receiver and flushes through the public API. The no-properties scenario checks delivery and identity; its wire representation is SDK-specific.

### Validate before rollout

Controlled hosts verify selection, route gaps, argument preservation, unexpected throws, and rejection of defective wire output. A source-built Node consumer verifies real HTTP delivery in CJS/ESM and v0/v1. The existing tag-selected acceptance CI discovers these cases after a released harness bundles the reviewed specs and its pin is updated separately.

## Risks / Trade-offs

- [A healthy controlled host could conceal an adapter defect] → Test the real installed SDK package and retain raw reports for both Node profiles.
- [An assertion could accept false/zero confusion or a flattened property map] → Inject typed-value and property-placement defects and require attributed failures.
- [Legacy client/invalid-input scenarios could be lost during setup changes] → Compare inventories and preserve their names and applicability.
- [The released harness does not yet contain the new cases] → Keep publication and image-pin rollout as a separate gate.

## Migration Plan

Review and merge the specs and harness coverage changes, publish a harness release that contains both, then update Node's harness pin through the existing rollout workflow. No SDK data or persistence migration is needed.

## Open Questions

None for the local coverage implementation. Publishing, pinning, and merging remain separately authorized actions.
