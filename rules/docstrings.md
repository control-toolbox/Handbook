# Docstrings

Every exported symbol *and* every internal component carries a docstring. Generic
templates below; use `DocStringExtensions` macros for signatures.

Identifiers: `DOC1`–`DOC8` (see [`README.md`](../README.md#rule-identifiers)).

Docstrings are **complete** (every function, struct, abstract type, macro, module),
**accurate** (actual behavior, never aspirational), **clear** (for readers fluent in
Julia but new to the domain) and **consistent** (they follow the templates).

---

## DOC1 — Directly above the declaration, signature by macro

**Rule.** Every function, struct, abstract type, macro and module has a docstring,
placed **immediately above** the declaration, no blank line in between. The signature
comes from a `DocStringExtensions` macro, never written by hand:

- `$(TYPEDEF)` — type signature for structs/abstract types.
- `$(TYPEDSIGNATURES)` — function signature with types.

**Why.** A hand-written signature drifts from the code; a macro-generated one cannot.

**Check.** `exact` (to be tooled, by introspection) for a missing docstring;
`exact` (syntactic) for a docstring without `$(TYPEDEF)` / `$(TYPEDSIGNATURES)`.

---

## DOC2 — The required structure, from the templates

**Rule.** A docstring has:

1. Signature via `$(TYPEDSIGNATURES)` (functions) or `$(TYPEDEF)` (types).
2. One-sentence summary.
3. Optional detail: behavior, constraints, invariants, edge cases.
4. Sections as applicable: `# Arguments`, `# Fields`, `# Returns`, `# Throws`,
   `# Example(s)`, `# Notes`, `# References`, and a `See also:` line. All arguments and
   fields are documented; returns and throws when relevant.

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

**Why.** One structure across the ecosystem: a reader knows where to find the
arguments, the return value and the errors of any symbol.

**Check.** `heuristic` (to be tooled): missing summary line, or an argument / field of
the signature absent from `# Arguments` / `# Fields`.

---

## DOC3 — Safe, reproducible examples

**Rule.** Examples must be safe, runnable and typical.

- ✅ pure deterministic computations, constructors with simple inputs, queries on
  created objects; start with `using RootPackage.SubModule`.
- ❌ file/network/DB/git operations, randomness without a seed, timing-dependent or
  long-running (>1s) code, reliance on external/global state.
- If no safe runnable example exists: use a plain ```julia block (not ```julia-repl)
  showing a conceptual usage pattern without claiming output.

**Why.** An example is run by readers, and by doctests: it must give the same result
everywhere, harmlessly.

**Check.** `signal` (to be tooled): `rand` without a seed, I/O or network calls inside a
`julia-repl` example; whether an example is typical is a `judgment`.

---

## DOC4 — Cross-references: `@ref` internal, `@extref` external, full paths

**Rule.**

- **Internal** (`@ref`): full module path including the root package.
  `[`MyPackage.SubA.do_thing`](@ref)` — not `[`do_thing`](@ref)`.
- **External** (`@extref`): symbols from a dependency with its own docs, full path.
  `[`OtherPkg.Sub.Sym`](@extref)`. Each must be backed by an `InterLinks` entry in
  `make.jl` ([`SITE4`](site.md)).

Use `@ref` for symbols documented in the current package, `@extref` for dependencies.

**Why.** A full path resolves unambiguously, and tells the reader where the target
lives.

**Check.** `exact` (to be tooled, syntactic): a `@ref` / `@extref` target without a
module path; broken links are caught by the docs build.

---

## DOC5 — Self-reference for extensible generics

**Rule.** For any cross-submodule reference inside a docstring on a symbol that other
packages might extend (shared accessors like `state`, `control`, `dual`, ...), use
`@extref MyPackage.Submodule.symbol` — self-referencing your own published inventory —
instead of `@ref`. Every such target is fully qualified (no bare names) and carries no
call-signature suffix (keep signature-disambiguated targets `@ref`). Requires a
self-referencing `InterLinks` entry; see
[`SITE5`](site.md#site5--self-reference-for-extensible-generics).

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

**Why.** A docstring on a generic that other packages are expected to extend is not
safe to treat as purely "internal", even though its target lives in the current
package. Julia docstrings attach to a *binding* (module + name), not to an individual
method. When a downstream package adds a new method to your generic, its docstring is
appended to the *same* accumulated doc object — there is no way to render "just this
package's part". Any `@docs` block on that generic, wherever it is written, renders the
full combined text. If your original docstring used `@ref` for a same-package
cross-reference, that `@ref` is carried into the downstream build verbatim — and `@ref`
only resolves against bindings documented in the *current* `makedocs()` build. The
downstream package never documents your other submodule's binding, so the link breaks
there, even though it resolves fine in your own docs. `@extref` resolves the same way
regardless of which package's build is rendering the (possibly transcluded) text.

**Caveats** — `@extref` resolves against a serialized inventory (`objects.inv`), not the
live in-build doc tree, so it is stricter than `@ref` in two ways:

- **No bare names.** `@extref` only matches an exact, fully-qualified entry in the
  inventory. `[`do_thing`](@extref)` silently fails to resolve even when `do_thing` is
  unambiguous in context; it must be `[`MyPackage.SubA.do_thing`](@extref)`. `@ref` is more
  forgiving here because it can fall back to Documenter's own in-build name resolution —
  which is exactly the behavior that doesn't carry over to a downstream build, so don't
  rely on it even where it happens to work locally.
- **No signature disambiguation.** When a generic has several methods each with their own
  docstring, `@ref` can pick one by its call signature (e.g.
  `` [`f(x::Int)`](@ref) `` vs. `` [`f(x::Float64)`](@ref) ``) by matching against the live
  doc tree. `@extref` cannot: the inventory indexes plain qualified names only, so a
  signature-suffixed target never resolves. If a `See also` needs to point at one specific
  overload among several on the same self-referencing generic, keep that particular
  reference `@ref` — it only ever needs to resolve within the package's own build, since
  the disambiguation is for readers of *this* package's docs, not for a downstream package
  extending the generic.

**Check.** `judgment` for which generics are meant to be extended; once that list is
known, `exact` (to be tooled) for a cross-submodule `@ref` in their docstrings.

---

## DOC6 — Functor call operators: one docstring per group

**Rule.** A **functor** (callable struct) that dispatches over several call signatures —
e.g. one method per `(TimeDependence, VariableDependence)` combination — must carry
**exactly one** docstring for the whole group, placed on the first method. Do **not**
add a docstring to each individual method.

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

**Why.** For `function (h::T{ConcreteA,ConcreteB,...})(args...) where {...}`, Julia's
`Base.Docs` keys the stored docstring on the method's `where`-clause, not on the
receiver's concrete type parameters or the argument list. Every dispatch variant that
shares the same `where` clause — which is the normal case for arity-dispatch functors —
collides on the *same* storage key, regardless of differing type parameters or arg
counts. Each subsequent docstring silently overwrites the previous one:

```text
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

This is a functor-specific exception to the "every method carries a docstring" default
([`DOC1`](#doc1--directly-above-the-declaration-signature-by-macro)): the group is
documented once, as a unit, because Julia's docsystem cannot distinguish the individual
call-operator methods by signature.

**Check.** `exact`: the `Replacing docs` warning at load time; to be tooled
(syntactic) as several docstrings on call operators of the same type.

---

## DOC7 — Module prefix in examples

**Rule.**

- Exported symbol after `using MyPackage.SubA`: call it bare (`do_thing(...)`).
- Internal symbol: prefix with the submodule (`SubA.helper(...)`).
- Public path shown in docs is always `RootPackage.SubModule.symbol`.

**Why.** The example shows exactly what a user can type, and where an internal symbol
comes from.

**Check.** `heuristic` (to be tooled): an unexported symbol called bare in an example.

---

## DOC8 — Accurate, consistent wording

**Rule.** Describe actual behavior, never aspirational or invented behavior; use the
same terms as the rest of the package's documentation.

**Why.** A docstring that promises what the code does not do is worse than none.

**Check.** `judgment`.
