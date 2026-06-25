# GitHub workflows — the control-toolbox philosophy

How the control-toolbox organization manages GitHub Actions across all its
repositories. Read this **before creating a new repo**, before adding or editing a
workflow, or when wondering why a given workflow is (or is not) present in a given
package.

The companion of this file in practice is the **[`CTActions`](https://github.com/control-toolbox/CTActions)**
repository (the central workflow library) and the **[`CTAppTemplate.jl`](https://github.com/control-toolbox/CTAppTemplate.jl)**
repository (the bootstrap template for a new package).

---

## 1. The core idea: centralize, then call

A control-toolbox repository **does not define its CI logic**. The logic lives **once**
in `CTActions`, as a set of **reusable workflows** (`on: workflow_call`). Every package
ships only a thin **caller** that delegates to `CTActions`:

```yaml
# .github/workflows/CI.yml  — in any package
jobs:
  call:
    uses: control-toolbox/CTActions/.github/workflows/ci.yml@main
    with:
      runs_on: '["ubuntu-latest", "macos-latest"]'
      use_ct_registry: true
    secrets:
      SSH_KEY: ${{ secrets.SSH_KEY }}
```

Why this design:

- **Single source of truth.** Fixing a CI bug or bumping an action version is done
  once in `CTActions`; every repo picks it up on its next run (callers pin `@main`).
- **Thin, declarative callers.** A package's workflow file only says *which* shared
  workflow to call, on *which events*, with *which inputs/secrets*. No step logic.
- **Consistency.** All packages test, build docs, format, and spell-check the same way.
- **Easy onboarding.** A new repo copies the caller files from the template; it
  inherits the whole pipeline for free.

### Naming convention

| Layer | Location | Filename style | Example |
| --- | --- | --- | --- |
| **Reusable** (the logic) | `CTActions/.github/workflows/` | `kebab-case.yml` | `ci.yml` |
| **Caller** (the trigger) | `<package>/.github/workflows/` | `PascalCase.yml` | `CI.yml` |

Callers always reference the reusable workflow by its full path **pinned to `@main`**:
`control-toolbox/CTActions/.github/workflows/<name>.yml@main`.

---

## 2. The second idea: label-gated triggers (`run …`)

Running the full matrix (CI on several OSes, breakage against every downstream package,
a Documenter build) on **every push to every PR** is slow and wasteful. So expensive
workflows are **opt-in per pull request via a label**. The caller guards its job with:

```yaml
jobs:
  call:
    if: github.event_name != 'pull_request' || contains(github.event.pull_request.labels.*.name, 'run ci')
    uses: control-toolbox/CTActions/.github/workflows/ci.yml@main
```

Read this `if` as: **always run on `push`/`tag`** (the `main` branch must stay green),
but **on a pull request, only run when the `run ci` label is present.** You add the
label to a PR when you want that check; you remove/re-add it to re-trigger (the caller
also listens to the `labeled` event).

### The `run …` labels

| Label | Triggers | Used in |
| --- | --- | --- |
| `run ci` | CI test matrix | most packages |
| `run ci cpu` | CI on GitHub-hosted CPU runners | OptimalControl (split CI) |
| `run ci gpu` | CI on self-hosted GPU runner | OptimalControl (split CI) |
| `run GPU` | dedicated GPU test job | CTDirect |
| `run breakage` | breakage tests against downstream **packages** | core packages |
| `run breakage applications` | breakage against downstream **applications/tutorials** | OptimalControl |
| `run documentation` | full Documenter build on the PR | most packages |

Labels are defined per-repo (GitHub repository labels). When you bootstrap a new repo,
create the labels you intend to use (`gh label create "run ci" --color 78f620
--description "Trigger CI"`, etc.). Workflows that are **not** PR-gated (scheduled or
push-only) need no label.

---

## 3. The catalog of workflows

Two families: **reusable workflows** (defined in `CTActions`, called by packages) and a
few **non-centralized / special** workflows (defined directly in a package).

### 3.1 Reusable workflows (in `CTActions`)

| Reusable (`CTActions`) | Caller name | Role | Typical trigger | Key inputs / secrets | PR label gate |
| --- | --- | --- | --- | --- | --- |
| `ci.yml` | `CI.yml` | Build + run the test suite over a Julia × OS × arch matrix | `push`, `tag`, PR | `versions`, `runs_on`, `archs`, `runner_type`, `use_ct_registry`; `SSH_KEY` | `run ci` |
| `coverage.yml` | `Coverage.yml` | Run tests with coverage, upload to Codecov | `push`/`tag` to `main` | `use_ct_registry`; `codecov-secret`, `SSH_KEY` | — (push only) |
| `documentation.yml` | `Documentation.yml` | Build & deploy the Documenter site | `push`, `tag`, PR | `use_ct_registry`; `SSH_KEY`, `DOCUMENTER_KEY` | `run documentation` |
| `breakage.yml` | `Breakage.yml` | Test that a change doesn't break downstream packages/apps (`latest`/`stable`); comment a result table on the PR | PR (labeled) | `pkgname`, `pkgpath`, `pkgversion`, `pkgbreak` (`test`/`doc`), `use_ct_registry`; `SSH_KEY` | `run breakage` |
| `formatter.yml` | `Formatter.yml` | Run JuliaFormatter (BlueStyle), open an auto PR | scheduled (nightly), `workflow_dispatch` | — | — |
| `spell-check.yml` | `SpellCheck.yml` | Spell-check with `crate-ci/typos` | PR, `workflow_dispatch` | `locale`, `extend-identifiers`, `config-path` | — |
| `compat-helper.yml` | `CompatHelper.yml` | Open PRs bumping `[compat]` bounds | scheduled (daily), `workflow_dispatch` | `subdirs`; `GITHUB_TOKEN`, `DOCUMENTER_KEY` | — |
| `update-readme.yml` | `UpdateReadme.yml` | Regenerate `README.md` from a template + the org's central `ABOUT/INSTALL/CONTRIBUTING.md` + badges | scheduled (weekly), `workflow_dispatch` | `template_file`, `output_file`, `package_name`, `repo_name`, `doc_url`, `citation_badge`, `assignee` | — |
| `auto-assign.yml` | `AutoAssign.yml` | Auto-assign new issues/PRs to a maintainer | issue/PR opened | `assignees`, `numOfAssignee` | — |
| `add-to-project.yml` | `AddToProject.yml` | Add new issues/PRs to the org project board (set Status) | issue/PR opened | `project-url`, `status`; `project_token` | — |

### 3.2 Maintenance workflows that live *in* `CTActions` (not called)

These run on `CTActions` itself, on a schedule, to keep the **self-hosted runners**
healthy. They are not `workflow_call` reusables.

| Workflow (`CTActions`) | Role | Trigger |
| --- | --- | --- |
| `occidata-runner-maintenance.yml` | Purge Julia compile cache, update TeXLive, rotate logs on the `occidata` self-hosted runner | weekly cron, `workflow_dispatch` |
| `remove-julia.yml` | Wipe stale Julia installs on a self-hosted runner | weekly cron, `workflow_dispatch` |

### 3.3 Non-centralized / per-repo special workflows

| Workflow | Where | Why it isn't centralized |
| --- | --- | --- |
| `TagBot.yml` | every package | Thin wrapper over `JuliaRegistries/TagBot@v1`; standard upstream action, no shared logic to factor. Triggered by `issue_comment` from `JuliaTagBot` (registration) or `workflow_dispatch`. |
| `setup-repo.yml` | **CTAppTemplate only** | One-shot bootstrap: renames the package, regenerates the UUID, sets authors/assignees, opens a setup PR. Meaningful only on a fresh clone of the template. |
| `JOSS.yml` | **OptimalControl only** | Compiles the JOSS paper under `joss/`. Specific to the package that has a paper. |
| `GPU.yml` | **CTDirect only** | Dedicated GPU test job on a self-hosted GPU runner, gated by `run GPU`. |
| `benchmark-reusable.yml`, `benchmarks-orchestrator.yml` | **CTBenchmarks.jl only** | Benchmark orchestration specific to the benchmarking repo. |

---

## 4. Which repo has which workflow — and why

Not every package carries every workflow. The base set (CI, Coverage, Documentation,
Formatter, SpellCheck, CompatHelper, UpdateReadme, AutoAssign, TagBot) is **universal**.
Two workflows are **conditional**: `Breakage` and `AddToProject`.

| Repo | Base set | Breakage | AddToProject | Extra |
| --- | :---: | :---: | :---: | --- |
| CTAppTemplate.jl | ✅ | — | — | `setup-repo` |
| CTBase | ✅ | ✅ | ✅ | — |
| CTModels.jl | ✅ | ✅ | ✅ | — |
| CTParser.jl | ✅ | ✅ | ✅ | — |
| CTFlows.jl | ✅ | ✅ | — | — |
| CTDirect.jl | ✅ | ✅ | ✅ | `GPU`, `Formatter` disabled |
| CTSolvers | ✅ | ✅ | ✅ | — |
| OptimalControl | ✅ | ✅ | ✅ | `JOSS`, split CI (cpu/gpu) |
| OptimalControlProblems | ✅ | — | — | — |
| CTDiffFlow.jl | ✅ | — | — | — |
| CTBenchmarks.jl | ✅ | — | — | `benchmark-*` |

**Why `Breakage` is present only in some repos.** Breakage answers: *"if I change this
package, do its downstream consumers still build/test?"* It only makes sense for a
package that **has downstream consumers inside the ecosystem**.

- A **foundation** package (`CTBase`) is depended on by everything, so its breakage
  matrix lists all the packages below it (`CTDirect`, `CTFlows`, `CTModels`, `CTParser`,
  `CTSolvers`, `OptimalControl`).
- An **umbrella** package (`OptimalControl`) sits on top, so its breakage matrix tests
  downstream **applications and tutorials** (hence the extra `run breakage
  applications` label and the `pkgbreak: doc` variant that builds their docs).
- A **peripheral / leaf** repo with no internal dependents (`CTDiffFlow`,
  `CTBenchmarks`, `OptimalControlProblems`, the template) has nothing to break, so it
  carries no `Breakage`.

**Why `AddToProject` is present only in some repos.** It wires issues/PRs into the
organization's project board. It is enabled on the actively-managed core packages and
omitted from peripheral repos and the template.

**Why `Formatter` is disabled in CTDirect** (`Formatter.yml.disabled`). The caller is
kept on disk but the `.disabled` suffix makes GitHub ignore it — a per-repo opt-out
without deleting the file. (Rename back to `Formatter.yml` to re-enable.)

**Why the template's CI has no label gate.** `CTAppTemplate.jl/CI.yml` calls `ci.yml`
with no `if:` and minimal inputs — the template favors a simple "runs on every PR"
default; real packages then tighten it with the `run ci` label and richer inputs.

---

## 5. Cross-cutting concepts

### The `ct-registry` and `SSH_KEY`

Several packages depend on **unregistered** ecosystem packages hosted in the private
[`control-toolbox/ct-registry`](https://github.com/control-toolbox/ct-registry). When a
workflow needs them, the caller passes `use_ct_registry: true` **and** the `SSH_KEY`
secret; the reusable workflow then runs `julia-actions/add-julia-registry` before
building. Set `use_ct_registry: false` for packages that only need the General registry
(e.g. `OptimalControl`'s CI sets it `false`; `CTBase`'s sets it `true`).

> Note: on Windows runners the registry step is skipped (SSH-key registry add is not
> wired there); keep that in mind when choosing `runs_on`.

### GitHub-hosted vs self-hosted runners

`ci.yml` accepts `runner_type: github | self-hosted` and a `runs_on` value (a single
label string or a JSON array of labels). GitHub-hosted runners use
`julia-actions/cache`; self-hosted runners use manual artifact/compiled-code caches.
OptimalControl demonstrates the split: a `github` CPU job (`run ci cpu`) and a
`self-hosted` GPU job on the `kkt` runner (`run ci gpu`). The self-hosted runners are
the ones maintained by the scheduled `CTActions` maintenance workflows (§3.2).

### Secrets used across the pipeline

| Secret | Used by | Purpose |
| --- | --- | --- |
| `SSH_KEY` | CI, Coverage, Documentation, Breakage | Add the private `ct-registry` |
| `DOCUMENTER_KEY` | Documentation, CompatHelper, TagBot | Deploy docs / sign tags (Documenter deploy key) |
| `CODECOV_TOKEN` → `codecov-secret` | Coverage | Upload coverage to Codecov |
| `PROJECT_TOKEN` → `project_token` | AddToProject | Write to the org project board |
| `GITHUB_TOKEN` | (built-in) most | Default repo-scoped token |

Use `secrets: inherit` (as `UpdateReadme` does) only when the reusable workflow needs
the caller's whole secret set; otherwise pass secrets explicitly, one by one.

---

## 6. Recipe — workflows for a **new** repository

1. **Start from the template.** Create the repo from `CTAppTemplate.jl` ("Use this
   template"). It already contains the base-set callers.
2. **Run `setup-repo`.** Trigger the `Setup Repository` workflow
   (`workflow_dispatch`); it renames the package, regenerates the UUID, sets authors
   and assignees, and opens a setup PR. Merge it, then delete `setup-repo.yml`.
3. **Adjust `AutoAssign.yml`** assignee if `setup-repo` didn't (default `ocots`).
4. **Decide on `Breakage`.** Add `Breakage.yml` only if other ecosystem packages
   depend on this one; fill the `pkgname` matrix with the downstream consumers. Skip it
   for a leaf/peripheral repo.
5. **Decide on `AddToProject`.** Add it (with the `PROJECT_TOKEN` secret) if the repo is
   tracked on the org project board.
6. **Set CI inputs.** Choose `versions`, `runs_on`, and `use_ct_registry` in `CI.yml`.
   Set `use_ct_registry: true` if the package needs `ct-registry`.
7. **Create the `run …` labels** you reference (`run ci`, `run breakage`, `run
   documentation`, …) in the repo's label set.
8. **Configure secrets** in the repo (or org): `SSH_KEY`, `DOCUMENTER_KEY`,
   `CODECOV_TOKEN`, `PROJECT_TOKEN` as needed by the workflows you kept.
9. **Provide `UpdateReadme` inputs.** Add a `README.template.md` and fill
   `package_name`, `repo_name`, `doc_url` in `UpdateReadme.yml`, or the job self-skips.

## 7. Recipe — **updating** workflows org-wide

- **Logic change** (a step, an action version, caching, a new input): edit the
  **reusable** workflow in `CTActions`. Because callers pin `@main`, every repo picks it
  up on its next run. Keep inputs backward-compatible (add with a `default:`), or update
  the callers in lockstep.
- **Per-repo trigger/inputs change** (different OS matrix, a new label, enabling
  `ct-registry`): edit that repo's **caller** only.
- **Roll out a brand-new workflow:** add the reusable in `CTActions`, add the caller to
  `CTAppTemplate.jl` (so new repos inherit it), then copy the caller into the existing
  repos that need it.
- **Disable a workflow in one repo without deleting it:** rename `X.yml` → `X.yml.disabled`
  (see CTDirect's Formatter).
- **Pinning:** prefer `@main` for in-ecosystem reuse (fast propagation); if you ever
  need a frozen pipeline for a release branch, pin a caller to a tag/SHA of `CTActions`
  instead.

---

## 8. Quick checklist for a new repo

- [ ] Created from `CTAppTemplate.jl`; `setup-repo` run and merged; `setup-repo.yml` removed.
- [ ] Base set present (CI, Coverage, Documentation, Formatter, SpellCheck, CompatHelper, UpdateReadme, AutoAssign, TagBot).
- [ ] `Breakage.yml` added **iff** the repo has internal downstream consumers; matrix filled.
- [ ] `AddToProject.yml` added **iff** tracked on the project board (`PROJECT_TOKEN` set).
- [ ] CI inputs set (`versions`, `runs_on`, `use_ct_registry`).
- [ ] `run …` labels created for every label-gated caller.
- [ ] Secrets configured (`SSH_KEY`, `DOCUMENTER_KEY`, `CODECOV_TOKEN`, `PROJECT_TOKEN`).
- [ ] `README.template.md` present and `UpdateReadme.yml` inputs filled.
