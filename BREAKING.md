<!-- markdownlint-disable MD024 -->
# Breaking Changes

This document lists breaking changes to ct-conventions (formerly the Handbook): removed or renamed files and
sections, or rule changes that require existing packages to adapt. Each entry comes
with a migration block, as described in
[`CHG3`](rules/changelog.md#chg3--breaking-entries-appear-in-both-files-with-a-migration-block).

## Version 0.2.0 — the Handbook becomes ct-conventions

- **Rules carry identifiers** and live in `rules/`; cite them by identifier
  (`MOD3`, not "modules.md, `using` never `import`").
- **Files moved out**: workflows to CTActions, the release guide to ct-registry, agent
  material and the VitePress migration recipe to ct-agents.
- **Repository renamed** `Handbook` → `ct-conventions`; GitHub redirects the old URL.

**Migration** (in each package):

```bash
# Before
git submodule add https://github.com/control-toolbox/Handbook.git .handbook

# After
git submodule add https://github.com/control-toolbox/ct-conventions.git .conventions
git -C .conventions checkout vX.Y.Z
```

```markdown
<!-- Before (AGENTS.md, comments, docs) -->
[`PHILOSOPHY.md`](https://raw.githubusercontent.com/control-toolbox/Handbook/refs/heads/main/PHILOSOPHY.md)
See Handbook/VITEPRESS-DOC.md "Plot image format — SVG vs PNG".

<!-- After -->
[`ct-conventions`](.conventions/README.md) — rules cited by identifier
See ct-conventions SITE12 (plots are rendered as SVG).
```

`PHILOSOPHY.md`, `RULES.md`, `PLAN.md`, `WORKFLOWS.md` and `VITEPRESS-DOC.md` remain as
redirects until the next release.

### Correspondence table

| Former location | Now |
| --- | --- |
| `PHILOSOPHY.md` | `README.md` — principles on one page |
| `philosophy/modules.md` — principles 1–7 | `MOD1`, `MOD8`, `MOD8`, `MOD3`, `MOD4`, `MOD6`, `MOD7` |
| `philosophy/modules.md` — `using`, never `import` | `MOD3` |
| `philosophy/modules.md` — The submodule manifest | `MOD2` |
| `philosophy/modules.md` — `using` styles | `MOD4` |
| `philosophy/modules.md` — Sibling imports | `MOD5` |
| `philosophy/modules.md` — Qualification at call sites | `MOD6` |
| `philosophy/modules.md` — Dependency DAG | `MOD7` |
| `philosophy/modules.md` — Two-level exports | `MOD8` |
| `philosophy/modules.md` — Naming conventions | `MOD9` |
| `philosophy/types-traits-interfaces.md` — The guiding rule; When an axis becomes a type parameter | `TYP1` |
| `philosophy/types-traits-interfaces.md` — Traits as type parameters; Dispatch via the trait | `TYP2` |
| `philosophy/types-traits-interfaces.md` — Aliases and `where`; Auditing a package | `TYP3` |
| `philosophy/types-traits-interfaces.md` — Interfaces and contracts | `TYP4` (stubs), `TYP5` (abstractions, LSP), `TYP6` (no capability type) |
| `philosophy/types-traits-interfaces.md` — When concrete types are justified | `TYP7` |
| `philosophy/types-traits-interfaces.md` — Type stability | `TYP8` |
| `philosophy/types-traits-interfaces.md` — SOLID / DRY / KISS / YAGNI | `rules/types.md` — guiding principles, no identifier |
| `philosophy/dimension-and-shape.md` — The rule; Why | `DIM1` |
| `philosophy/dimension-and-shape.md` — The in-place buffer is the exception | `DIM2` |
| `philosophy/dimension-and-shape.md` — Boundary rules | `DIM3` (callers, storage), `DIM4` (coercion) |
| `philosophy/dimension-and-shape.md` — Testing the convention | `DIM5` |
| `philosophy/exceptions.md` — The seven types; The choice rule; Anti-patterns | `EXC1` |
| `philosophy/exceptions.md` — principles 1–3 (message, suggestion, context) | `EXC2`, `EXC3` |
| `philosophy/exceptions.md` — the fields note | `EXC4` |
| `philosophy/exceptions.md` — Testing exceptions | `EXC5` |
| `philosophy/performance.md` — hot path vs. setup path | `PERF1` |
| `philosophy/performance.md` — Order of operations; JET analyzers | `PERF2` |
| `philosophy/performance.md` — JET setup; False positives; Benign collector noise | `PERF3`, `PERF6` (dependencies) |
| `philosophy/performance.md` — Stability guards | `PERF4` |
| `philosophy/performance.md` — Allocation guards | `PERF5` |
| `philosophy/docstrings.md` — Principles; placement; Macros | `DOC1`, `DOC8` (accuracy) |
| `philosophy/docstrings.md` — Required structure; Templates | `DOC2` |
| `philosophy/docstrings.md` — Example safety | `DOC3` |
| `philosophy/docstrings.md` — Cross-references | `DOC4` |
| `philosophy/docstrings.md` — Self-reference for extensible generics | `DOC5` |
| `philosophy/docstrings.md` — Functor call operators | `DOC6` |
| `philosophy/docstrings.md` — Module-prefix convention in examples | `DOC7` |
| `philosophy/testing.md` — The file template; principle 2 (orthogonality) | `TST1` |
| `philosophy/testing.md` — qualified imports; critical rule 2 | `TST2` |
| `philosophy/testing.md` — fakes/stubs; critical rule 1 | `TST3` |
| `philosophy/testing.md` — Test categories; critical rule 3 (exports) | `TST4` |
| `philosophy/testing.md` — Error | `TST5` |
| `philosophy/testing.md` — Capability-gated tests | `TST6` |
| `philosophy/testing.md` — critical rules 4–5; Quality | `TST7` |
| `philosophy/documentation.md` — principle 1 | `SITE1` |
| `philosophy/documentation.md` — principle 2; API generation pattern | `SITE2`, `SITE3` (extensions) |
| `philosophy/documentation.md` — principle 5; Cross-reference infrastructure; Local fallback | `SITE4` |
| `philosophy/documentation.md` — Self-reference for extensible generics | `SITE5` |
| `philosophy/documentation.md` — principle 3 | `SITE6` |
| `philosophy/documentation.md` — Submodule imports in guides | `SITE7` |
| `philosophy/documentation.md` — principle 4; Index page | `SITE8` |
| `philosophy/documentation.md` — Code cell line width | `SITE9` |
| `philosophy/documentation.md` — The draft switch | `method.md` §3 |
| `philosophy/changelog.md` — Two-file convention | `CHG1` |
| `philosophy/changelog.md` — CHANGELOG.md format; Section taxonomy | `CHG2` |
| `philosophy/changelog.md` — Breaking entries | `CHG3` |
| `philosophy/changelog.md` — Non-breaking notes | `CHG4` |
| `philosophy/changelog.md` — Retroactive bootstrap | `CHG5` |
| `VITEPRESS-DOC.md` — Canonical api_reference.jl structure | dropped; `SITE10` keeps explicit `ext_dir` and cleanup |
| `VITEPRESS-DOC.md` — Presenting code | `SITE11` |
| `VITEPRESS-DOC.md` — Plot image format — SVG vs PNG | `SITE12` |
| `VITEPRESS-DOC.md` — Deployment (stable tags, `bases.txt` guard) | `SITE13` |
| `VITEPRESS-DOC.md` — other important notes | `rules/site.md` — notes on the VitePress backend |
| `VITEPRESS-DOC.md` — Migration steps | `ct-agents/recipes/vitepress-migration.md` |
| `RULES.md` §1–3, §6 | `method.md` §1–4 |
| `RULES.md` §1 (`Monitor`), §5 (dedicated tools) | `ct-agents/adapters/claude-code.md` |
| `RULES.md` §4, §5, §7 | `ct-agents/base.md` |
| `RULES.md` §8 | `ct-agents/setup/github-pat.md` |
| `PLAN.md` | `plan-template.md` |
| `WORKFLOWS.md` | `CTActions/docs/WORKFLOWS.md` |
| `LOCAL-REGISTRY.md` | `ct-registry/RELEASING.md` |

## Baseline (0.1.0)

This is the reference version. Breaking changes from this version onward are tracked
here.

Note for packages that referenced the previous layout: the `ai-agents/` directory is
removed (together with the `ai-agent.yml` reusable workflow in `CTActions`). No
migration is required for packages that do not call `ai-agent.yml`.
