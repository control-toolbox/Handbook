# Migration from Documenter to DocumenterVitepress

> The conventions for a DocumenterVitepress site — API reference structure, plots as SVG,
> code annotations, stable-tag deployment — and the notes on the backend live in
> [`rules/site.md`](rules/site.md) (`SITE1`–`SITE13`). This file only keeps the migration
> recipe.


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

## Deployment

Deployment is done automatically via CI with `DocumenterVitepress.deploydocs`. Ensure that:

- The GitHub repository exists
- The `gh-pages` branch does not contain symlinks
- CI workflows are configured for DocumenterVitepress

See [`SITE13`](rules/site.md#site13--deploy-on-stable-tags-only-and-guard-deploydocs) for the tag filter and the `deploydocs` guard.
