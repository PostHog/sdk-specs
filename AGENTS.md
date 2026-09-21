# Repository instructions

## Spec changes are not RFCs

This repository records SDK contracts, not proposal-only RFCs. Follow the OpenSpec workflow in [README.md](README.md): propose, apply, and archive each spec change on the same branch and in the same PR.

- Before a spec-change PR merges, sync its delta into `openspec/specs/` and archive its change artifacts under `openspec/changes/archive/YYYY-MM-DD-<change-name>/`.
- Do not merge a proposal-only PR or defer applying and archiving to a follow-up PR. Active change directories are temporary working artifacts, not the final deliverable.
- Keep `proposal.md` and the other OpenSpec artifacts in the archive as the change history; their filenames do not make an archived change an active proposal.
- Archiving here means the spec change is complete. SDK implementation happens in the SDK repositories and is not a prerequisite for archiving the spec change.
- Historical proposal-only PRs (such as #13 and #14, later applied and archived in #21 and #15) are not precedent for the current workflow.
