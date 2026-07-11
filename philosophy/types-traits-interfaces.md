# Types, traits, interfaces

How we model variation: abstract types for *nouns*, trait-parameters for *adjectives*,
dispatch via trait extraction. Generic examples.

## The guiding rule

> **One abstract type per real *noun*. One trait-parameter per orthogonal *axis*.**
> Concrete types are reserved for genuinely different data layouts.

- **Abstract type** — good for a *noun* ("what is it"), `is-a` relations, shared
  methods. But: single inheritance only → combinatorial explosion across several
  orthogonal axes.
- **Trait (as a type parameter)** — good for an *adjective / capability*. Composes
  freely, dispatched via an extractor.

## Traits as type parameters

A trait is a singleton type under a shared abstract trait. It is carried as a type
parameter and read back with an extractor.

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

## ⚠️ Aliases and `where`: never let a bound default to `Any`

The example above is safe because it fixes the *only* parameter — nothing is left
free, so there is no bound to get wrong. The pitfall appears as soon as a type has
**more than one** parameter and the alias only fixes some of them.

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
process(x::Concrete{Eager,Extra}, y) where {Extra<:AbstractBound} = ...

# ✓ every bound restated exactly as declared on Concrete
process(x::Concrete{Eager,Extra}, y) where {Extra<:AbstractBound} = ...
# (here TD is not even named — it is fixed to Eager — only Extra needs a bound;
# the point is: whichever parameters you DO name must all carry their bound)
```

**Rule:** every time you name a type parameter — in a `const Alias{...} = ...`
declaration or in a method's `where {...}` clause — copy its bound verbatim from
the original `struct`/`abstract type`. If you don't need to restrict a trailing
parameter, leave it out of the curly braces instead of naming it unbounded;
Julia's own partial-application then carries the original bound forward for free,
which is strictly safer than restating it by hand.

This is not a corner case reserved for exotic code: it silently affects the exact
alias pattern shown earlier in this file as soon as the aliased type has more than
one parameter, which is the common case for any noun with both a trait axis and
other structural parameters (a container type, a backing store, …).

### Auditing a package

Two greps surface **candidates** for manual review (not proof of a bug —
cross-check each hit against the bounds actually declared on the type being
aliased or dispatched on; many hits are innocuous, e.g. a parameter that was never
bounded upstream, or a `where` clause matching a concrete type's own declaration
rather than a shared, more-bounded ancestor):

```bash
# Aliases whose parameter list has zero `<:` (no bound restated at all)
grep -rnE '^\s*const\s+[A-Za-z_][A-Za-z0-9_]*\{[A-Za-z_][A-Za-z0-9_]*(\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\}\s*=' --include='*.jl' src/

# `where {...}` clauses with zero `<:` (every listed var defaults to Any)
grep -rnE 'where \{[A-Za-z_][A-Za-z0-9_]*(\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*\}' --include='*.jl' src/
```

The first grep is high-precision: a hit is almost always worth checking, because a
`const Alias{...} = ...` declaring parameters with *zero* `<:` anywhere in its own
parameter list means none of them repeat a bound. The second grep is noisier (a
bare `where {A,B}` is often correct — e.g. a concrete type's own unbounded fields,
or a callable struct's sole method) and needs one extra check per hit: does the
type being dispatched on declare a bound, for that parameter, that this
`where`-clause fails to repeat?

## When an axis becomes a type parameter (vs. stays an extracted trait)

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

## Dispatch via the trait (Holy trait pattern)

Extract the trait, then re-dispatch on it:

```julia
function process(x::AbstractThing)
    return _process(mode(x), x)        # extract, then re-dispatch
end

_process(::Type{Eager}, x) = ...       # eager branch
_process(::Type{Lazy},  x) = ...       # lazy branch
```

This is **type-stable** when the trait is a type parameter: `mode(x)` is known at
compile time, so the re-dispatch resolves statically; the extra call is inlined.

⚠️ Pitfall: extracting a trait from a *runtime value* (not encoded in the type) makes
the re-dispatch dynamic and breaks inference. Keep traits as type parameters.

## Interfaces and contracts

Define methods on abstract types; mark required ones with a `NotImplemented` stub so a
subtype that forgets them fails loudly.

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

# Generic code works with any subtype (LSP)
function optimize(m::AbstractModel, x0)
    v = evaluate(m, x0)   # safe for any model honoring the contract
    # ...
end
```

Rules:
- **Accept abstractions** in signatures (`build(::AbstractInput)`), not concrete types,
  so users can extend without editing core code (OCP/DIP).
- **Subtypes honor the contract** (LSP): same return shape across the hierarchy; test
  generic code against all subtypes.
- **Do not add an abstract type for a capability.** A capability (e.g. "supports AD")
  is a *trait*, not a node in the hierarchy — adding `AbstractThingWithAD` collides with
  the other axes under single inheritance.

## When concrete types are justified

Use a concrete type when the *data layout* genuinely differs (different fields), not to
encode an adjective. Two concrete types with identical fields that differ only by a flag
should be one parametric type with a trait parameter + aliases.

## SOLID / DRY / KISS / YAGNI (condensed)

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

## Type stability {#type-stability}

Type-stable = return type inferable from input types at compile time. Typically
10–100× faster than unstable code.

- **Parametric, concrete fields** — `struct C{T}; data::Vector{T}; end`, never
  `Vector{Any}` or an abstract field type.
- **`NamedTuple` over `Dict`** for fixed-key, mixed-type records.
- **No `Any` in hot paths**; avoid conditional return types
  (`Union{Int,Nothing}` from one function).
- **Function barriers** — isolate an unavoidable instability behind a typed inner
  function.
- **`const Ref(...)`** instead of mutable globals.

Verify:

```julia
@testset "type stability" begin
    @test_nowarn @inferred f(x)      # @inferred only on function calls, not field access
    @test (@allocated hot_path(x)) == 0
end
```

Type stability matters on critical paths (inner loops, numerics); it is secondary on
one-time setup, user-facing API, and error paths.

## Checklist

- [ ] One abstract type per noun; one trait-parameter per orthogonal axis.
- [ ] Trait extractor + alias per variant; dispatch via extracted trait.
- [ ] Every named type parameter (alias or `where`) repeats its original bound
      verbatim; unconstrained trailing parameters are left out of the braces
      instead of named unbounded.
- [ ] Contracts are `NotImplemented` stubs on abstract types.
- [ ] Signatures accept abstractions; subtypes honor the contract.
- [ ] No abstract type encoding a capability (use a trait).
- [ ] Concrete types only for genuinely different data layouts.
- [ ] Parametric concrete fields; no `Any` in hot paths; `@inferred` on critical calls.
