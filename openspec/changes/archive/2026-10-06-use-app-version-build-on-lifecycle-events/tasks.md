## 1. Spec delta

- [x] 1.1 Modify exactly one requirement in `application-lifecycle`, **Canonical application-lifecycle behavior**, as a full copied-and-edited block
- [x] 1.2 State that the current version and build come from `$app_version` / `$app_build`, and that un-prefixed `version` / `build` SHOULD NOT be added
- [x] 1.3 Allow SDKs that send `version` / `build` today to keep them until their next major
- [x] 1.4 Update the **Version change captures an update event** scenario
- [x] 1.5 Update the install/update and open steps in the Behavior section to match
- [x] 1.6 Update `acceptance/private/application-lifecycle.feature` to match the scenario

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/application-lifecycle/spec.md` and archive the change
