## Decisions

The server resolves defaults by environment and suite when it first accepts a run. An explicit
override participates in the original creation submission and its replay. The SDK transmits the
selection and consumes the existing lifecycle receipt.

Scorer scope distinguishes item formulas from experiment formulas. Experiment formula inputs
carry an aggregate statistic and version policy. Scorer versions keep formula semantics while
suite defaults can move between versions for new runs.
