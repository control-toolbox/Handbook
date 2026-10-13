# Performance verification

How performance properties are made *verifiable and enforced* — static analysis with
JET, then regression guards locking in what was verified. For the *design* principles
(parametric fields, function barriers, no `Any` in hot paths), see
[`TYP8`](types.md#typ8--type-stability-by-default). For *running* tests, see
[`method.md`](../method.md).

Identifiers: `PERF1`–`PERF6` (see [`README.md`](../README.md#rule-identifiers)).

---

## PERF1 — Classify hot path vs. setup path; guard the hot path only

**Rule.** Before measuring anything, classify the code. Every performance decision below
follows from this split:

- **Hot path** — called repeatedly during a computation: evaluating a wrapped
  function at each solver step, reading an option inside an inner loop, evaluating
  an interpolant at many points. This code must be **type-stable** and its
  allocation behavior must be **an invariant**, because any defect multiplies over
  thousands of calls.
- **Setup path** — called once per problem, before the computation: building a
  registry, constructing and validating options, resolving an identifier. Runtime
  dispatch here is often **by design** (runtime-extensible registries need
  `Vector`/`Dict` storage with abstract element types) and its cost is paid once.

**Keep the hot path inferable and allocation-clean; do not chase dispatch warnings in
one-time construction code.**

**Why.** A guard asserted on setup-path code is not a regression guard — it is a
permanently red assertion of an accepted trade-off.

**Check.** `judgment`.

---

## PERF2 — Scan for correctness first, investigate, then lock in

**Rule.** Guards lock in a *verified* state, so the sequence matters:

1. **Correctness scan first** (`JET.report_package`, one-off) — find latent bugs
   (`MethodError`s, undefined names) and JET false positives. Fix the bugs; verify
   suspected false positives by hand at the REPL before blaming the analyzer.
2. **Stability investigation** (`JET.@report_opt` on concrete hot-path calls;
   `Cthulhu.@descend` / `@code_warntype` to find root causes) — fix instabilities at
   their origin, not at the call site.
3. **Only then, lock in** — `@inferred` stability guards ([`PERF4`](#perf4--inferred-guards-on-verified-hot-path-calls))
   and `@ballocated` allocation guards ([`PERF5`](#perf5--an-allocation-contract-never-wall-clock-time))
   on the now-verified entry points.

JET has **two analyzers**; conflating them is the most common setup mistake:

| Analyzer | Entry points | Answers | Needs |
| --- | --- | --- | --- |
| Error analyzer | `report_package`, `test_package` | "does any method contain a latent error?" | nothing — scans every method signature |
| Optimization analyzer | `@report_opt`, `report_opt` | "is this *call* free of runtime dispatch?" | a **concrete call** (function + argument types) |

`report_package` does **not** detect type instabilities; `@report_opt` does, but
only for the calls you give it.

**Why.** Locking in an unhealthy state freezes bad numbers.

**Check.** `judgment` (a process, not a property of the code).

---

## PERF3 — `JET.test_package` enabled, and genuinely clean

**Rule.** Once the one-off scan is clean, enable it permanently in the code-quality test
file, scoped to the package's own modules — and keep it genuinely clean: no tolerated
red.

```julia
Test.@testset "JET" begin
    JET.test_package(MyPackage; target_modules=(MyPackage,))
end
```

**Why.** A suite that is red on a known false positive trains everyone to ignore it.

### False positives

JET's signature-based analysis cannot resolve every legal pattern (e.g. helper
functions defined inside a `struct` body, called from a sibling inner constructor).
When JET flags code that demonstrably works:

1. **Verify at the REPL** — run the flagged call; confirm it behaves.
2. **Prefer simplifying the pattern over excluding it.** A construct JET cannot
   follow is often one the compiler struggles with too — the same `Val`-dispatch
   machinery that blinds the analyzer can be a genuine instability when its argument
   is not a compile-time constant. Replacing it with straight-line code frequently
   fixes both at once.
3. Enable `test_package` only when the scan is genuinely clean.

### Benign collector noise: "skipping callee ... UndefRefError()"

`JET.test_package` collects method signatures via Revise/`LoweredCodeUtils` without
calling anything. For a **keyword-argument functor method** (a callable struct with
a `; kwarg=default` in its call signature), Julia compiles a hidden body function
named `var"#_#N"`; `LoweredCodeUtils` cannot statically attribute that hidden body to
its parent method and emits `@warn "skipping callee ... due to UndefRefError()"`
before moving on. It is a collector limitation, not a JET finding: the flagged body
is simply excluded from the static scan, the scan result is unaffected, and the
method's runtime behavior is (as always) covered by the normal test suite regardless.

Distinguish this from a real false positive (previous section): nothing is
misreported here — there is no entry in JET's result, just log noise while
scanning. Filter it precisely (message prefix + emitting module), never by silencing
the whole module or lowering the log level globally, so an unrelated warning from the
same package still surfaces:

```julia
using Logging: Logging

struct _SkipBenignLoweredCodeUtilsWarnings <: Logging.AbstractLogger
    logger::Logging.AbstractLogger
end

Logging.min_enabled_level(l::_SkipBenignLoweredCodeUtilsWarnings) =
    Logging.min_enabled_level(l.logger)

Logging.shouldlog(l::_SkipBenignLoweredCodeUtilsWarnings, level, _module, group, id) =
    Logging.shouldlog(l.logger, level, _module, group, id)

function Logging.handle_message(
    l::_SkipBenignLoweredCodeUtilsWarnings, level, message, _module, group, id, file, line; kwargs...
)
    if level == Logging.Warn && nameof(_module) === :LoweredCodeUtils &&
        startswith(string(message), "skipping callee")
        return nothing
    end
    return Logging.handle_message(l.logger, level, message, _module, group, id, file, line; kwargs...)
end

Test.@testset "JET" begin
    Logging.with_logger(_SkipBenignLoweredCodeUtilsWarnings(Logging.current_logger())) do
        JET.test_package(MyPackage; target_modules=(MyPackage,))
    end
end
```

`Logging` is a standard library, but a strict `Pkg.test` sandbox (a `[targets]`-style
`Project.toml`, no separate `test/Project.toml`) still needs it declared explicitly
in `[extras]`/`[targets]["test"]`/`[compat]`, the same as any other stdlib used only
under `test/`.

**Check.** `exact` (to be tooled): the test suite calls `JET.test_package` with
`target_modules`; it passing is checked by CI.

---

## PERF4 — `@inferred` guards on verified hot-path calls

**Rule.** One guard per verified hot-path entry point, added to the **existing testset
that owns the fixture** — not blanket coverage, and never on setup-path functions.

```julia
Test.@testset "Type stability" begin
    w = SubA.Wrapper(_raw)                 # construction may be dynamic — not asserted
    Test.@inferred w(x)                    # the repeated call must infer
    Test.@inferred SubA.trait_accessor(w)  # trait reads must infer
end
```

`@inferred` applies to **calls only**, never field access (see [`TST7`](testing.md)).

**Why.** The guard turns a verified stability into a regression test, next to the
fixture that exercises it.

**Check.** `judgment`: which calls are hot is decided by
[`PERF1`](#perf1--classify-hot-path-vs-setup-path-guard-the-hot-path-only).

---

## PERF5 — An allocation contract, never wall-clock time

**Rule.** Guard allocations with `BenchmarkTools.@ballocated`, with `$` interpolation,
in one dedicated "performance contract" file (`test/suite/meta/test_performance.jl`,
next to the code-quality file). **Never assert wall-clock time in a test suite.** Two
invariant classes:

**Zero-overhead wrappers** — a wrapper call must allocate exactly what the raw
wrapped function does. Compare wrapper to raw rather than to a magic constant, so
the guard is independent of Julia version and word size:

```julia
# TOP-LEVEL: raw functions to wrap (as always — never inside the test function)
_raw(x) = -x

Test.@testset "Zero-overhead wrappers" begin
    w = SubA.Wrapper(_raw)
    Test.@test (BenchmarkTools.@ballocated $w($x)) ==
        (BenchmarkTools.@ballocated _raw($x))
end
```

**Zero-allocation reads** — accessors, interpolant evaluation, option reads: the
things called per iteration must allocate nothing at all:

```julia
Test.@testset "Zero-allocation reads" begin
    Test.@test (BenchmarkTools.@ballocated $interp(0.5)) == 0
    Test.@test (BenchmarkTools.@ballocated SubA.trait_accessor($w)) == 0
    Test.@test (BenchmarkTools.@ballocated SubB.option_read($strategy)) == 0
end
```

Note the `$` interpolation: without it, `@ballocated` benchmarks global-variable
access and reports spurious allocations. These guards run fast (allocation counts
need almost no sampling) and belong in the normal suite — no separate CI.

**Why.** Type stability is necessary but not sufficient: a change can stay fully
inferable yet start allocating (a stray `collect`, a boxed closure, an abstract
field). Allocation counts — unlike wall-clock time — are **deterministic**: no
run-to-run noise, no machine dependence, `== 0` either holds or does not. One file
makes the package's performance guarantees legible in one place.

**Check.** `exact` (to be tooled) for wall-clock assertions (`@elapsed`, `@time`,
`@btime` inside `@test`); `heuristic` for `@ballocated` without `$` interpolation.

---

## PERF6 — JET and BenchmarkTools are test dependencies

**Rule.** JET and BenchmarkTools are dev/test dependencies, never runtime ones — in
`[extras]` and the test target (plus `docs/Project.toml` if live doc checks are used),
never in `[deps]`:

```toml
[extras]
JET = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"

[targets]
test = ["JET", "Test", ...]

[compat]
JET = "0.11"
```

**Why.** Users of the package never pay for its verification tooling.

**Check.** `exact` (to be tooled): neither package appears in `[deps]` of
`Project.toml`.

---

## Optional: live checks in the documentation

A performance guide page can *execute* `JET.@report_opt` on hot-path calls at
doc-build time (executed `@example` blocks; JET then also joins `docs/Project.toml`):

````markdown
```@example perf
using MyPackage, JET
w = MyPackage.SubA.Wrapper(x -> -x)
JET.@report_opt w([1.0, 2.0])
```
````

A clean call renders as `No errors detected`, regenerated at every build — the page
shows readers *what healthy looks like* and a hot-path regression surfaces in the
docs build instead of letting the page go stale. Keep only stable-output checks
live; illustrate known-dynamic constructions in non-executed ` ```julia ` blocks,
because dispatch traces embed Base-internal `file:line` strings that shift between
Julia versions and would make the build fragile.
