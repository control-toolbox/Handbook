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

- **ANSI color codes in @repl blocks**: DocumenterVitepress does not automatically convert ANSI escape codes to HTML in `@repl` blocks (unlike `@example` blocks which are converted to `ansi` code blocks). To avoid raw ANSI codes appearing in the generated markdown, wrap `showerror` calls with `IOContext(stdout, :color => false)`:

  ```julia
  try
      # ... your code that may throw ...
  catch e
      showerror(IOContext(stdout, :color => false), e)
  end
  ```

  This is a known limitation tracked in [LuxDL/DocumenterVitepress.jl#321](https://github.com/LuxDL/DocumenterVitepress.jl/issues/321).

- **Color-aware display functions**: If your package has custom display functions that emit ANSI escape codes (e.g. error formatting helpers), make them color-aware by checking `get(io, :color, false)` before applying escape sequences:

  ```julia
  _apply_ansi(s, code, io::IO) = get(io, :color, false) ? "\033[$(code)m$(s)\033[0m" : s
  ```

  Propagate the `io` argument through all display helpers so that:
  - REPL / GitHub Actions → colors enabled (`:color => true` by default)
  - Documenter / VitePress → plain text when wrapped with `IOContext(stdout, :color => false)`

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
