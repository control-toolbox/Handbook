# Types, traits, interfaces

How we model variation: abstract types for *nouns*, trait-parameters for *adjectives*,
dispatch via trait extraction. Generic examples.

Identifiers: `TYP1`–`TYP8` (see [`README.md`](../README.md#rule-identifiers)).

---

## TYP1 — One abstract type per noun, one trait-parameter per axis

**Rule.**

> **One abstract type per real *noun*. One trait-parameter per orthogonal *axis*.**
> Concrete types are reserved for genuinely different data layouts
> ([`TYP7`](#typ7--concrete-types-only-for-different-data-layouts)).

- **Abstract type** — good for a *noun* ("what is it"), `is-a` relations, shared
  methods. But: single inheritance only → combinatorial explosion across several
  orthogonal axes.
- **Trait (as a type parameter)** — good for an *adjective / capability*. Composes
  freely, dispatched via an extractor.

### When an axis becomes a type parameter (vs. stays an extracted trait)

The criterion is not "is this axis important?" but:

> **Does the axis change the contract visible to consumers of the abstract type?**
> If yes → type parameter. If no → extracted trait only.

- An axis that changes the **method signatures** the abstract type promises (e.g. number
  or role of arguments) is structural: it propagates up through the hierarchy and belongs
  as a type parameter.
- An axis that only affects **how** a computation is performed *inside* a concrete type,
  while both variants honour the same abstract contract, stays as an extracted trait on
  the concrete type.

A practical signal: **if an axis never propagates beyond one level of the hierarchy** —
present on concrete types but absent from abstract types and their consumers — it is most
likely an implementation detail, not a structural axis.

**Why.** Single inheritance cannot express several orthogonal axes: a type tree per
combination explodes, while one parameter per axis composes.

**Check.** `judgment`.

---

## TYP2 — Traits as type parameters, read by an extractor, dispatched on

**Rule.** A trait is a singleton type under a shared abstract trait. It is carried as a
type parameter, read back with an extractor, and given a readable alias per variant.
Dispatch extracts the trait, then re-dispatches on it (Holy trait pattern).

```julia
abstract type AbstractMode <: AbstractTrait end
struct Eager <: AbstractMode end
struct Lazy  <: AbstractMode end

# The trait is a parameter of the noun's abstract type
abstract type AbstractThing{M<:AbstractMode} end

# Extractor: returns a type known at compile time
mode(::AbstractThing{M}) where {M} = M

# Aliases give back the readable per-variant names for dispatch
const AbstractEagerThing = AbstractThing{Eager}
const AbstractLazyThing  = AbstractThing{Lazy}
```

Adding an axis is adding a parameter, not multiplying the type tree.

```julia
function process(x::AbstractThing)
    return _process(mode(x), x)        # extract, then re-dispatch
end

_process(::Type{Eager}, x) = ...       # eager branch
_process(::Type{Lazy},  x) = ...       # lazy branch
```

**Why.** This is **type-stable** when the trait is a type parameter: `mode(x)` is known
at compile time, so the re-dispatch resolves statically; the extra call is inlined.

⚠️ Pitfall: extracting a trait from a *runtime value* (not encoded in the type) makes
the re-dispatch dynamic and breaks inference. Keep traits as type parameters.

**Check.** `judgment`; the stability of the dispatch is guarded by
[`PERF4`](performance.md).

---

## TYP3 — Aliases and `where` repeat every bound verbatim

**Rule.** Every time you name a type parameter — in a `const Alias{...} = ...`
declaration or in a method's `where {...}` clause — copy its bound verbatim from the
original `struct`/`abstract type`. If you don't need to restrict a trailing parameter,
leave it out of the curly braces instead of naming it unbounded; Julia's own
partial-application then carries the original bound forward for free, which is
strictly safer than restating it by hand.

**Why.** The alias example of [`TYP2`](#typ2--traits-as-type-parameters-read-by-an-extractor-dispatched-on)
is safe because it fixes the *only* parameter — nothing is left free, so there is no
bound to get wrong. The pitfall appears as soon as a type has **more than one**
parameter and the alias only fixes some of them.

`<:` between two parametric types is a **structural** comparison of declared
bounds — Julia does not look inside the body to notice that a wider bound is, in
practice, harmless. Any alias or method signature that **names** a type parameter
without repeating its original bound silently widens that parameter to `<:Any`,
and the result stops being a subtype of the type it was meant to specialize — even
though `isa` on any concrete instance still works fine, since instance membership
and formal subtyping are checked differently. Method dispatch ranks overlapping
methods using exactly that `<:` relation, so the bug stays invisible until two
methods overlap for the same call: dispatch then either **silently picks the wrong
(more generic) method**, or **throws `MethodError: ... is ambiguous` at the call
site** — both far away from the alias declaration that caused it, and neither
raised at definition time.

```julia
abstract type AbstractThing{M<:AbstractMode} end

struct Concrete{M<:AbstractMode,Extra<:AbstractBound} <: AbstractThing{M}
    data::Extra
end

# ✗ risky: Extra is named but its bound is dropped → defaults to Extra<:Any
const EagerConcrete{Extra} = Concrete{Eager,Extra}
EagerConcrete <: Concrete    # false — NOT a subtype, silently

# ✓ safe #1: repeat the original bound verbatim
const EagerConcrete{Extra<:AbstractBound} = Concrete{Eager,Extra}
EagerConcrete <: Concrete    # true

# ✓ safe #2 (preferred when possible): leave the untouched parameter out of the
# braces entirely — Julia then reuses Concrete's own bound automatically, so
# there is nothing to get wrong
const EagerConcrete = Concrete{Eager}
EagerConcrete <: Concrete    # true
```

The same rule applies to a method's own `where` clause, and it is **all-or-nothing**
— dropping *one* bound among several is enough to break the relation, even if the
others are correctly restated:

```julia
# ✗ TD's bound is dropped (should be TD<:AbstractMode) → mis-ranked or ambiguous
# against a more generic method taking ::Concrete or ::AbstractThing
process(x::Concrete{TD,Extra}, y) where {TD,Extra<:AbstractBound} = ...

# ✓ every bound restated exactly as declared on Concrete
process(x::Concrete{Eager,Extra}, y) where {Extra<:AbstractBound} = ...
# (here TD is not even named — it is fixed to Eager — only Extra needs a bound;
# the point is: whichever parameters you DO name must all carry their bound)
```

This is not a corner case reserved for exotic code: it silently affects the exact
alias pattern of [`TYP2`](#typ2--traits-as-type-parameters-read-by-an-extractor-dispatched-on)
as soon as the aliased type has more than one parameter, which is the common case for
any noun with both a trait axis and other structural parameters (a container type, a
backing store, …).

**Check.** To be tooled — `exact` for aliases by introspection (a loaded alias whose
`UnionAll` variable is bounded by `Any` where the aliased type declares a bound);
`heuristic` for `where` clauses. Measure meanwhile with two greps, which surface
**candidates** for manual review (not proof of a bug — cross-check each hit against
the bounds actually declared on the type being aliased or dispatched on; many hits
are innocuous, e.g. a parameter that was never bounded upstream, or a `where` clause
matching a concrete type's own declaration rather than a shared, more-bounded
ancestor):

```bash
# Aliases whose parameter list has zero `<:` (no bound restated at all)
grep -rnE '^\s*const\s+[A-Za-z_][A-Za-z0-9_]*\{[A-Za-z_][A-Za-z0-9_]*(\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\}\s*=' --include='*.jl' src/

# `where {...}` clauses with zero `<:` (every listed var defaults to Any)
grep -rnE 'where \{[A-Za-z_][A-Za-z0-9_]*(\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\}' --include='*.jl' src/
```

The first grep is high-precision (`heuristic`): a hit is almost always worth checking,
because a `const Alias{...} = ...` declaring parameters with *zero* `<:` anywhere in
its own parameter list means none of them repeat a bound. The second grep is noisier
(`signal`: a bare `where {A,B}` is often correct — e.g. a concrete type's own
unbounded fields, or a callable struct's sole method) and needs one extra check per
hit: does the type being dispatched on declare a bound, for that parameter, that this
`where`-clause fails to repeat?

---

## TYP4 — Contracts are `NotImplemented` stubs on abstract types

**Rule.** Define methods on abstract types; mark required ones with a `NotImplemented`
stub so a subtype that forgets them fails loudly.

```julia
abstract type AbstractModel end

"""Contract: every model implements `evaluate`."""
function evaluate(m::AbstractModel, x)
    throw(Exceptions.NotImplemented(
        "evaluate not implemented";
        required_method = "evaluate(::$(typeof(m)), x)",
        suggestion      = "Define evaluate for your concrete model type",
        context         = "AbstractModel contract",
    ))
end
```

**Why.** A missing method surfaces as a clear, actionable error naming the method to
define, instead of a `MethodError` deep inside generic code.

**Check.** To be tooled — `exact` by introspection: every concrete subtype of an
abstract type has a method for each of its `NotImplemented` stubs.

---

## TYP5 — Program against abstractions; subtypes honor the contract

**Rule.**

- **Accept abstractions** in signatures (`build(::AbstractInput)`), not concrete types,
  so users can extend without editing core code (OCP/DIP).
- **Subtypes honor the contract** (LSP): same return shape across the hierarchy; test
  generic code against all subtypes.

```julia
# Generic code works with any subtype (LSP)
function optimize(m::AbstractModel, x0)
    v = evaluate(m, x0)   # safe for any model honoring the contract
    # ...
end
```

**Why.** Generic code written once works for every present and future subtype.

**Check.** `judgment`; contract tests ([`TST4`](testing.md)) exercise generic code
against all subtypes.

---

## TYP6 — No abstract type for a capability

**Rule.** A capability (e.g. "supports AD") is a *trait*, not a node in the hierarchy.

**Why.** Adding `AbstractThingWithAD` collides with the other axes under single
inheritance.

**Check.** `judgment`.

---

## TYP7 — Concrete types only for different data layouts

**Rule.** Use a concrete type when the *data layout* genuinely differs (different
fields), not to encode an adjective. Two concrete types with identical fields that
differ only by a flag should be one parametric type with a trait parameter + aliases.

**Why.** A flag encoded as a separate type duplicates every method that does not care
about the flag.

**Check.** `signal` (to be tooled): two concrete types with identical field names and
types; whether they should merge is a `judgment`.

---

## TYP8 — Type stability by default

**Rule.** Type-stable = return type inferable from input types at compile time.
Typically 10–100× faster than unstable code.

- **Parametric, concrete fields** — `struct C{T}; data::Vector{T}; end`, never
  `Vector{Any}` or an abstract field type.
- **`NamedTuple` over `Dict`** for fixed-key, mixed-type records.
- **No `Any` in hot paths**; avoid conditional return types
  (`Union{Int,Nothing}` from one function).
- **Function barriers** — isolate an unavoidable instability behind a typed inner
  function.
- **`const Ref(...)`** instead of mutable globals.

Type stability matters on critical paths (inner loops, numerics); it is secondary on
one-time setup, user-facing API, and error paths
([`PERF1`](performance.md)).

```julia
@testset "type stability" begin
    @test_nowarn @inferred f(x)      # @inferred only on function calls, not field access
    @test (@allocated hot_path(x)) == 0
end
```

**Why.** An inference failure on the hot path costs an order of magnitude and
propagates to every caller.

**Check.** `signal` (to be tooled) for abstract or `Any` field types; stability itself
is verified by JET and locked in by `@inferred` and allocation guards
([`PERF2`–`PERF5`](performance.md)).

---

## Guiding principles (no identifier)

SOLID, DRY, KISS and YAGNI guide every design decision above; they are not checkable
rules, so they carry no identifier.

- **SRP** — one responsibility per module/function/type. Red flags: names with "and",
  functions > ~50 lines, branches handling unrelated concerns.
- **OCP** — extend via new subtypes + dispatch, not by editing `isa`/`typeof` chains.
- **LSP** — subtypes substitutable; consistent return types.
- **ISP** — small focused interfaces; don't force unused methods on a type.
- **DIP** — depend on abstract types; inject dependencies.
- **DRY** — one representation per piece of knowledge; extract shared validation.
- **KISS** — the simplest thing that works.
- **YAGNI** — no speculative fields/features.

Anti-patterns to avoid: God object, primitive obsession (use domain types), feature
envy (put the method where the data is).
