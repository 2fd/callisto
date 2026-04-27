# Homepage — Astro Static Site on Cloudflare Workers

## Project Overview

A fast, static marketing homepage built with Astro and deployed to Cloudflare Workers. Uses the **Callisto Design System**: a dark-themed, warm-accented UI with soft contrasts and serif display typography.

## Tech Stack

- **Framework:** Astro 6 (static output)
- **Styling:** Tailwind CSS v4 with `@theme inline` (no `tailwind.config.js`)
- **UI Components:** shadcn/ui-style Astro components using `class-variance-authority`
- **Typography:** Inter Variable (sans), system serif stack
- **Deployment:** Cloudflare Workers via `@astrojs/cloudflare` adapter + Wrangler
- **Tooling:** Oxc (oxlint, oxfmt)
- **Node:** >= 22.12.0

## Architecture

```
homepage/
├── src/
│   ├── components/ui/      # Reusable UI components (Button, Card, etc.)
│   ├── lib/
│   │   └── utils.ts        # cn() helper — clsx + tailwind-merge
│   ├── pages/
│   │   └── index.astro     # Landing page
│   ├── styles/
│   │   └── global.css      # Tailwind imports, theme tokens, base styles
│   └── assets/             # Images and media
├── public/                 # Static assets (favicon, etc.)
├── astro.config.mjs        # Astro config (static output, Cloudflare adapter)
├── wrangler.jsonc          # Cloudflare Workers deployment config
├── tsconfig.json           # Strict TypeScript with @/* path alias
└── DESIGN.md               # Callisto Design System spec
```

## Key Design Decisions

- **Static output only:** `output: "static"` in `astro.config.mjs`. No server-side rendering or API routes.
- **Dark theme only:** Single dark surface (`night` `#0E0E16`) with warm peach accent (`primary` `#FFB08A`).
- **Tailwind v4 `@theme inline`:** All design tokens live in `src/styles/global.css`. No separate Tailwind config file.
- **Astro components for UI primitives:** Button, Card, and card subcomponents are `.astro` files using CVA for variant logic. No React or other JS framework.
- **Path alias `@/*`:** Maps to `./src/*` in both TypeScript and Vite.
- **Cloudflare Workers adapter:** `@astrojs/cloudflare` handles static asset serving on the edge.

## Design Tokens

### Colors

| Token | Hex |
|-------|-----|
| `night` | `#0E0E16` |
| `surface` | `#171726` |
| `muted-base` | `#2B2B3D` |
| `primary` | `#FFB08A` |
| `light` | `#FFF8F4` |
| `text-muted` | `#A1A1AA` |

Semantic CSS variables: `background`, `foreground`, `card`, `primary`, `secondary`, `muted`, `border`, `ring`, etc. All defined in `::root` in `global.css`.

### Typography

| Token | Family | Size | Usage |
|-------|--------|------|-------|
| `display` | Serif | 48px | Hero headlines |
| `heading` | Serif | 24px | Section headings |
| `body` | Sans | 16px | UI text, paragraphs |
| `small` | Sans | 14px | Labels, metadata |
| `caption` | Sans | 12px | Badges, fine print |

### Spacing

8pt grid. Tailwind spacing scale is used directly.

### Elevation & Motion

Shadows and durations defined as CSS custom properties in `@theme inline`:
- `shadow-elevation-1` through `shadow-elevation-3`
- `duration-hover` (150ms), `duration-fade` (200ms), `duration-scale` (200ms), `duration-slide` (300ms)

## Build & Run

```bash
# Install dependencies
pnpm install

# Development server
pnpm dev

# Build (generates Wrangler types + Astro build)
pnpm build

# Preview production build locally
pnpm preview

# Deploy to Cloudflare Workers
pnpm deploy

# Lint
pnpm lint

# Format
pnpm format
```

## Conventions

- **No client-side JavaScript by default.** Astro components are server-rendered. Only add client directives (`client:load`, etc.) when interactivity is required.
- **Use the `@/*` path alias** for all internal imports.
- **Style with Tailwind utility classes.** No CSS Modules or styled-components.
- **Use `cn()` from `@/lib/utils`** for conditional class merging.
- **Follow the 8pt grid** for spacing and layout.
- **Respect the dark theme.** Do not introduce light-mode variants unless explicitly requested.
- **Keep components small.** Extract subviews into separate `.astro` files when they exceed ~80 lines.
- **Use CVA for component variants.** See `Button.astro` for the pattern.
