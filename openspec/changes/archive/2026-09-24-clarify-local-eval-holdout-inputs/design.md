## Evidence and decisions

Python's `_get_holdout_variant` at commit `9c84daafa5194fe3340b0169452e02adb8801da5` returns None when either `holdout.get("id")` or `holdout.get("exclusion_percentage")` is None. Document the same missing/null exception without defining recovery for other malformed or non-finite inputs.

Keep the exact-zero inclusive comparison in the normative hash requirement. Remove its standalone Gherkin scenario because no concrete identifier fixture is supplied and it requires an injected hash. This does not assert that a zero hash is mathematically impossible.

This follow-up delta supersedes the incomplete-input wording in the original archived change. Its history remains unchanged. Add four concrete missing/null input examples and validate the resulting canonical specification with OpenSpec.
