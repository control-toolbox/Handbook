# control-toolbox Handbook

Design philosophy, operational rules, plan templates and CI/CD conventions shared by all
packages of the [control-toolbox](https://github.com/control-toolbox) ecosystem.

## Contents

| File | Topic |
| --- | --- |
| [`PHILOSOPHY.md`](PHILOSOPHY.md) | Code philosophy (details in [`philosophy/`](philosophy/)) |
| [`RULES.md`](RULES.md) | Operational rules: tests, coverage, docs, git |
| [`PLAN.md`](PLAN.md) | Implementation plan template |
| [`WORKFLOWS.md`](WORKFLOWS.md) | CI/CD workflows and label-gated triggers |
| [`LOCAL-REGISTRY.md`](LOCAL-REGISTRY.md) | `ct-registry` and package releases |
| [`VITEPRESS-DOC.md`](VITEPRESS-DOC.md) | DocumenterVitepress documentation guide |
| [`CHANGELOG.md`](CHANGELOG.md), [`BREAKING.md`](BREAKING.md) | History and breaking changes |

## Using the Handbook in a package

Add it as a git submodule in `.handbook/`, pinned to a release tag:

```bash
git submodule add https://github.com/control-toolbox/Handbook.git .handbook
git -C .handbook checkout vX.Y.Z
```

Clone a package with `git clone --recurse-submodules`, or run
`git submodule update --init` in an existing clone. To bump the Handbook:

```bash
git -C .handbook fetch --tags && git -C .handbook checkout vX.Y.Z
```

then commit the updated pointer.

## Versioning

The Handbook follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html), with
tags `vX.Y.Z`. While the version is `0.x`, a minor bump may contain breaking changes.

- **Major**: rules or conventions that require existing packages to adapt.
- **Minor**: new rules, new sections or files.
- **Patch**: clarifications, typos, fixes.

Earlier states of the repository are tagged by date (`v2026.04.11`, `v2026.07.27`).

## Releasing

1. Move the `[Unreleased]` entries of [`CHANGELOG.md`](CHANGELOG.md) under a new
   `## [X.Y.Z] - YYYY-MM-DD` heading, and update [`BREAKING.md`](BREAKING.md) if needed.
2. Merge the change on `main`.
3. Tag the merge commit: `git tag vX.Y.Z && git push origin vX.Y.Z`, then create a
   GitHub release from the tag.
