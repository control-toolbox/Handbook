# Migration from Documenter to DocumenterVitepress

## Migration Steps

### 1. Update dependencies

File **docs/Project.toml**

- Add `DocumenterVitepress` (UUID: `4710194d-e776-4893-9690-8d956a29c365`)
- Add `LiveServer` for local preview
- Keep `Documenter` as a dependency

Keep all existing `[deps]` entries — only add the three new packages:

```toml
[deps]
# ... existing dependencies unchanged ...
DocumenterVitepress = "4710194d-e776-4893-9690-8d956a29c365"
LiveServer = "16fef848-5104-11e9-1b77-fb7a48bbb589"

[compat]
# ... existing compat entries unchanged ...
DocumenterVitepress = "0.3"
LiveServer = "1"
```

### 2. Modify make.jl

File **docs/make.jl**

- Add usage comments at the top (how to run and serve)
- Add `using DocumenterVitepress`
- Replace `format=Documenter.HTML(...)` with `format=DocumenterVitepress.MarkdownVitepress(...)`
- Replace `deploydocs` with `DocumenterVitepress.deploydocs`

```julia
# to run the documentation generation: julia --project=. docs/make.jl
# to serve the documentation (option 1 — handles clean URLs natively):
#   npx serve docs/build/1 --listen 5173
# to serve the documentation (option 2 — Julia only):
#   julia --project=docs -e 'using LiveServer; LiveServer.serve(dir="docs/build/1", single_page=true)'
# note: single_page=true is required so that reloading /getting-started serves the correct HTML

using Documenter
using DocumenterVitepress

makedocs(;
    # ... other arguments ...
    format=DocumenterVitepress.MarkdownVitepress(;
        repo="github.com/MyOrg/MyPackage.jl",  # no https:// prefix — DocumenterVitepress adds it
        devbranch="main",
        devurl="dev",
        sidebar_drawer=true,
    ),
    pages=[
        # Do NOT list index.md here — it is automatically the root page at /
        # Adding it as "Introduction" => "index.md" creates a duplicate /index entry
        # in the sidebar and causes the Next page link from / to loop back to /index
        # instead of going to the first real page.
        # ⚠️  If your existing pages= list has an "Introduction" => "index.md" entry, remove it.
        "Getting Started" => "getting-started.md",
        # ...
    ],
)

DocumenterVitepress.deploydocs(;
    repo="github.com/MyOrg/MyPackage.jl.git",
    devbranch="main",
    push_preview=true,
)
```

> **Note — wrapped `makedocs`**: some packages wrap `makedocs` in a helper (e.g.
> `with_api_reference(...) do api_pages ... makedocs(...) end`). In that case, add the
> `format=` argument inside the inner `makedocs` call, and replace `deploydocs` with
> `DocumenterVitepress.deploydocs` after the wrapper block.

### 3. Install Julia dependencies

After editing `docs/Project.toml`, resolve and instantiate (the Manifest must be regenerated to include the new packages):

```bash
julia --project=docs -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
```

### 4. Generate Vitepress configuration files

`generate_template` requires `DocumenterVitepress` to be installed (step 3 must be done first).

```bash
julia --project=docs -e 'using DocumenterVitepress; DocumenterVitepress.generate_template("docs", "MyPackage")'
```

Replace `"MyPackage"` with the actual package name (e.g. `"CTModels"`, `"CTFlows"`).

This creates the following files (do not create them manually):

In `docs/src/`:

- `.vitepress/config.mts` - Main Vitepress configuration
- `.vitepress/theme/index.ts` - Theme customization
- `.vitepress/theme/style.css` - Custom CSS styles
- `.vitepress/theme/docstrings.css` - Docstring block styles
- `.vitepress/mathjax-plugin.ts` - MathJax plugin
- `.vitepress/julia-repl-transformer.ts` - Julia REPL transformer
- `components/VersionPicker.vue` - Version picker navbar component
- `components/SidebarDrawerToggle.vue` - Sidebar collapse toggle
- `components/AuthorBadge.vue` - Author badge component
- `components/Authors.vue` - Authors list component

At the root of `docs/`:

- `package.json` - npm dependencies
- `.gitignore` - ignores `build/`, `node_modules/`, `package-lock.json`, `Manifest.toml`

### 5. Patch config.mts

Two mandatory changes in `docs/src/.vitepress/config.mts` — neither is generated correctly by `generate_template`.

#### 5a. Replace nav placeholder with a direct definition

The generated file spreads from a `navTemp.nav` placeholder that is **not** replaced at build time.
Replace it with a direct array:

Replace:

```typescript
const navTemp = {
  nav: 'REPLACE_ME_DOCUMENTER_VITEPRESS',
}

const nav = [
  ...navTemp.nav,
  {
    component: 'VersionPicker'
  }
]
```

With:

```typescript
const nav = [
  { text: 'Home', link: '/index' },
  { component: 'VersionPicker' }
]
```

Replace `'Home'` and `'/index'` with the appropriate label and root link for your package.

#### 5b. Add control-toolbox remote assets to the head

The generated `head` block is missing the control-toolbox CSS and JS. Replace it:

Replace:

```typescript
head: [
  ['link', { rel: 'icon', href: 'REPLACE_ME_DOCUMENTER_VITEPRESS_FAVICON' }],
  ['script', {src: `${getBaseRepository(baseTemp.base)}versions.js`}],
  ['script', {src: `${baseTemp.base}siteinfo.js`}]
],
```

With:

```typescript
head: [
  ['link', { rel: 'icon', href: 'REPLACE_ME_DOCUMENTER_VITEPRESS_FAVICON' }],
  ['link', { rel: 'stylesheet', href: 'https://control-toolbox.org/assets/css/vitepress-documentation.css' }],
  ['script', {src: `${getBaseRepository(baseTemp.base)}versions.js`}],
  ['script', {src: 'https://control-toolbox.org/assets/js/vitepress-documentation.js'}],
  ['script', {src: `${baseTemp.base}siteinfo.js`}]
],
```

The two added lines load the shared control-toolbox stylesheet and JavaScript from the remote CDN.
Without them, the documentation will render without the organization's theme.

#### Option A: Local assets (for development only)

If assets are not yet published remotely, use local files placed in `docs/src/assets/`. Add a Vite plugin in the `vite.plugins` section of `config.mts` to copy them at build time:

```typescript
import { copyFileSync, mkdirSync } from 'fs'

let ctOutDir = ''

// inside vite.plugins:
{
  name: 'ct-static-assets',
  apply: 'build' as const,
  configResolved(config: any) {
    if (!config.build.ssr) ctOutDir = config.build.outDir
  },
  closeBundle() {
    if (!ctOutDir) return
    const assetsDir = path.join(ctOutDir, 'assets')
    mkdirSync(assetsDir, { recursive: true })
    for (const file of [
      'vitepress-documentation.css',
      'vitepress-documentation.js',
    ]) {
      try { copyFileSync(path.resolve(__dirname, '../assets', file), path.join(assetsDir, file)) } catch (_) {}
    }
  }
},
```

And reference them in `head` using `${baseTemp.base}assets/...` instead of the remote URLs.

### 6. Install npm dependencies

```bash
cd docs && npm install
```

### 7. Local build and preview

```bash
# Generate documentation
julia --project=docs docs/make.jl

# Local preview — option 1: npx serve (recommended, handles clean URLs natively)
# Output is in docs/build/1/, not docs/build/
npx serve docs/build/1 --listen 5173

# Local preview — option 2: Julia LiveServer
# single_page=true is required: without it, reloading any page other than / returns a blank page
# because VitePress uses clean URLs (/getting-started maps to getting-started.html, not a directory)
julia --project=docs -e 'using LiveServer; LiveServer.serve(dir="docs/build/1", single_page=true)'
```

> **Why `single_page=true`?** VitePress builds with `cleanUrls: true`, generating `getting-started.html`
> for the URL `/getting-started`. A plain static server returns 404 for that URL on hard reload.
> With `single_page=true`, LiveServer falls back to serving `index.html` for unknown URLs, letting
> the VitePress router handle the rest. `npx serve` avoids this issue by trying `<path>.html` automatically.

## Important notes

- **`@repl` vs `@example` — ANSI color rule**: Before `DocumenterVitepress` **v0.3.5**, ANSI-colored output from `@repl` was emitted as a ` ```julia ` fence and rendered as raw escape sequences. This limitation was fixed in v0.3.5 ([#373](https://github.com/LuxDL/DocumenterVitepress.jl/pull/373)): colored `@repl` output is now rendered as ANSI while the input remains Julia syntax-highlighted.

  | Block type | Behaviour in `DocumenterVitepress` v0.3.5+ | Recommended use |
  | --- | --- | --- |
  | `@example` | ANSI output is rendered correctly | Evaluated examples without REPL formatting |
  | `@repl` | Colored output is rendered correctly; input remains REPL-highlighted | Interactive examples, including colored `show` output |
  | `@ansi` | Intended for examples whose terminal ANSI output is the focus | Explicit ANSI / terminal-output demonstrations |

  For **v0.3.5 and later**:

  - Use **`@repl`** for interactive examples, including values displayed by a custom ANSI-colored `show` method.
  - Use **`@example`** when the example is better represented as a regular evaluated example; no change is needed when its output already renders correctly.
  - Use **`@ansi`** when the example explicitly demonstrates terminal styling or raw ANSI output.
  - Use **`@repl`** + `try/catch # hide` + `showerror(IOContext(stdout, :color => false), e) # hide` for exceptions when a stable, colorless error message is desired. This is a presentation choice, not a workaround required by v0.3.5+:

    ```julia
    try
        # ... your code that may throw ...
    catch e
        showerror(IOContext(stdout, :color => false), e) # hide
    end # hide
    ```

  For **versions before v0.3.5**, use `@example` or `@ansi` for colored output, or disable colors explicitly as above. The old limitation was tracked in [LuxDL/DocumenterVitepress.jl#321](https://github.com/LuxDL/DocumenterVitepress.jl/issues/321).

- **Color-aware display functions**: If your package has custom display functions that emit ANSI escape codes (e.g. error formatting helpers), make them color-aware by checking `get(io, :color, false)` before applying escape sequences:

  ```julia
  _apply_ansi(s, code, io::IO) = get(io, :color, false) ? "\033[$(code)m$(s)\033[0m" : s
  ```

  Propagate the `io` argument through all display helpers so that:
  - REPL / GitHub Actions → colors enabled (`:color => true` by default)
  - Documenter / VitePress → plain text when wrapped with `IOContext(stdout, :color => false)`

- **Plot image format — SVG vs PNG**: DocumenterVitepress selects the output format for
  `@example` block plots by picking the MIME type with the **highest priority** among those
  the plotting library supports:

  | MIME type | Priority |
  | --- | --- |
  | `image/svg+xml` | 3.0 |
  | `image/png` | 4.0 |

  PNG wins by default. This is the **opposite** of `Documenter.HTML`, which prefers SVG.

  **Both `Plots.jl` and `CairoMakie` respond to `image/png`**, so PNG wins for every figure
  unless you disable PNG capture. Do it once, globally, in `make.jl` — before any `@example`
  block runs, so it covers every page present and future (`Base.showable` is a method on the
  figure type):

  ```julia
  using Plots
  import CairoMakie   # `import`, not `using`: `using` pulls Makie's `plot` / `plot!` into
                      # Main, colliding with Plots' and breaking any bare-`plot` `@docs` block
  Base.showable(::MIME"image/png", ::Plots.Plot) = false
  CairoMakie.activate!(; type = "svg")
  Base.showable(::MIME"image/png", ::CairoMakie.Makie.Figure) = false
  ```

  DocumenterVitepress then falls back to `image/svg+xml` and saves each figure as a separate
  `.svg` file (referenced via `![](filename.svg)`). Plots' GR backend and CairoMakie both
  emit standalone SVG with the `xmlns` attribute, which is what DocumenterVitepress needs.

  If you only plot on a few pages, the `Base.showable` line can instead go in a per-page
  `@setup` block — but the global form is simpler and does not have to be repeated.

  Older guidance said CairoMakie "produces SVG automatically, no action needed" — that is
  **not true** with current CairoMakie (0.15): it responds to `image/png` like Plots does.

  Note: `Plots.default(fmt=:svg)` has **no effect** on MIME type selection — it only
  controls the format used when Plots saves to a file path, not how Documenter captures
  the result.

- **Git repository required**: DocumenterVitepress requires a git repository to function
- **Build output**: Documentation is generated in `docs/build/1/` (not `docs/build/`)
- **Do not create Vitepress files manually**: always use `generate_template` (step 4) — it generates all config, theme, components, and npm files
- **Symlinks**: Before deployment, remove symlinks on the `gh-pages` branch (stable, v1, etc.)

  Documenter.jl uses symlinks on the `gh-pages` branch to manage documentation versions:

  - `stable` → points to the current stable version (e.g., `v0.5.0`)
  - `v1` → points to the latest major version
  - `v0.1`, `v0.2`, etc. → point to specific versions

  DocumenterVitepress cannot write to symlinks. If you are migrating from an existing Documenter documentation, your `gh-pages` branch likely contains these symlinks. They must be manually removed before the first deployment with DocumenterVitepress.

  **How to remove symlinks:**

  1. Go to GitHub: `https://github.com/<org>/<package>/tree/gh-pages`
  2. Symlinks are identifiable by a small arrow ↗
  3. Click on each symlink (stable, v1, etc.)
  4. Delete them via the context menu

  DocumenterVitepress handles versions differently, without using symlinks.
- **Vitepress configuration**: The `REPLACE_ME_DOCUMENTER_VITEPRESS` strings are automatically replaced during the build
- **TypeScript errors**: TypeScript errors in the IDE regarding `sidebar` and missing `node_modules` are normal before `npm install` — DocumenterVitepress replaces these values during the build

## Presenting code

VitePress gives fenced code blocks a set of annotations Documenter's Markdown does not. They
render through DocumenterVitepress and are worth using where they make a snippet read better.

| Feature | Syntax (trailing comment on the line, or on the fence) | Renders |
| --- | --- | --- |
| diff add / remove | `# [!code ++]` / `# [!code --]` | green / red gutter with `+` / `-` |
| error line | `# [!code error]` | red-tinted line |
| warning line | `# [!code warning]` | amber-tinted line |
| highlight | `# [!code highlight]`, or `` ```julia {2,5-7} `` on the fence | tinted background |
| focus | `# [!code focus]` | dims the rest, reveals on hover |
| line numbers | `` ```julia:line-numbers `` | gutter numbering |
| code group | `::: code-group` … `:::` around several fences | tabbed switcher |

The `[!code …]` token is stripped from the rendered comment, so it can sit after real text:
`# paired keywords  [!code ++]` renders as `# paired keywords` on a line marked added.

**Hard constraint — static fences only.** These annotations are reliable only in
non-executed ```` ```julia ```` / ```` ```julia-repl ```` / ```` ```text ```` fences.
There is no support for them inside executed `@example` / `@repl` / `@setup` blocks (the
CSP + transform path drops them). Never annotate a build-verified example. They do work
inside `!!! note` / `!!! warning` admonitions (verified: OptimalControl.jl `migration.md`).

**Before/after — collapse the pair.** A "write this instead of that" shown as two blocks
becomes one:

````markdown
```julia
f(t0, x0, tf, λ)                    # [!code --]
f(t0, x0, tf; variable=λ)           # [!code ++]
```
````

**Do not use a code group for a correspondence pair.** A `::: code-group` is a tabbed
switcher — the reader sees one block at a time. That fits genuine *either/or* alternatives
(`using Plots` vs `using CairoMakie`), never a pair whose point is the line-to-line mapping
(a DSL macro shown next to the function calls it expands to, a before/after). Keep those
stacked and both visible, with the prose that ties them together.

## Canonical api_reference.jl structure

> This section is independent of the Vitepress migration. It documents the evolved
> `api_reference.jl` pattern used in CTFlows.jl and CTModels.jl, which supersedes the
> older CTBase pattern.

### What changed

The original CTBase pattern has three problems:

- It generates a separate catch-all **Internals** page that mixes symbols from all modules
  — poor discoverability, no module context.
- `with_api_reference` only accepts `src_dir` and derives `ext_dir` internally — fragile
  if the layout ever changes.
- A `modules_config` array + comprehension loop is clever but harder to read and maintain.

The newer pattern (CTFlows, CTModels) fixes all three:

| Aspect | Old (CTBase) | New (CTFlows / CTModels) |
| --- | --- | --- |
| Public vs private | Two-tier: public pages + one Internals page | `public=true, private=true` per module — one page per module |
| Extension dir | Derived internally from `src_dir` | Passed explicitly as `ext_dir` |
| Extensions | Aggregated in Internals page | Conditional `if !isnothing(ext)` push, or grouped into parent page |
| Page generation | `modules_config` loop | One explicit `CTBase.automatic_reference_documentation` call per page |
| `_cleanup_pages` | Module-level function | Local function inside `with_api_reference` |

### Canonical structure

```julia
# ==============================================================================
# MyPackage API Reference Manager
#
# One CTBase.automatic_reference_documentation call per documented page.
# Keep the file lists in sync with src/<Submodule>/ and ext/ when files
# are added, removed, or renamed.
# ==============================================================================

function generate_api_reference(src_dir::String, ext_dir::String)
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]
    ext(files...) = [abspath(joinpath(ext_dir, f)) for f in files]

    EXCLUDE_BASE = Symbol[:include, :eval]

    # Pre-load optional extensions (may be nothing if the weak dep is not loaded)
    MyPackageExt = Base.get_extension(MyPackage, :MyPackageExt)

    pages = [
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                MyPackage.SubmoduleA => src(
                    joinpath("SubmoduleA", "SubmoduleA.jl"),
                    joinpath("SubmoduleA", "types.jl"),
                    # ...
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true, private=true,   # ← both on the same page
            title="SubmoduleA",
            title_in_menu="SubmoduleA",
            filename="api_submodule_a",
        ),
        # ... one block per module ...
    ]

    # Conditional extension page
    if !isnothing(MyPackageExt)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[MyPackageExt => ext("MyPackageExt.jl")],
            external_modules_to_document=[MyPackage],
            exclude=EXCLUDE_BASE,
            public=true, private=true,
            title="MyExt Extension",
            title_in_menu="MyExt",
            filename="ext_myext",
        ))
    end

    return pages
end

function with_api_reference(f::Function, src_dir::String, ext_dir::String)
    pages = generate_api_reference(src_dir, ext_dir)
    try
        f(pages)
    finally
        docs_src = abspath(joinpath(@__DIR__, "src"))
        function cleanup(pages)
            for p in pages
                content = last(p)
                if content isa AbstractString
                    fname = endswith(content, ".md") ? content : content * ".md"
                    full_path = joinpath(docs_src, fname)
                    isfile(full_path) && rm(full_path)
                elseif content isa Vector
                    cleanup(content)
                end
            end
        end
        cleanup(pages)
    end
end
```

Then in `make.jl`, pass both directories:

```julia
src_dir = abspath(joinpath(@__DIR__, "..", "src"))
ext_dir = abspath(joinpath(@__DIR__, "..", "ext"))

with_api_reference(src_dir, ext_dir) do api_pages
    makedocs(; ..., pages=["API Reference" => api_pages])
end
```

### Grouping extensions into a parent page

When an extension is tightly coupled to a module (e.g. a Plots extension for a Display
module), it can be listed as an additional entry in `primary_modules` of the parent page
instead of getting its own page:

```julia
CTBase.automatic_reference_documentation(;
    subdirectory="api",
    primary_modules=[
        MyPackage.Display => src(joinpath("Display", "Display.jl"), ...),
        MyPackagePlots    => ext("CTMyPackagePlots.jl", ...),    # ← grouped here
    ],
    external_modules_to_document=[Plots],
    exclude=EXCLUDE_BASE,
    public=true, private=true,
    title="Display & Plots",
    title_in_menu="Display & Plots",
    filename="api_display",
),
```

## Deployment

Deployment is done automatically via CI with `DocumenterVitepress.deploydocs`. Ensure that:

- The GitHub repository exists
- The `gh-pages` branch does not contain symlinks
- CI workflows are configured for DocumenterVitepress

### Restrict the workflow to stable tags only

By default a documentation workflow triggers on `tags: '*'`, which includes prerelease
tags such as `v0.26.0-beta`. DocumenterVitepress does **not** deploy prereleases when a
higher stable version with the same major.minor already exists (e.g. `v0.26.0` already
in the registry → `v0.26.0-beta` produces 0 VitePress bases). This causes `deploydocs`
to crash because it expects a `bases.txt` file that was never written.

Restrict the tag trigger to stable versions only in `.github/workflows/Documentation.yml`:

```yaml
on:
  push:
    branches:
      - main          # deploys to the `dev/` subfolder
    tags:
      - 'v[0-9]+\.[0-9]+\.[0-9]+'   # v0.26.0 yes, v0.26.0-beta no
  pull_request:
    types: [labeled, synchronize, opened, reopened]
```

Push to `main` still deploys the `dev` version of the docs. Only pushes of stable tags
trigger the versioned deployment.

### Guard `deploydocs` against missing `bases.txt`

As a belt-and-suspenders safeguard (e.g. if a prerelease tag is pushed despite the
workflow filter), wrap the `deploydocs` call in `docs/make.jl` with an existence check:

```julia
bases_file = joinpath(@__DIR__, "build", "bases.txt")
if isfile(bases_file)
    DocumenterVitepress.deploydocs(;
        repo=repo_url * ".git", devbranch="main", push_preview=true
    )
else
    @info "Skipping deployment: no bases were built (prerelease with existing higher stable release)."
end
```

If `makedocs` built 0 bases (any reason), the CI job completes cleanly instead of
crashing at `deploydocs`.
