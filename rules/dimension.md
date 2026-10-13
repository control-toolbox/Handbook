# Dimension and shape: 1-D is a scalar

How control-theoretic quantities are shaped across the ecosystem. Generic examples.
For types vs traits, see [`types.md`](types.md).

Identifiers: `DIM1`–`DIM5` (see [`README.md`](../README.md#rule-identifiers)).

---

## DIM1 — A one-dimensional quantity is a scalar

**Rule.**

> **A one-dimensional quantity is a `scalar`, never a length-1 vector.**

This applies to every user-facing quantity of a problem — **state**, **costate**,
**control**, **variable** — and it holds end to end: the functions the user writes, the
values integrators pass around, and the trajectories a solution returns.

- state `x ∈ ℝ`  → `x::Number`   (not `x::Vector` of length 1)
- control `u ∈ ℝ` → `u::Number`
- variable `v ∈ ℝ` → `v::Number`
- for dimension ≥ 2, the quantity is an `AbstractVector`.

**Why.** The dimension-1 case is the only ambiguous one: `ℝ` can be modelled as a scalar
`2.0` or as a 1-vector `[2.0]`. Letting both float around produces silent
inconsistencies — the same problem returns a scalar through one API and a 1-vector
through another. Fixing **scalar** removes the ambiguity, and Julia makes it cheap and
robust:

- `only([v]) == only(v) == v` — one coercion collapses either form to the scalar.
- `x[1] == x` for a scalar — code written with `x[1]` indexing keeps working when `x`
  is a scalar, so the convention does not force a rewrite of existing `[1]`-indexed
  functions.

**Check.** `judgment` in review; enforced at run time by the contract test of
[`DIM5`](#dim5--a-contract-test-pins-the-boundary-shape).

---

## DIM2 — The in-place buffer is the exception

**Rule.** An **in-place** right-hand side needs a *mutable* output, and a scalar cannot
be mutated. So the derivative buffer `r` is **always an `n`-vector**, written by index,
even for `n = 1`:

```julia
# 1-D dynamics: r is a length-1 vector; x, u, v are scalars
f!(r, t, x, u, v) = (r[1] = -x + u; nothing)
```

**Why.** The asymmetry is deliberate: **inputs follow "1-D = scalar"; the in-place
buffer stays a vector** because mutation requires a container.

**Check.** `judgment`.

---

## DIM3 — Callers pass scalars; storage imposes nothing

**Rule.**

- **Model authors** write dynamics, costs, and control laws with scalars for 1-D
  quantities (`r[1] = -x + u`, `ℓ(t,x,u,v) = 0.5u^2`, `u(x,p) = -p`).
- **Callers** (integrators, flows, discretizers) pass **scalars for 1-D** to those
  functions. They must **not** re-wrap a scalar into a 1-vector at the call boundary.
- **Storage layers impose nothing.** A model container that stores a user function
  verbatim does not reshape its arguments; the shape contract is set by whoever *calls*
  the function, and that contract is this convention.

**Why.** A wrapper that vectorizes (`x → [x]`) *breaks* a scalar-written dynamics:
`r[1] = -x + u` with `x == [x]` evaluates the right-hand side to a 1-vector and then
fails to assign it into the scalar slot `r[1]`.

**Check.** `judgment`; [`DIM5`](#dim5--a-contract-test-pins-the-boundary-shape) pins
the boundary.

---

## DIM4 — Coercion is driven by the declared dimension

**Rule.** Coerce by the declared dimension, not by the runtime type of the value:
`only` when `dim == 1`, `identity` otherwise.

**Why.** Because `only` accepts both a scalar and a length-1 vector, a caller that
receives either form still yields the scalar — whereas a test on the runtime type
lets the ambiguity of [`DIM1`](#dim1--a-one-dimensional-quantity-is-a-scalar) back in.

**Check.** `signal` (to be tooled): `isa Number` / `isa AbstractVector` branches on a
state, control or variable value.

---

## DIM5 — A contract test pins the boundary shape

**Rule.** Verify the shape contract with a **fake, type-recording dynamics** (a contract
test): it records the argument types the boundary hands it, and the compute uses `[1]`
so it stays correct for both shapes.

```julia
const SEEN = Ref{Any}(nothing)
rec_dyn_1d!(r, t, x, u, v) = (SEEN[] = (x, u, v); r[1] = -x[1] + u[1]; nothing)

# after driving a 1-D problem through the caller under test:
@test SEEN[][1] isa Number         # 1-D state → scalar (a Dual under AD is still a Number)
@test SEEN[][2] isa Number         # 1-D control → scalar
# and for an n-D problem: @test SEEN[][1] isa AbstractVector
```

Also keep a scalar-vs-vector equivalence test at the unit level: a `[1]`-indexed function
must give the same result whether called with `2.0` or `[2.0]`.

**Why.** The shape is decided at the boundary, far from the user function; only a test
that records what the boundary actually passes catches a regression.

**Check.** `judgment`: each layer that calls user functions has such a test.

---

## Migration note

`x[1]` evaluates to the scalar when `x` is a scalar, so a `[1]`-indexed function is the
**safe common denominator**: it works whether the caller passes a scalar or a 1-vector.
When migrating a package to this convention, switching callers to pass scalars is
non-breaking for `[1]`-indexed user code, and *enables* scalar-written code. Pure
scalar-style code (`-x + u`, no indexing) only works once every caller passes scalars.

## Scope across the ecosystem

The convention is one contract shared by every layer:

- **Modeling** — stores user functions verbatim; documents the scalar contract.
- **Parsing / macros** — may emit `[1]`-indexed code (works with scalars) or scalar code;
  either honours the convention.
- **Discretization / integration** — pass scalars for 1-D to the stored dynamics/costs.
- **Flows** — coerce the internal state to scalar for 1-D (`only`) before calling user
  functions, and return scalars for 1-D in point evaluations and solutions.

A layer that still passes 1-vectors for 1-D is not yet compliant; align it before relying
on scalar-style user code.
