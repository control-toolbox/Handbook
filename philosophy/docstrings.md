# Docstrings

Every exported symbol *and* every internal component carries a docstring. Generic
templates below; use `DocStringExtensions` macros for signatures.

## Principles

1. **Completeness** — document every function, struct, abstract type, macro, module.
2. **Accuracy** — describe actual behavior, never aspirational.
3. **Clarity** — for readers fluent in Julia but new to the domain.
4. **Consistency** — follow the templates.

Placement: **immediately above** the declaration, no blank line in between.

## Required structure

1. Signature via `$(TYPEDSIGNATURES)` (functions) or `$(TYPEDEF)` (types).
2. One-sentence summary.
3. Optional detail: behavior, constraints, invariants, edge cases.
4. Sections as applicable: `# Arguments`, `# Fields`, `# Returns`, `# Throws`,
   `# Example(s)`, `# Notes`, `# References`, and a `See also:` line.

## Templates (generic)

### Function

```julia
"""
$(TYPEDSIGNATURES)

One sentence describing what the function does.

# Arguments
- `a::TypeA`: description.
- `b::TypeB`: description.

# Returns
- `RetType`: description.

# Throws
- `ExceptionType`: when and why.

# Example
\`\`\`julia-repl
julia> using MyPackage.SubA

julia> do_thing(a, b)
expected_output
\`\`\`

See also: [`MyPackage.SubA.related`](@ref), [`MyPackage.SubB.Other`](@ref)
"""
function do_thing(a::TypeA, b::TypeB)::RetType
    # ...
end
```

### Struct

```julia
"""
$(TYPEDEF)

One sentence describing what this type represents.

# Fields
- `field1::Type1`: description and constraints.
- `field2::Type2`: description and constraints.

See also: [`MyPackage.SubA.related_type`](@ref)
"""
struct Thing{T}
    field1::Type1
    field2::T
end
```

### Abstract type

```julia
"""
$(TYPEDEF)

One sentence describing the abstraction.

# Interface Requirements

Subtypes must implement:
- `required_method(::SubType)`: description.

See also: [`MyPackage.SubA.ConcreteA`](@ref), [`MyPackage.SubA.ConcreteB`](@ref)
"""
abstract type AbstractThing end
```

## Functor call operators: one docstring per group

A **functor** (callable struct) that dispatches over several call signatures — e.g. one
method per `(TimeDependence, VariableDependence)` combination — must carry **exactly one**
docstring for the whole group, placed on the first method. Do **not** add a docstring to
each individual method.

```julia
"""
$(TYPEDSIGNATURES)

Call operators for [`MyPackage.SubA.Thing`](@ref), dispatching on the `(TD, VD)` trait
pair for the correct arity:

| `TD` / `VD` | Call signature | Effective call |
|---|---|---|
| `Auton` / `Fixed` | `f(x)` | `_core(h, 0, x, ∅)` |
| `NonAuton` / `Fixed` | `f(t, x)` | `_core(h, t, x, ∅)` |
| `Auton` / `NonFixed` | `f(x, v)` | `_core(h, 0, x, v)` |
| `NonAuton` / `NonFixed` | `f(t, x, v)` | `_core(h, t, x, v)` |
"""
function (h::Thing{Auton,Fixed,DF})(x) where {DF<:Function}
    return _core(h, 0.0, x, nothing)
end

# no docstring here — already covered by the table above
function (h::Thing{NonAuton,Fixed,DF})(t, x) where {DF<:Function}
    return _core(h, t, x, nothing)
end

function (h::Thing{Auton,NonFixed,DF})(x, v) where {DF<:Function}
    return _core(h, 0.0, x, v)
end

function (h::Thing{NonAuton,NonFixed,DF})(t, x, v) where {DF<:Function}
    return _core(h, t, x, v)
end
```

**Why**: for `function (h::T{ConcreteA,ConcreteB,...})(args...) where {...}`, Julia's
`Base.Docs` keys the stored docstring on the method's `where`-clause, not on the
receiver's concrete type parameters or the argument list. Every dispatch variant that
shares the same `where` clause — which is the normal case for arity-dispatch functors —
collides on the *same* storage key, regardless of differing type parameters or arg
counts. Each subsequent docstring silently overwrites the previous one:

```
┌ Warning: Replacing docs for `MyPackage.SubA.Thing :: Union{Tuple{DF}, Tuple{Any, Any}} where {DF<:Function}` in module `MyPackage.SubA`
└ @ Base.Docs docs/Docs.jl:249
```

This reproduces with a minimal callable struct:

```julia
struct T{A,B,DF} <: Function
    d::DF
end

"""doc1"""
function (h::T{AutonT,FixedT,DF})(x) where {DF<:Function} end

"""doc2"""  # ← triggers "Replacing docs for T", even though A/B differ
function (h::T{NonAutonT,FixedT,DF})(t, x) where {DF<:Function} end
```

Removing the second docstring (keeping only the first, with the dispatch table) makes
the warning disappear — there is no real duplication to fix, only one docstring to write.

This is a functor-specific exception to the "every method carries a docstring" default:
the group is documented once, as a unit, because Julia's docsystem cannot distinguish
the individual call-operator methods by signature.

## Cross-references

- **Internal** (`@ref`): full module path including the root package.
  `[`MyPackage.SubA.do_thing`](@ref)` — not `[`do_thing`](@ref)`.
- **External** (`@extref`): symbols from a dependency with its own docs, full path.
  `[`OtherPkg.Sub.Sym`](@extref)`. Each must be backed by an `InterLinks` entry in
  `make.jl`.

Use `@ref` for symbols documented in the current package, `@extref` for dependencies.

### Self-reference for extensible generics

A docstring on a generic function or type that **other packages are expected to
extend** (shared accessors like `state`, `control`, `dual`, ...) is not safe to treat
as purely "internal", even though its target lives in the current package.

**Why**: Julia docstrings attach to a *binding* (module + name), not to an individual
method. When a downstream package adds a new method to your generic, its docstring is
appended to the *same* accumulated doc object — there is no way to render "just this
package's part". Any `@docs` block on that generic, wherever it is written, renders the
full combined text. If your original docstring used `@ref` for a same-package
cross-reference, that `@ref` is carried into the downstream build verbatim — and `@ref`
only resolves against bindings documented in the *current* `makedocs()` build. The
downstream package never documents your other submodule's binding, so the link breaks
there, even though it resolves fine in your own docs.

**Rule**: for any cross-submodule reference inside a docstring on a symbol that other
packages might extend, use `@extref MyPackage.Submodule.symbol` — self-referencing your
own published inventory — instead of `@ref`. `@extref` resolves the same way regardless
of which package's build is rendering the (possibly transcluded) text. Requires a
self-referencing `InterLinks` entry; see
[`documentation.md`](documentation.md#self-reference-for-extensible-generics).

```julia
# ❌ breaks once a downstream package extends `state` and transcludes this docstring
"""
...
See also: [`MyPackage.Solutions.Solution`](@ref)
"""
function state(...) end

# ✅ resolves both locally and when transcluded into a downstream package's docs
"""
...
See also: [`MyPackage.Solutions.Solution`](@extref)
"""
function state(...) end
```

## Module-prefix convention in examples

- Exported symbol after `using MyPackage.SubA`: call it bare (`do_thing(...)`).
- Internal symbol: prefix with the submodule (`SubA.helper(...)`).
- Public path shown in docs is always `RootPackage.SubModule.symbol`.

## Example safety

Examples must be safe and reproducible.

- ✅ pure deterministic computations, constructors with simple inputs, queries on
  created objects; start with `using RootPackage.SubModule`.
- ❌ file/network/DB/git operations, randomness without a seed, timing-dependent or
  long-running (>1s) code, reliance on external/global state.
- If no safe runnable example exists: use a plain ```julia block (not ```julia-repl)
  showing a conceptual usage pattern without claiming output.

## Macros

- `$(TYPEDEF)` — type signature for structs/abstract types.
- `$(TYPEDSIGNATURES)` — function signature with types.

Use these instead of writing signatures by hand.

## Checklist

- [ ] Directly above the declaration; uses `$(TYPEDEF)`/`$(TYPEDSIGNATURES)`.
- [ ] One-sentence summary; all args/fields documented; returns and throws when relevant.
- [ ] Example is safe, runnable, and typical.
- [ ] `@ref` for internal, `@extref` for external; full module paths.
- [ ] Cross-submodule refs inside a docstring on an extensible generic use `@extref`
      (self-referencing), not `@ref`.
- [ ] No invented behavior; consistent terminology.
