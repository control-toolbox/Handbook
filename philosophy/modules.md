# Modules and qualification

Submodule organization and import rules (`using` only — never `import`). Generic
examples.

## Principles

1. **One submodule per responsibility**, in its own directory `src/<Name>/<Name>.jl`.
2. **Package manifest exports nothing**: the top-level file only `include`s the
   submodules and `using .Submodule`; it **exports nothing**.
3. **Each submodule exports its public API**; internal helpers stay unexported and are
   reached via full qualification.
4. **`using`, never `import`**: a single keyword for every dependency; method
   extensions are consequently always qualified.
5. **Qualified external imports**: `using Pkg: Pkg` or `using Pkg: Sub`, never a bare
   `using Pkg`.
6. **Qualification everywhere**: call `Sub.function` / `Sub.Type`, never rely on
   implicit scope.
7. **One-way dependency flow (DAG)**: a low module never depends on a high one; no
   cycles.

## `using`, never `import`

`import` is **not used anywhere** in the ecosystem — sources, tests, and documentation
cells alike. The two keywords have almost the same syntax and almost the same reach,
which makes the one place where they differ a trap rather than a feature: after
`import Mod: f`, writing `f(::T) = ...` extends `Mod.f` with no visible mention of
`Mod`, while the same line after `using Mod: f` is rejected outright:

```
invalid method definition in M: function Mod.f must be explicitly imported to be extended
```

So `using`-only makes every extension qualified — the same rule already in force at
call sites:

```julia
using LinearAlgebra: LinearAlgebra

Base.show(io::IO, x::Thing) = print(io, "Thing")   # ✅ origin visible
LinearAlgebra.norm(x::Thing) = 1.0                 # ✅ origin visible
```

Translation table:

| Instead of | Write |
|---|---|
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

## The submodule manifest

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

Order: docstring → `module` → external imports → sibling imports → `include`s →
`export`s → `end`.

## `using` styles (by preference)

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
import CTBase: Exceptions               # ❌ `import` is never used
```

## Sibling imports

```julia
using ..Lower                     # call Lower.f(...)
using ..Core: Core as CTCore      # alias on conflict or for readability
using ..Core: AbstractTag         # single pervasive symbol (often an abstract type)
```

## Qualification at call sites

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

Why: visible origin, safe refactors (only the `using ..X` line changes), no accidental
shadowing, same rule for external and sibling symbols.

## Naming conventions

Three visibility levels, signalled by the name itself:

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

## Two-level exports

- **Submodule**: `export` for its public API; internals (`_helper`, `__default`) unexported.
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

## Dependency DAG

The loading order in the top-level manifest follows a topological sort. A module may
`using ..Lower` only if `Lower` is already loaded. **No cycles**: if two modules need
each other, extract the shared concept into a lower module (`Core`).

## Checklist

- [ ] One submodule = one directory + one same-named manifest.
- [ ] Manifest = docstring, `module`, imports, `include`s, `export`s, `end` — nothing else.
- [ ] No `import` anywhere; extensions written qualified (`Base.show`, `Mod.f`).
- [ ] External imports: `using Pkg: Pkg` / `using Pkg: Sub` / (macros) `using Pkg: m`.
- [ ] Sibling imports: `using ..Sib` / `using ..Sib: Sib as A` / `using ..Sib: Sym`.
- [ ] Every external/sibling symbol is qualified at the call site.
- [ ] Acyclic DAG respected by the loading order.
- [ ] Each submodule exports its API; the package top-level exports nothing.
