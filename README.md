# Brian Rogers — portfolio and résumé

My résumé, projects, and technical articles, built with Hugo and [Toha](https://github.com/hugo-themes/toha) v4.16.0 and deployed through Cloudflare Pages.

## Build locally

The tested toolchain is Hugo Extended 0.166.0, Go 1.27.1, and Node.js 22.14.0 with npm 10. The site's `go.mod` requires Go 1.25.1 or newer.

```sh
npm ci --include=dev
npm run build
```

Hugo resolves the pinned theme module and writes the site to `public/`, excluding drafts. For local development with live reload, run `hugo server` after installing dependencies.

## Cloudflare Pages

In the Cloudflare dashboard, use these settings for both Production and Preview:

| Setting | Value |
| --- | --- |
| Root directory | Repository root |
| Build command | `npm ci --include=dev && npm run build` |
| Build output directory | `public` |
| `HUGO_VERSION` | `0.166.0` |
| `GO_VERSION` | `1.27.1` |
| `NODE_VERSION` | `22.14.0` |
| `SKIP_DEPENDENCY_INSTALL` | `1` |

Check that the Pages build log reports Hugo Extended. With `SKIP_DEPENDENCY_INSTALL=1`, the build command handles dependency installation using the committed lockfile.

The canonical URL in `hugo.yaml` is `https://brian.th3rogers.com/`. Preview builds use it by default. To give a preview its own absolute URLs, override Hugo's `baseURL` in that preview's build command.

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

Review and commit `go.mod`, `go.sum`, `package.json`, `package-lock.json`, and `packages/hugoautogen/` together. Hugo generates the theme's Node dependencies in the `packages/hugoautogen` npm workspace; use `hugo mod npm pack` to update it. The site's module metadata lives in `package.hugo.json`.

## Content

- `data/en/author.yaml` and `data/en/site.yaml`: identity, contact information, and metadata.
- `data/en/sections/`: About, skills, employment, projects, and achievements.
- `static/files/resume.pdf`: downloadable résumé; keep employment details and project descriptions consistent with the site.
- `content/posts/u-forge-ai/`: u-forge.ai project case study and screenshot.
- `content/posts/strixhalo-cachyos/`: September 2025 local-inference setup guide.
