<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to the control-toolbox Handbook will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 📚 Documentation

- [`VITEPRESS-DOC.md`](VITEPRESS-DOC.md): new note on packages without a logo or favicon —
  delete the two `REPLACE_ME_DOCUMENTER_VITEPRESS` placeholders (`logo:` and the `icon`
  link) from `config.mts` to silence the DocumenterVitepress warnings; the output is
  unchanged.

### ✅ Compatibility

- **No breaking changes**: a recommendation for new and existing packages; nothing to
  migrate.

## [0.1.0] - 2026-10-13 — baseline

This is the reference version. No changelog was maintained before this point;
use `git log` for earlier history (earlier states are tagged `v2026.04.11` and
`v2026.07.27`). Breaking changes from this version onward are tracked in
[BREAKING.md](BREAKING.md).

### 📚 Documentation

- Code philosophy ([`PHILOSOPHY.md`](PHILOSOPHY.md) and [`philosophy/`](philosophy/)),
  operational rules ([`RULES.md`](RULES.md)), plan template ([`PLAN.md`](PLAN.md)),
  CI/CD workflows ([`WORKFLOWS.md`](WORKFLOWS.md)), local registry guide
  ([`LOCAL-REGISTRY.md`](LOCAL-REGISTRY.md)) and VitePress documentation guide
  ([`VITEPRESS-DOC.md`](VITEPRESS-DOC.md)).
- The experimental `ai-agents/` directory and its workflow documentation are removed.

### ✅ Compatibility

- **No breaking changes**: baseline release. See [BREAKING.md](BREAKING.md).
