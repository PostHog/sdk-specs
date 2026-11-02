## 1. Spec delta

- [x] 1.1 Modify **Canonical identify behavior** in `identify` so client SDKs keep running `identify` while opted out, and add the identify-while-opted-out and same-properties-after-opt-in `@client` scenarios
- [x] 1.2 Add the matching scenarios to `acceptance/public/identify.feature` with existing step text

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 `identify`: remove opt-out from Behavior step 1 guards and describe the opted-out behavior, make the step 3 dedup-hash update conditional on capture, and remove "opted-out user" from the Error handling drop list
- [x] 2.2 `opt-in`: reword `optOut` step 3 and the Interactions entry so opt-out blocks event capture and `identify` still updates local identity and reloads flags

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `openspec archive` to sync the delta into `specs/identify/spec.md` and archive the change
