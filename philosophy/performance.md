# Performance verification

How performance properties are made *verifiable and enforced* — static analysis with
JET, then regression guards locking in what was verified. For the *design* principles
(parametric fields, function barriers, no `Any` in hot paths), see
[`types-traits-interfaces.md`](types-traits-interfaces.md#type-stability). For
*running* tests, see [`../RULES.md`](../RULES.md).

## The principle: hot path vs. setup path

Before measuring anything, classify the code. Every performance decision below
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

The rule: **keep the hot path inferable and allocation-clean; do not chase dispatch
warnings in one-time construction code.** A guard asserted on setup-path code is not
a regression guard — it is a permanently red assertion of an accepted trade-off.

## Order of operations

Guards lock in a *verified* state; locking in an unhealthy state freezes bad
numbers. So the sequence matters:

1. **Correctness scan first** (`JET.report_package`, one-off) — find latent bugs
   (`MethodError`s, undefined names) and JET false positives. Fix the bugs; verify
   suspected false positives by hand at the REPL before blaming the analyzer.
2. **Stability investigation** (`JET.@report_opt` on concrete hot-path calls;
   `Cthulhu.@descend` / `@code_warntype` to find root causes) — fix instabilities at
   their origin, not at the call site.
3. **Only then, lock in** — `@inferred` stability guards and `@ballocated`
   allocation guards on the now-verified entry points.

## JET

JET has **two analyzers**; conflating them is the most common setup mistake:

| Analyzer | Entry points | Answers | Needs |
| --- | --- | --- | --- |
| Error analyzer | `report_package`, `test_package` | "does any method contain a latent error?" | nothing — scans every method signature |
| Optimization analyzer | `@report_opt`, `report_opt` | "is this *call* free of runtime dispatch?" | a **concrete call** (function + argument types) |

`report_package` does **not** detect type instabilities; `@report_opt` does, but
only for the calls you give it.

### Setup

JET is a dev/test dependency, never a runtime one:

```toml
[extras]
JET = "c3a54625-cd67-489e-a8e7-0a5a0ff4e31b"

[targets]
test = ["JET", "Test", ...]

[compat]
JET = "0.11"
```

Once the one-off scan is clean, enable it permanently in the code-quality test file,
scoped to the package's own modules:

```julia
Test.@testset "JET" begin
    JET.test_package(MyPackage; target_modules=(MyPackage,))
end
```

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
3. Enable `test_package` only when the scan is genuinely clean — a suite that is red
   on a known false positive trains everyone to ignore it.

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

## Stability guards: `Test.@inferred`

One guard per verified hot-path entry point, added to the **existing testset that
owns the fixture** — not blanket coverage, and never on setup-path functions.

```julia
Test.@testset "Type stability" begin
    w = SubA.Wrapper(_raw)                 # construction may be dynamic — not asserted
    Test.@inferred w(x)                    # the repeated call must infer
    Test.@inferred SubA.trait_accessor(w)  # trait reads must infer
end
```

`@inferred` applies to **calls only**, never field access
(see [`testing.md`](testing.md)).

## Allocation guards: `BenchmarkTools.@ballocated`

Type stability is necessary but not sufficient: a change can stay fully inferable
yet start allocating (a stray `collect`, a boxed closure, an abstract field). Guard
the complementary property with allocation counts, which — unlike wall-clock time —
are **deterministic**: no run-to-run noise, no machine dependence, `== 0` either
holds or does not. **Never assert wall-clock time in a test suite.**

Gather these in one dedicated "performance contract" file
(`test/suite/meta/test_performance.jl`, next to the code-quality file), so the
package's performance guarantees are legible in one place. `BenchmarkTools` joins
the test target the same way JET does. Two invariant classes:

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

## Checklist

- [ ] Hot path vs. setup path identified; guards target the hot path only.
- [ ] One-off `JET.report_package` scan run; real bugs fixed; false positives
      verified by hand (and the flagged pattern simplified where it was also a
      genuine instability).
- [ ] `JET.test_package(...; target_modules=...)` enabled in the code-quality test
      file, and genuinely clean — no tolerated red. Benign `LoweredCodeUtils`
      "skipping callee" noise (if any keyword-argument functor methods exist)
      filtered precisely, not silenced wholesale.
- [ ] `Test.@inferred` guard on each verified hot-path call, in the testset that
      owns the fixture.
- [ ] Allocation contract in `test/suite/meta/test_performance.jl`:
      wrapper-vs-raw equalities and `== 0` reads, via `@ballocated` with `$`
      interpolation; no wall-clock assertions anywhere.
- [ ] JET and BenchmarkTools in `[extras]`/test target (+ docs env if live doc
      checks are used) — never in `[deps]`.
