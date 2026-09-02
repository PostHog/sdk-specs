## 1. Define the crash-containment contract

- [x] 1.1 Add a canonical requirement that replay setup and configuration failures are contained and never throw into host application code.
- [x] 1.2 Add a scenario for an invalid replay configuration.
- [x] 1.3 Add a scenario for an unavailable replay integration.
- [x] 1.4 Add a scenario for a replay integration that fails to initialize.
- [x] 1.5 Add matching public acceptance coverage.

## 2. Publish the canonical specification

- [x] 2.1 Validate the OpenSpec change in strict mode (run post-archive against a scratch copy
      of this change directory: `openspec validate --changes --strict` passes)
- [x] 2.2 Archive the completed change and sync the canonical specification.
- [x] 2.3 Validate all canonical specifications and archived artifacts in strict mode
      (`openspec validate --all --strict --no-interactive`, `@fission-ai/openspec@1.4.1` — the
      package `.github/workflows/openspec.yml` installs: 62/62 items pass)
