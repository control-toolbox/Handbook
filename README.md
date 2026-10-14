# ct-conventions

Coding conventions shared by all packages of the
[control-toolbox](https://github.com/control-toolbox) ecosystem: what makes code,
tests, docstrings and documentation **right**, with a stable identifier per rule.

| Repository | Question it answers |
| --- | --- |
| [`CTAppTemplate.jl`](https://github.com/control-toolbox/CTAppTemplate.jl), [`CTActions`](https://github.com/control-toolbox/CTActions) | what is a package built from, how does its CI run? |
| `ct-conventions` (here) | what is right: structure, types, errors, tests, docs? |
| `ct-lint` *(planned)* | does the code follow these rules, and with which guarantee? |
| [`ct-agents`](https://github.com/control-toolbox/ct-agents) | who does what, in which order: agent base, roles, harness adapters |

The rules are written **abstractly**: they apply to every package, and their
examples stay generic (no package-specific symbols).

---

## Reading order

1. **[`rules/general.md`](rules/general.md)** — rules that hold everywhere
   (language, …). **Always read it.**
2. The rule file for the area you work on:

   | File | Prefix | Area |
   | --- | --- | --- |
   | [`rules/modules.md`](rules/modules.md) | `MOD` | submodules, `using`, qualification, exports, DAG |
   | [`rules/types.md`](rules/types.md) | `TYP` | types vs traits, contracts, type stability |
   | [`rules/dimension.md`](rules/dimension.md) | `DIM` | "1-D is a scalar" |
   | [`rules/exceptions.md`](rules/exceptions.md) | `EXC` | the seven exceptions and the choice rule |
   | [`rules/performance.md`](rules/performance.md) | `PERF` | hot path vs setup path, JET, `@inferred`, allocations |
   | [`rules/docstrings.md`](rules/docstrings.md) | `DOC` | docstring templates, cross-references, examples |
   | [`rules/testing.md`](rules/testing.md) | `TST` | test file template, fakes, categories |
   | [`rules/site.md`](rules/site.md) | `SITE` | documentation site, API generation, guides |
   | [`rules/changelog.md`](rules/changelog.md) | `CHG` | `CHANGELOG.md` and `BREAKING.md` |

3. **[`method.md`](method.md)** — how to work: running tests, coverage,
   building the docs, capturing output.
4. **[`plan-template.md`](plan-template.md)** — the implementation plan template.

---

## The principles on one page

1. **One module per responsibility.** Each submodule has a single role, its own
   directory, its own manifest; the package manifest exports nothing.
   → `MOD1`, `MOD2`, `MOD8`
2. **Everything is qualified — with `using`, never `import`.** Bring modules into
   scope, not their symbols; call `Module.symbol` everywhere; extend methods
   qualified (`Base.show(...)`). → `MOD3`–`MOD6`
3. **One abstract type per *noun*, one trait-parameter per *adjective*.** Variants
   are types; orthogonal axes are traits in a type parameter; aliases and `where`
   clauses repeat each named parameter's bound verbatim. → `TYP1`–`TYP3`
4. **Program against abstractions.** Methods live on abstract types; contracts are
   `NotImplemented` stubs; subtypes honor the contract (LSP). → `TYP4`, `TYP5`
5. **SOLID, DRY, KISS, YAGNI.** Single responsibility, open/closed via dispatch,
   no duplication, the simplest thing that works, nothing speculative. These are
   guiding principles, not checkable rules: they have no identifier.
6. **Structured errors.** Seven typed exceptions, picked by a sharp rule.
   → `EXC1`–`EXC5`
7. **Type stability by default — and enforced.** Verified with JET, locked in by
   `@inferred` and allocation guards, on the hot path only. → `TYP8`, `PERF1`–`PERF6`
8. **Everything is documented.** A docstring on every symbol, fixed templates,
   safe examples. → `DOC1`–`DOC8`
9. **Tests: module + callable function + everything qualified.** → `TST1`–`TST7`
10. **Auto-generated API docs, public *and* private; guides separate.**
    → `SITE1`–`SITE14`

---

## Rule identifiers

Every rule has an identifier made of its file's **prefix** and a number: `MOD3`,
`EXC1`, `SITE10`. Cite rules by identifier — in commits, PRs, issues, reviews,
exemptions and agent reports — never by file section or bare number.

Each rule follows the same shape:

```markdown
## MOD3 — No `import`

**Rule.** One or two sentences: what must hold.

**Why.** What breaks otherwise.

✅ / ❌ examples.

**Check.** How the rule is verified.
```

The **Check** line says how far a tool can go:

| Check | Meaning |
| --- | --- |
| `exact` | decidable by a tool, no known false positive or negative |
| `heuristic` | a tool finding is almost always a violation, but the tool misses some |
| `signal` | a tool finding says *where to look*; it is not necessarily a violation |
| `judgment` | not decidable by a tool: a human or a reviewing agent decides |

Until `ct-lint` exists, the Check line states the **target** guarantee
(`to be tooled — exact`), or gives the `grep` command that *measures* the rule
without deciding it.

### Pin the version you apply

A rule identifier is only meaningful with the version of the conventions it comes
from. A review report, a plan or an agent run that applies the conventions states
the version at its top:

```text
Conventions: ct-conventions v0.2.0 (commit 1a2b3c4)
```

```bash
git -C .conventions describe --tags --always
```

---

## Using the conventions in a package

Add the repository as a git submodule, pinned to a release tag:

```bash
git submodule add https://github.com/control-toolbox/ct-conventions.git .conventions
git -C .conventions checkout vX.Y.Z
```

Clone a package with `git clone --recurse-submodules`, or run
`git submodule update --init` in an existing clone. To bump the conventions:

```bash
git -C .conventions fetch --tags && git -C .conventions checkout vX.Y.Z
```

then commit the updated pointer.

---

## Versioning

The conventions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
with tags `vX.Y.Z`. The public interface is the set of **rule identifiers**: what a
commit, a review or an exemption cites.

| | What triggers it |
| --- | --- |
| **major** | an identifier changes meaning: rule renumbered, merged, split or removed |
| **minor** | rule added, tightened or relaxed; identifiers unchanged |
| **patch** | rewording, examples, typos |

While the version is `0.x`, a minor bump may contain breaking changes. Every
breaking change carries its **correspondence table** in
[`BREAKING.md`](BREAKING.md), so that an old citation stays readable.

Earlier states of the repository, under its former name `Handbook`, are tagged
`v2026.04.11`, `v2026.07.27` and `v0.1.0`.

## Releasing

1. Move the `[Unreleased]` entries of [`CHANGELOG.md`](CHANGELOG.md) under a new
   `## [X.Y.Z] - YYYY-MM-DD` heading, and update [`BREAKING.md`](BREAKING.md) if
   needed.
2. Merge the change on `main`.
3. Tag the merge commit: `git tag vX.Y.Z && git push origin vX.Y.Z`, then create a
   GitHub release from the tag.
