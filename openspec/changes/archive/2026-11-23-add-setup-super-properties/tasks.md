## 1. Spec delta

- [x] 1.1 Add **Super properties at setup** to `setup` covering canonical option naming, legacy alias policy, client `register()` store seeding before bootstrap and lifecycle hooks, server init-time attachment, and caller-wins precedence
- [x] 1.2 Add **Setup-seeded super properties share the register store** to `register`
- [x] 1.3 Add **Startup lifecycle events carry setup super properties** to `application-lifecycle`

## 2. Acceptance features

- [x] 2.1 Add declarative setup super-properties scenarios to `acceptance/public/setup.feature`
- [x] 2.2 Add setup-seeded `register` / `unregister` / `reset` scenario to `acceptance/public/register.feature`
- [x] 2.3 Add first-launch and update lifecycle super-properties scenarios to `acceptance/private/application-lifecycle.feature`

## 3. Validation and archive

- [x] 3.1 Run `openspec validate --strict`
- [x] 3.2 Sync deltas into `openspec/specs/` and archive the change
