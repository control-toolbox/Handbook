<!-- markdownlint-disable MD024 -->
# Breaking Changes

This document lists breaking changes to the Handbook: removed or renamed files and
sections, or rule changes that require existing packages to adapt. Each entry comes
with a migration block, as described in
[`CHG3`](rules/changelog.md#chg3--breaking-entries-appear-in-both-files-with-a-migration-block).

## Baseline (0.1.0)

This is the reference version. Breaking changes from this version onward are tracked
here.

Note for packages that referenced the previous layout: the `ai-agents/` directory is
removed (together with the `ai-agent.yml` reusable workflow in `CTActions`). No
migration is required for packages that do not call `ai-agent.yml`.
