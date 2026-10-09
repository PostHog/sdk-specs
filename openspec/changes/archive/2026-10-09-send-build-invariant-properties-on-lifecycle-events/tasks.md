## 1. Spec delta

- [x] 1.1 Add one requirement to `application-lifecycle`, **Build-invariant context properties**
- [x] 1.2 State that such properties ride `Application Installed` / `Application Updated` and are not added to the common event context
- [x] 1.3 Carve out `$lib`, `$lib_version`, `$app_version` and `$app_build`
- [x] 1.4 State that the property is omitted when the platform reports no value, and not sent at all where there are no lifecycle events
- [x] 1.5 Note the rule in the install/update step of the Behavior section

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and compare against `main`
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/application-lifecycle/spec.md` and archive the change
