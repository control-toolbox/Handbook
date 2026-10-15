# General rules

Rules that hold in every package and every kind of contribution — code, tests,
documentation, and everything written around them. **Read this file in all cases**,
before the file of the area you work on.

Identifiers: `GEN1`, `GEN2`, … (see [`README.md`](../README.md#rule-identifiers)).

---

## GEN1 — English everywhere

**Rule.** Everything written in or for a control-toolbox repository is in English:

- identifiers, code comments, docstrings, error messages;
- test names and `@testset` descriptions;
- documentation pages, guides, READMEs;
- `CHANGELOG.md`, `BREAKING.md`;
- branch names, commit messages, issue and PR titles and bodies, review comments;
- plans, run logs and reports produced by agents.

A conversation with a contributor may be held in any language; what it **produces**
and leaves in the repository or on GitHub is in English.

**Why.** The ecosystem is public and international, and its packages are read
alongside the rest of the Julia ecosystem. One language keeps the corpus searchable,
reviewable by anyone, and consistent across packages — for humans and agents alike.
A mixed-language history (a French commit, an English PR, a French issue) is harder
to follow than either language alone.

✅

```julia
# Reject a negative horizon early: every later step assumes tf > t0.
tf > t0 || throw(Exceptions.IncorrectArgument(
    "final time must exceed initial time";
    got = "tf = $tf", expected = "tf > $t0",
))
```

❌

```julia
# On rejette un horizon négatif : la suite suppose tf > t0.
tf > t0 || throw(Exceptions.IncorrectArgument(
    "le temps final doit dépasser le temps initial";
    got = "tf = $tf", expected = "tf > $t0",
))
```

**Exceptions.**

- Proper nouns and quoted material keep their original spelling (an author's name,
  the title of a cited paper).
- A user-facing tutorial deliberately written in another language is a separate,
  explicitly labelled page; it does not make the rest of the docs bilingual.

**Check.** `signal` — accented letters outside quoted material point at likely
non-English text, but say nothing about unaccented French:

```bash
grep -rnP '[àâçéèêëîïôûùüÿœæ]' --include='*.jl' --include='*.md' src test docs
```

Commits, issues and PRs are reviewed by `judgment`.

---

## GEN2 — One markdownlint configuration in every repository

**Rule.** Every repository has a `.markdownlint.json` at its root with exactly this
content, and no `<!-- markdownlint-disable … -->` comment in its Markdown files:

```json
{
    "MD013": false,
    "MD024": { "siblings_only": true },
    "MD033": false,
    "MD046": false,
    "MD051": false
}
```

Every other markdownlint rule stays on. JSON has no comments, so the reason for each
exception is here, measured on the eight packages (CTBase, CTModels, CTSolvers, CTFlows,
CTDirect, CTParser, CTLie, OptimalControl) with markdownlint's default configuration:

| Rule | What it checks | Why it is off or relaxed | Measured |
| --- | --- | --- | --- |
| `MD013` | line length (80) | tables, URLs and `@ref` links cannot be wrapped, and some pages write one sentence per line; even at 92 columns with tables, code and headings excluded, hundreds of lines remain in each package | 32 to 1 488 hits per package |
| `MD024` | duplicate headings | a changelog repeats `### 🐛 Fixed`, `### 📚 Documentation` in every version; `siblings_only` allows that and still catches a heading repeated under the same parent | replaces the `markdownlint-disable MD024` comment of every `CHANGELOG.md` |
| `MD033` | inline HTML | `README.md` is generated with HTML (logo, badges) and the documentation uses `@raw html` blocks and VitePress components | 76 hits, all in `README.md` |
| `MD046` | code block style | a Documenter admonition (`!!! note`) indents its content by four spaces, which markdownlint reads as an indented code block | up to 158 hits per package, all in admonitions |
| `MD051` | link fragments | Documenter keeps the case of heading anchors (`#In-place-vector-fields`); markdownlint expects them lowercase, so every valid in-page link is reported | 9 hits in CTFlows, all valid links |

**Why.** One configuration means a Markdown file reads the same in every repository and
an editor reports the same problems everywhere. Before this rule, the packages had four
different configurations, or none: a rule switched off in one package for a reason
nobody wrote down stayed on in the next one. Switching a rule off for the whole
ecosystem is a decision recorded here, with its reason; a rule that reports real
problems stays on.

With this configuration, what markdownlint still reports is real (blank lines around
fences and lists, emphasis used as a heading, trailing spaces, missing alt text): fix it
when you touch the file. A large share comes from shared sources — the README template
and the files of `control-toolbox/.github` that the UpdateReadme workflow assembles —
and is fixed there, once.

**Exceptions.** A file that is not rendered by GitHub or Documenter but by another tool
with its own syntax (a JOSS `paper.md` with a Pandoc title block) may be excluded by the
tool that lints it; it does not change `.markdownlint.json`.

**Check.** `exact` (to be tooled): `.markdownlint.json` equals the content above, and no
tracked `.md` file contains `markdownlint-disable`.

```bash
grep -rln 'markdownlint-disable' --include='*.md' . --exclude-dir=.conventions
```
