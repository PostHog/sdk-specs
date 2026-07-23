## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/is-feature-enabled/spec.md` modifies the single `Canonical is-feature-enabled behavior` requirement as a full copied-and-edited block
- [x] 1.2 Verify the requirement prose adds the caller-supplied default contract (applies to any no-value case; flag value always wins) and names the three-state no-default variation for the posthog-js family
- [x] 1.3 Verify the missing-flag scenario is re-anchored on the default value and the two new scenarios (default `true` for missing flag; flag value beats caller default) are present
- [x] 1.4 Verify the value-mapping and tracking-suppression scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add `defaultValue?: boolean` to the client-side canonical signature options in `openspec/specs/is-feature-enabled/spec.md`
- [x] 2.2 Update the surface-variants list: `isFeatureEnabled(key, { defaultValue })` uniformly for posthog-js, posthog-js-lite, and react-native
- [x] 2.3 Update the client/server comparison table "Unknown flag behavior" row and the client/server behavior-flow bullets to mention the caller-supplied default
- [x] 2.4 Reword the client-side flow step 2 "SDKs vary between returning `undefined` and falling back to `false` / a supplied default" to reference the named variation in the requirement

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into `specs/is-feature-enabled/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Per-platform port changes pick up the two new scenarios in the acceptance harness once implementations ship (posthog-js family already shipped in PostHog/posthog-js#4222; Android/Unity/iOS/Flutter conform by construction)
