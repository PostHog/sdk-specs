## 1. Spec delta

- [x] 1.1 Modify Observer-only instrumentation, Tool call event, Session identity, Arguments the SDK injects, and Optional events so each rule has one home
- [x] 1.2 Add Client conversation ids and Conversation anchoring, split out of Session identity with their scenarios
- [x] 1.3 Rename Virtual tool annotations to Virtual tools and move the virtual tool rules into it

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Terminology: client conversation ids point to their new requirement
- [x] 2.2 Configuration: rows point to their requirement instead of restating behavior
- [x] 2.3 Place the added requirements after Session identity (the archive appends them at the end)

## 3. Validation

- [x] 3.1 Every scenario is unchanged, and every normative sentence that changed still holds elsewhere (script comparing the spec before and after)
- [x] 3.2 Run `openspec validate --specs --strict`
- [x] 3.3 Run `openspec archive` to sync the delta and archive the change
