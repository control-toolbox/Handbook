# Exceptions

Structured, informative errors. The ecosystem provides seven exception types under
`CTException`, brought into scope via `using CTBase: Exceptions`.

Identifiers: `EXC1`–`EXC5` (see [`README.md`](../README.md#rule-identifiers)).

A good error has a **clear message** (immediately understandable), an **actionable
suggestion** (how to fix it), **rich context** (what was expected, what was received,
where), and a **type** that lets callers catch precisely.

## The seven types

| Type | Key fields | Use when |
| --- | --- | --- |
| `IncorrectArgument` | `msg, got, expected, suggestion, context` | a single argument's value is out of domain |
| `PreconditionError` | `msg, reason, suggestion, context` | arguments valid individually, but the call's relation/state/timing is forbidden |
| `NotImplemented` | `msg, required_method, suggestion, context` | interface stub a subtype must implement |
| `ParsingError` | `msg, location, suggestion` | DSL / syntax / structure error |
| `AmbiguousDescription` | `description, candidates, suggestion, context` | a symbol-tuple description matches no catalogue entry |
| `ExtensionError` | `weakdeps, feature, context` | an optional (weak) dependency is not loaded |
| `SolverFailure` | `msg, retcode, suggestion, context` | a numerical solver/integrator failed |

---

## EXC1 — Typed, and the type follows the choice rule

**Rule.** Every error is one of the seven types — never an untyped `error(...)` — and
the type is chosen by:

> **`IncorrectArgument`** = "*this value* is wrong" (domain of **one** argument).
> **`PreconditionError`** = "*this combination / state / timing* is wrong" (a
> **relational** or contextual contract, each argument valid on its own).

Operational heuristic: if the message must mention **two things** ("x relative to y",
"this after that"), it is almost always `PreconditionError`. If it mentions **one**
value ("n must be > 0"), it is `IncorrectArgument`. An unimplemented contract is
`NotImplemented`; a missing optional dependency is `ExtensionError`.

```julia
using CTBase: Exceptions

# Single-argument domain violation
throw(Exceptions.IncorrectArgument(
    "dimension must be positive";
    got = "n = -1", expected = "n > 0",
    suggestion = "pass a positive integer for n",
    context = "make_thing",
))

# Relational / state violation
throw(Exceptions.PreconditionError(
    "cannot combine A with B";
    reason = "A carries x, B carries (x, p): the handoff is undefined",
    suggestion = "combine objects of the same kind",
    context = "composition",
))

# Interface stub on an abstract type
function run(s::AbstractStrategy, x)
    throw(Exceptions.NotImplemented(
        "run not implemented for $(typeof(s))";
        required_method = "run(::$(typeof(s)), x)",
        suggestion = "define run for your strategy type",
        context = "AbstractStrategy contract",
    ))
end

# Optional dependency missing (extension stub)
throw(Exceptions.ExtensionError(:SomeBackend; feature = "AD", context = "build"))

# Numerical failure
throw(Exceptions.SolverFailure(
    "integration failed"; retcode = ":Unstable",
    suggestion = "reduce the step or check initial conditions",
))
```

❌

```julia
error("something went wrong")                             # ❌ untyped, vague
throw(Exceptions.IncorrectArgument("already finalized"))  # ❌ should be PreconditionError
throw(Exceptions.PreconditionError("n must be > 0"))      # ❌ should be IncorrectArgument
```

**Why.** Callers can catch precisely, and the type alone tells the user whether to fix
a value or the way values are combined.

**Check.** `exact` (to be tooled) for untyped errors (`error(...)`,
`throw(ErrorException(...))`); the choice between types is a `judgment` — a reviewer
needs every `throw` site with its context.

---

## EXC2 — A clear message, with `got` / `expected` when applicable

**Rule.** The message is clear and specific; an `IncorrectArgument` sets `got` and
`expected`.

```julia
throw(Exceptions.IncorrectArgument("bad"))    # ❌ no got/expected/suggestion
```

**Why.** The user sees at once what was received and what was expected, without
reading the source.

**Check.** `signal` (to be tooled): an `IncorrectArgument` without `got` or `expected`.

---

## EXC3 — An actionable suggestion, and context for non-trivial errors

**Rule.** Set `suggestion` to say how to fix the error; set `context` (where it
happened) for any non-trivial error.

**Why.** An error is read by someone who wants to fix it: the suggestion is the fix,
the context is where to look.

**Check.** `signal` (to be tooled): a `throw` without `suggestion`.

---

## EXC4 — Fields valid for the chosen type

**Rule.** Use only the fields of the chosen type: `IncorrectArgument` has
`got`/`expected` (**no** `reason`); `PreconditionError` has `reason`.

**Why.** Using the wrong field is a tell that the type is wrong
([`EXC1`](#exc1--typed-and-the-type-follows-the-choice-rule)).

**Check.** `exact` (to be tooled, syntactic): keyword arguments match the fields of the
constructed type.

---

## EXC5 — Covered by a test

**Rule.** Every error path is covered by a `@test_throws` on its type; check the message
when it matters.

```julia
Test.@test_throws Exceptions.IncorrectArgument bad_call()

err = try bad_call() catch e; e end
Test.@test err isa Exceptions.IncorrectArgument
Test.@test occursin("must be positive", err.msg)
```

**Why.** An untested error path regresses silently — to the wrong type, or to no error
at all. See also [`TST5`](testing.md).

**Check.** `signal` (to be tooled): an exception type thrown in `src/` that no
`@test_throws` in `test/` mentions; per-site coverage is shown by the coverage report.
