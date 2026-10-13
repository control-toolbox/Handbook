# Testing

How tests are structured and written. Generic examples. For *running* tests, see
[`method.md`](../method.md).

Identifiers: `TST1`–`TST7` (see [`README.md`](../README.md#rule-identifiers)).

Tests are **contract-first** (define and test interfaces with fakes/stubs to verify
routing and behavior; test public APIs and the internal logic that matters),
**isolated** (unit tests use fakes; integration tests exercise real boundaries),
**deterministic** (reproducible, no external state, no execution-order dependence) and
**clear** (intent obvious from names and structure).

---

## TST1 — The file template: module + callable entry, organized by functionality

**Rule.** This is mandatory. Each test file is a **module**; it imports everything
**qualified** ([`TST2`](#tst2--qualified-imports-and-qualified-calls)); it defines a
single entry function `test_<name>()`; and it **redefines that function in the outer
scope** so the test runner can call it. Test organization follows *functionality*, not
the `src/` layout: `test/suite/<group>/test_<name>.jl`.

```julia
# File: test/suite/<group>/test_<name>.jl
module TestName

# Qualified imports — bring module names into scope, call Sub.sym everywhere
using Test: Test
using CTBase: Exceptions
using MyPackage: SubA, SubB

# Test options (verbose / timing), overridable by the runner
const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# TOP-LEVEL fakes (never inside a function — world-age issues otherwise)
struct FakeThing <: SubA.AbstractThing end
SubA.required_method(::FakeThing) = 42

# Single entry function, named exactly like the file
function test_name()
    Test.@testset "Name" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test SubA.required_method(FakeThing()) == 42
    end
end

end # module TestName

# CRITICAL: redefine in the outer scope so the runner can call it
test_name() = TestName.test_name()
```

**Why.**

- **Module wrapper** — isolates names per file; avoids clashes across the suite.
- **Outer redefinition** — the runner discovers and calls `test_name()` at top level.
- **Organization by functionality** — a behavior is tested in one place, even when its
  implementation spans several source files.

**Check.** `exact` (to be tooled, syntactic): the file is one module, defines
`test_<name>` matching the file name, and redefines it after the module.

---

## TST2 — Qualified imports and qualified calls

**Rule.** Imports are qualified and written with `using` (`using X: X`,
`using Pkg: Sub`) — same policy as the source, `import` included: never
([`MOD3`](modules.md#mod3--no-import)). Calls are qualified, **omitting the root for
submodules**: `Test.@test SubA.f(x) isa SubB.T` — not the fully-root-qualified,
over-verbose form; not unqualified.

**Why.** The module name is in scope and call sites read `SubA.sym`: the origin of
every symbol under test is visible.

**Check.** As [`MOD3`](modules.md#mod3--no-import)–[`MOD6`](modules.md#mod6--qualification-at-call-sites),
applied to `test/`.

---

## TST3 — Fakes and stubs at module top-level

**Rule.** Fakes, stubs and every `struct` used by a test are defined at module
top-level — never inside test functions.

- **Fake** — minimal struct implementing the required contract methods, to isolate the
  unit under test.
- **Stub** — a default method on an abstract type that throws `NotImplemented` /
  `ExtensionError`; tested by calling it on a fake type.
- **Mock** (interaction-recording) — not used; fakes suffice.

**Why.** Defining a `struct` inside a function triggers world-age errors.

**Check.** `exact` (to be tooled, syntactic): no type or method definition (including
through `@eval`/`eval`) inside a function of a test file.

---

## TST4 — Categories present and separated

**Rule.** A test file covers the relevant categories, separated with section comments
inside one `@testset`:

- **Unit** — single component in isolation; pure, deterministic, fast (<1ms). Use fakes
  for dependencies.
- **Integration** — several real module boundaries together; fakes only for leaf
  dependencies. Slower (up to ~1s) acceptable.
- **Contract** — verify the interface using fakes that implement only the required
  methods. Check routing, defaults, and Liskov substitution (generic code works for
  every subtype). Includes **export verification**: assert submodule exports exist and
  that the package top-level re-exports nothing it shouldn't.
- **Error** — verify stubs and error paths throw the right exception
  ([`TST5`](#tst5--error-paths-and-extension-stubs)).

**Why.** Each category answers a different question; separating them shows which ones
a file covers, and which it lacks.

**Check.** `judgment`.

---

## TST5 — Error paths and extension stubs

**Rule.** Error paths use `@test_throws` ([`EXC5`](exceptions.md#exc5--covered-by-a-test)).

- **Interface stub** (`NotImplemented`): a fake that omits a required method triggers
  the abstract type's stub. Safe regardless of loaded extensions.
- **Extension stub** (`ExtensionError` / fallback): **always use a fake type** no
  extension knows about.

**Why.** Using a real type makes the test depend on whether another test file loaded
the extension.

**Check.** `signal` (to be tooled): a test of an extension stub called on a type
defined in `src/`.

---

## TST6 — Capability-gated tests skip visibly

**Rule.** A test that needs a runtime capability (CUDA, a specific hardware device, …)
must not skip by **returning early from inside its own `@testset`**; it skips with
`Test.@test_skip`, and fails loudly on the runner that is supposed to have the
capability.

```julia
# ❌ Vacuous skip — indistinguishable from a real pass
Test.@testset "GPU flows" begin
    if !is_cuda_on()
        @info "CUDA not functional — skipped"
        return nothing
    end
    Test.@test some_gpu_assertion()
end

# ✅ Visible skip — shows as `Broken` in the summary
Test.@testset "GPU flows" begin
    if !is_cuda_on()
        Test.@test_skip some_gpu_assertion()
    else
        Test.@test some_gpu_assertion()
    end
end
```

On the runner that is *supposed* to have the capability, make its absence fail loudly
instead of silently — `RUNNER_NAME` is set by the GitHub Actions agent itself, no
CI/CTActions change needed (see the
[CTActions workflow guide](https://github.com/control-toolbox/CTActions/blob/main/docs/WORKFLOWS.md)
for the `kkt`/`occidata` GPU runner names):

```julia
on_gpu_runner() = get(ENV, "RUNNER_NAME", "") in ("kkt", "occidata")

if on_gpu_runner()
    Test.@test is_cuda_on()   # fails loudly if the GPU runner lost its device
end
```

Define the capability predicate (`is_cuda_on()` and similar) **once**, not once per
test file — duplicated copies drift. Use a single `TestCapabilities` module: either in
`test/runtests.jl` (`Main.TestCapabilities`) if the runner shares one process across
files, or `test/helpers/capabilities.jl` `include`d by each file when the runner
isolates each file in its own process (each file must then stand alone).

Reference: control-toolbox/CTSolvers.jl#189 and #190 (original report and fix),
control-toolbox/CTFlows.jl#375 (same pattern applied one level up).

**Why.** An early `return` makes a correctly-skipped run (capability absent, as
expected) and a silently-broken run (capability *should* be present but isn't) produce
the exact same output: a green testset with zero assertions (`Pass 0`). Nothing in the
summary tells them apart.

**Check.** `heuristic` (to be tooled): a `return` inside a `@testset` body.

---

## TST7 — Specific, independent, deterministic tests

**Rule.**

- **Independence** — fresh instances per testset; no shared mutable/global state; no
  order dependence.
- **Specific assertions** (`≈ … atol=…`, `isa T`, `== n`), not `> 0` or `!= nothing`.
- **Names** describe *what* is tested, not *how*.
- **Internal `_` functions** are tested directly when their logic is complex/branchy;
  otherwise they are covered indirectly.
- **Type-stability tests** use `@inferred` on **function calls** (not field access);
  allocation tests for hot paths prefer `BenchmarkTools.@ballocated` (steady-state,
  excludes first-call compilation) over raw `@allocated`.

```julia
Test.@test_nowarn Test.@inferred SubA.accessor(obj)   # ✅ a call
# Test.@inferred obj.field                              # ❌ field access
Test.@test (BenchmarkTools.@ballocated SubA.accessor($obj)) == 0
```

For the full methodology — JET setup, hot-path vs. setup-path classification, and the
allocation-contract file — see [`PERF1`–`PERF6`](performance.md).

**Why.** A vague assertion passes on wrong results; a test that depends on another's
state passes or fails by accident of order.

**Check.** `heuristic` (to be tooled) for weak assertions (`> 0`, `!= nothing`) and
`@inferred` on a field access; independence is a `judgment`.
