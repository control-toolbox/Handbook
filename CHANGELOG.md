# Changelog

All notable changes to ct-conventions (formerly the control-toolbox Handbook) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ New Features

- `SITE15`: an error raised because an extension is not loaded is shown from a fresh
  Julia process (`NoExt.repl`), never from `@repl` (the build loads every extension) nor
  as hand-written output; the build fails if the example no longer throws.
- `SITE16`: warnings shown in `@example` blocks carry no build-machine path
  (`DocLogs.run`).
- `SITE17`: a GPU page runs on every build, its device blocks guarded by
  `CUDA.functional()`, with a note that the output depends on the machine; the GPU pass
  of CTActions (`gpu_runner`) republishes it with device output.

### 🛠 Enhancements

- `SITE13` tightened to what the packages do: PR previews are deployed only with the
  `documentation push preview` label (`push_preview` read from
  `DOCUMENTER_PUSH_PREVIEW`), removed when the PR is closed (`DocPreviewCleanup.yml`),
  and `opened` is no longer in the PR `types`. The example showed a hardcoded
  `push_preview=true` and `opened`.

### 📚 Documentation

- Notes on the VitePress backend: tables are right-aligned unless the separator row
  says otherwise; an `@example` block that returns a value does not show what it
  printed.

## [0.4.0] - 2026-10-15

### ✨ New Features

- `GEN2`: one `.markdownlint.json` in every repository, with the reason for each rule
  switched off (`MD013`, `MD033`, `MD046`, `MD051`) or relaxed (`MD024`, siblings only),
  measured on the eight packages. Replaces the `markdownlint-disable MD024` comments of
  the changelogs.

### 🔧 Internal

- `CHG2`: the `CHANGELOG.md` header no longer starts with
  `<!-- markdownlint-disable MD024 -->`; `.markdownlint.json` relaxes `MD024` instead
  (`GEN2`).
- This repository follows `GEN2` (`.markdownlint.json` added, comments removed).

## [0.3.1] - 2026-10-14

### 📚 Documentation

- A package no longer vendors the conventions as a git submodule: `Pkg.add` cannot
  install a package that contains one on Julia 1.10, which blocked a registration of
  CTBase. It pins a tag in `AGENTS.md` and reads a git-ignored clone in `.conventions/`
  ([Using the conventions in a package](README.md#using-the-conventions-in-a-package)).

### 🔧 Internal

- Releases are automatic: merging a release PR (a new `## [X.Y.Z]` section in this
  changelog) tags the merge commit and creates the GitHub release.

## [0.3.0] - 2026-10-14

### ✨ New Features

- `SITE14`: dependencies in `docs/package.json` are pinned to exact versions. A caret
  range let `@nolebase/vitepress-plugin-enhanced-readabilities@2.21.x` (peer
  `vitepress@^2`) break `npm install` in every package's documentation build.

## [0.2.0] - 2026-10-13

The Handbook becomes **ct-conventions**: coding conventions only, one identifier per
rule. Everything else moves to the repository it describes.

### 💥 Breaking Changes

#### Rules carry identifiers; `philosophy/` becomes `rules/`

- Every rule now has a stable identifier (`MOD3`, `EXC1`, `SITE12`, …), a **Why**
  paragraph and a **Check** line stating how far a tool can verify it (`exact`,
  `heuristic`, `signal`, `judgment`). Cite rules by identifier from now on.
- `philosophy/*.md` move to `rules/*.md`: `modules.md` (`MOD`), `types.md` (`TYP`, was
  `types-traits-interfaces.md`), `dimension.md` (`DIM`, was `dimension-and-shape.md`),
  `exceptions.md` (`EXC`), `performance.md` (`PERF`), `docstrings.md` (`DOC`),
  `testing.md` (`TST`), `site.md` (`SITE`, was `documentation.md`), `changelog.md`
  (`CHG`).
- The meaning of the rules is unchanged, with the exceptions listed under 🐛 and ✨.

#### Files moved out of the repository

- `PHILOSOPHY.md` → the principles on one page in [`README.md`](README.md).
- `RULES.md` → [`method.md`](method.md) for procedures; agent behavior to
  [`ct-agents`](https://github.com/control-toolbox/ct-agents).
- `PLAN.md` → [`plan-template.md`](plan-template.md).
- `WORKFLOWS.md` → `CTActions/docs/WORKFLOWS.md`.
- `LOCAL-REGISTRY.md` → `ct-registry/RELEASING.md`.
- `VITEPRESS-DOC.md` → rules `SITE10`–`SITE13` and backend notes in
  [`rules/site.md`](rules/site.md); migration recipe to `ct-agents`.

`PHILOSOPHY.md`, `RULES.md`, `PLAN.md`, `WORKFLOWS.md` and `VITEPRESS-DOC.md` remain as
redirects until the next release. The full correspondence table is in
[BREAKING.md](BREAKING.md).

### ✨ New Features

- [`GEN1`](rules/general.md#gen1--english-everywhere) — English everywhere: code,
  docs, commits, issues, PRs, plans and agent reports. The only new rule.
- `SITE10`–`SITE13` — conventions that lived in the VitePress migration guide become
  rules: explicit `ext_dir` and cleanup in `with_api_reference`, code annotations,
  plots as SVG, stable-tag deployment with a guarded `deploydocs`.
- The README states how to pin the conventions version in plans, reviews and agent
  reports, and versions the repository on rule identifiers.

### 🐛 Bug Fixes

- `TYP3`: the wrong and right `where` examples were identical; the wrong one now names
  `TD` without its bound, as its comment says.
- `SITE12`: the SVG example used `import CairoMakie`, contradicting `MOD3`; it now uses
  `using CairoMakie: CairoMakie`, which avoids the same name collision.
- The "Canonical api_reference.jl structure" section of the VitePress guide (one page
  per module, no Internals page) is dropped: no package follows it, and it contradicted
  the pattern in force, now `SITE2`.
- `plan-template.md` branches off `main` (not `develop`) and uses plain `git` instead
  of harness-specific tools.

### 📚 Documentation

- The VitePress guide gains a note on packages without a logo or favicon — delete the
  two `REPLACE_ME_DOCUMENTER_VITEPRESS` placeholders from `config.mts` to silence the
  DocumenterVitepress warnings; the output is unchanged. Now in the backend notes of
  [`rules/site.md`](rules/site.md).

### ✅ Compatibility

- **Breaking**: files renamed, moved or removed, and rules now cited by identifier.
  See [BREAKING.md](BREAKING.md) for the correspondence table and the migration.

## [0.1.0] - 2026-10-13 — baseline

This is the reference version. No changelog was maintained before this point;
use `git log` for earlier history (earlier states are tagged `v2026.04.11` and
`v2026.07.27`). Breaking changes from this version onward are tracked in
[BREAKING.md](BREAKING.md).

### 📚 Documentation

- Code philosophy ([`PHILOSOPHY.md`](PHILOSOPHY.md) and `philosophy/`),
  operational rules ([`RULES.md`](RULES.md)), plan template ([`PLAN.md`](PLAN.md)),
  CI/CD workflows ([`WORKFLOWS.md`](WORKFLOWS.md)), local registry guide
  (`LOCAL-REGISTRY.md`) and VitePress documentation guide
  ([`VITEPRESS-DOC.md`](VITEPRESS-DOC.md)).
- The experimental `ai-agents/` directory and its workflow documentation are removed.

### ✅ Compatibility

- **No breaking changes**: baseline release. See [BREAKING.md](BREAKING.md).
