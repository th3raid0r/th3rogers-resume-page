# Brian Rogers — portfolio and résumé

Hugo site using [Toha](https://github.com/hugo-themes/toha) v4.16.0, deployed through **Cloudflare Pages**. Docker is not part of the build or deployment workflow.

## Build locally

Use Hugo **Extended 0.166.0**, Go **1.25.1 or newer**, and Node.js **22.14.0 or newer** (npm 10). Toha requires Hugo Extended 0.163.0 or newer; use the pinned 0.166.0 version here for consistent npm workspace generation.

```sh
npm ci --include=dev
npm run build
```

Hugo resolves the pinned Go module during the build. Output is written to `public/`; drafts are excluded. For interactive local development, run `hugo server` after installing dependencies.

## Cloudflare Pages

Configure the existing Pages project with the following settings for **both Production and Preview**:

| Setting | Value |
| --- | --- |
| Root directory | Repository root |
| Build command | `npm ci --include=dev && npm run build` |
| Build output directory | `public` |
| `HUGO_VERSION` | `0.166.0` |
| `GO_VERSION` | `1.27.1` |
| `NODE_VERSION` | `22.14.0` |
| `SKIP_DEPENDENCY_INSTALL` | `1` |

These versions match the local validation toolchain. Confirm the Pages build log reports **Hugo Extended**. `SKIP_DEPENDENCY_INSTALL` avoids a redundant automatic installation; the explicit `npm ci --include=dev` installs the theme's build dependencies from the committed lockfile. Go 1.25.1 is the minimum declared by this site's `go.mod`; the configured version above is the locally tested version.

The canonical production URL is `https://brian.th3rogers.com/` in `hugo.yaml`. The default build intentionally retains that canonical URL on previews. If a preview needs its own absolute URLs, override Hugo's `baseURL` in that preview build only; do not replace the production canonical URL with a `pages.dev` address.

Pages build settings live in the Cloudflare dashboard and are **not changed by this repository update**. No Wrangler account/project identifiers or deployment secrets are required for this Git-integrated static build.

References: [Cloudflare's Hugo guide](https://developers.cloudflare.com/pages/framework-guides/deploy-a-hugo-site/) and [build tool version settings](https://developers.cloudflare.com/pages/configuration/build-image/).

## Update the theme

```sh
hugo mod get github.com/hugo-toha/toha/v4@latest
hugo mod tidy
hugo mod npm pack
npm install
npm audit
npm run build
```

Review and commit `go.mod`, `go.sum`, `package.json`, `package-lock.json`, and `packages/hugoautogen/` together. Newer Hugo versions generate the theme's Node dependencies as the `packages/hugoautogen` npm workspace. Do not restore the older duplicated theme dependency list in the root `package.json` or manually edit the generated workspace. `package.hugo.json` retains the site's module metadata.

## Content

- `data/en/author.yaml` and `data/en/site.yaml`: identity, contact information, and metadata.
- `data/en/sections/`: About, skills, employment, projects, and achievements.
- `static/files/resume.pdf`: downloadable résumé; keep site content reconciled with it.
- `content/posts/u-forge-ai/`: u-forge.ai project case study and screenshot.
- `content/posts/strixhalo-cachyos/`: related local-inference article.

Tucson.social and u-forge.ai are portfolio projects, not employment entries. u-forge.ai's public destination is its GitHub repository; the site does not link its domain as a live hosted product.
