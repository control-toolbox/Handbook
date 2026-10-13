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
