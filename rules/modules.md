# Modules and qualification

Submodule organization, imports, qualification, exports and dependency order.
Generic examples.

Identifiers: `MOD1`–`MOD9` (see [`README.md`](../README.md#rule-identifiers)).

---

## MOD1 — One submodule per responsibility, one directory, one manifest

**Rule.** Each submodule has a single responsibility and lives in its own directory,
with a manifest named after it: `src/<Name>/<Name>.jl`.

**Why.** The file tree mirrors the module tree: a reader finds a module's code, and a
module's role, from its name alone.

**Check.** `exact` (to be tooled): every submodule declared by the package is defined
in `src/<Name>/<Name>.jl`.

---

## MOD2 — The manifest only declares

**Rule.** A submodule manifest contains, in this order: docstring → `module` →
external imports → sibling imports → `include`s → `export`s → `end`. Nothing else —
definitions live in the included files.

Canonical structure of `src/<Name>/<Name>.jl`:

```julia
"""
Module docstring — role, responsibilities, dependencies.
"""
module Name

# 1. External-package imports (qualified)
using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES     # macros: symbol form tolerated
using CTBase: Exceptions                                # qualifies Exceptions.*
using SomePackage: SomePackage                          # call SomePackage.*

# 2. Sibling-submodule imports
using ..Lower
using ..Other: Other as OtherAlias
using ..Core: AbstractTag                               # pervasive symbol only

# 3. Includes (internal dependency order)
include(joinpath(@__DIR__, "abstract_types.jl"))
include(joinpath(@__DIR__, "concrete.jl"))

# 4. Exports — public API only
export AbstractThing, Thing
export build_thing

end # module Name
```

**Why.** The manifest is the module's table of contents: its dependencies, its files
and its public API, readable at a glance.

**Check.** `exact` (to be tooled): the top-level statements of the manifest are of the
listed kinds, in the listed order.

---

## MOD3 — No `import`

**Rule.** `import` is **not used anywhere** in the ecosystem — sources, tests, and
documentation cells alike. Every dependency comes into scope with `using`, and method
extensions are therefore always written qualified.

**Why.** The two keywords have almost the same syntax and almost the same reach,
which makes the one place where they differ a trap rather than a feature: after
`import Mod: f`, writing `f(::T) = ...` extends `Mod.f` with no visible mention of
`Mod`, while the same line after `using Mod: f` is rejected outright:

```text
invalid method definition in M: function Mod.f must be explicitly imported to be extended
```

So `using`-only makes every extension qualified — the same rule already in force at
call sites ([`MOD6`](#mod6--qualification-at-call-sites)):

```julia
using LinearAlgebra: LinearAlgebra

Base.show(io::IO, x::Thing) = print(io, "Thing")   # ✅ origin visible
LinearAlgebra.norm(x::Thing) = 1.0                 # ✅ origin visible
```

Translation table:

| Instead of | Write |
| --- | --- |
| `import Pkg` | `using Pkg: Pkg` |
| `import Pkg.Sub` | `using Pkg: Sub` |
| `import Pkg: sym1, sym2` | `using Pkg: sym1, sym2` |
| `import ..Sib as Alias` | `using ..Sib: Sib as Alias` |
| `import Mod: f` then `f(::T) = …` | `using Mod: Mod` then `Mod.f(::T) = …` |

Two points that are easy to get wrong:

- `using Pkg: Sub` binds **only** the name `Sub` — it does *not* pull `Sub`'s `export`s
  into scope (unlike `using Pkg.Sub`). It is a faithful replacement for `import Pkg.Sub`.
- Aliasing must go through the `: name as Alias` form. Plain `using ..Sib as Alias`
  does not parse: `ERROR: "using" with "as" renaming requires a ":" and context module`.

This follows [Blue Style](https://github.com/invenia/BlueStyle#module-imports), which
prefers `using` over `import` "to ensure that extension of a function is always explicit
and on purpose"; the ecosystem rule additionally drops Blue Style's `import` escape hatch.

**Check.** `exact` (to be tooled, syntactic). Measure meanwhile:

```bash
grep -rnE '^\s*import\s' --include='*.jl' src ext test docs
```

---

## MOD4 — Qualified external imports

**Rule.** An external package comes into scope by **name**, not by its exports:

```julia
using SomePackage: SomePackage   # ✅ preferred: only the name enters scope
using CTBase: Exceptions         # ✅ qualifies the submodule, no export leakage
using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES  # ✅ reserved for macros / pervasive symbols
```

Forbidden:

```julia
using SomePackage                       # ❌ pollutes scope
using CTBase: AbstractModel, validate   # ❌ opaque origin at call sites
using CTBase.Exceptions                 # ❌ also brings Exceptions' exports into scope
```

**Why.** Only the module name enters scope, so every use of an external symbol names
its origin ([`MOD6`](#mod6--qualification-at-call-sites)).

**Check.** `exact` (to be tooled) for a bare `using Pkg` and for the dotted form
`using Pkg.Sub`; `signal` for `using Pkg: sym` on a non-macro symbol — whether the
symbol is pervasive enough is a `judgment`.

---

## MOD5 — Sibling imports

**Rule.** A sibling submodule comes into scope by name, optionally aliased; a single
symbol is imported only when it is pervasive (often an abstract type):

```julia
using ..Lower                     # call Lower.f(...)
using ..Core: Core as CTCore      # alias on conflict or for readability
using ..Core: AbstractTag         # single pervasive symbol (often an abstract type)
```

**Why.** Same reason as [`MOD4`](#mod4--qualified-external-imports): the origin of a
sibling symbol stays visible, and a refactor only changes the `using ..X` line.

**Check.** `signal` (to be tooled) for a symbol imported from a sibling; whether it is
pervasive is a `judgment`.

---

## MOD6 — Qualification at call sites

**Rule.** Call `Sub.function` / `Sub.Type`; never rely on implicit scope. The same rule
holds for external and sibling symbols.

```julia
# ✅ explicit origin at every call
function Strategies.metadata(::Type{<:Modelers.ADNLP})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(name=:backend, type=Symbol, default=:auto),
    )
end

# ❌ where do StrategyMetadata, OptionDefinition come from?
function metadata(::Type{<:ADNLP})
    return StrategyMetadata(OptionDefinition(name=:backend, type=Symbol))
end
```

**Why.** Visible origin, safe refactors (only the `using ..X` line changes), no
accidental shadowing.

**Check.** `heuristic` (to be tooled): requires resolving names, i.e. loading the
package; [ExplicitImports.jl](https://github.com/JuliaTesting/ExplicitImports.jl)
covers part of it.

---

## MOD7 — One-way dependency flow (DAG)

**Rule.** A low module never depends on a high one, and there are no cycles. The
loading order in the top-level manifest follows a topological sort: a module may
`using ..Lower` only if `Lower` is already loaded. If two modules need each other,
extract the shared concept into a lower module (`Core`).

**Why.** Each layer can be understood, tested and documented without the layers above
it.

**Check.** `exact` (to be tooled): the graph of sibling `using ..X` is acyclic and
consistent with the `include` order.

---

## MOD8 — Two-level exports

**Rule.**

- **Submodule**: `export` for its public API; internals (`_helper`, `__default`)
  stay unexported and are reached via full qualification.
- **Package (top-level)**: **no** `export`. Load submodules with `using .Submodule`;
  users reach them via `Package.Submodule.sym`.

```julia
module MyPackage
include(joinpath(@__DIR__, "Core", "Core.jl"));       using .Core
include(joinpath(@__DIR__, "Systems", "Systems.jl")); using .Systems
# NO exports here.
end
```

User access:

```julia
using MyPackage                  # brings no symbols into scope
MyPackage.Systems.AbstractThing  # qualified (recommended)

using MyPackage.Systems          # opt-in: brings Systems exports into scope
AbstractThing                    # unqualified, the user's choice
```

**Why.** Loading the package never pollutes the user's scope; bringing a submodule's
API into scope is the user's explicit choice.

**Check.** `exact` (to be tooled): the package module exports nothing
(`names(MyPackage)` is only the module itself).

---

## MOD9 — Naming signals visibility

**Rule.** Three visibility levels, signalled by the name itself:

- `symbol` — **public**: exported via `export`; part of the documented API.
- `_symbol` — **private helper**: unexported; internal implementation detail.
  Accessible via qualified path (`Module._symbol`) but not advertised.
- `__symbol` — **default value**: unexported; provides a replaceable semantic
  default (e.g. `__display() = true`). The double underscore distinguishes it
  from a plain helper: it is a *default* that a higher-level layer may override,
  not merely a utility function.

```julia
export build_thing           # public

function _validate(x)        # private helper
    ...
end

__verbose()::Bool = false    # default value (replaceable by extension or subtype)
```

**Why.** A reader knows, from the name alone, whether a symbol is API, internal, or a
default meant to be overridden.

**Check.** `exact` (to be tooled): no exported name starts with `_`. Whether a private
symbol is a helper or a default is a `judgment`.
