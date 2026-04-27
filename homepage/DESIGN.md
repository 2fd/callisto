# Callisto Design System

> A calm, focused productivity companion for Mac.
> Soft contrasts, warm accents, and a dark theme.

---

## Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `night` | `#0E0E16` | Darkest background (base) |
| `surface` | `#171726` | Card and popover surfaces |
| `muted-base` | `#2B2B3D` | Muted elements, secondary backgrounds, borders |
| `primary` | `#FFB08A` | Warm peach accent — CTAs, highlights, focus rings |
| `light` | `#FFF8F4` | Primary foreground text color |
| `text-muted` | `#A1A1AA` | Secondary text, captions, disabled states |

### Semantic Mapping

- `background` → `night`
- `foreground` → `light`
- `card` → `surface`
- `card-foreground` → `light`
- `primary` → `primary`
- `primary-foreground` → `night`
- `secondary` → `muted-base`
- `secondary-foreground` → `light`
- `muted` → `muted-base`
- `muted-foreground` → `text-muted`
- `accent` → `muted-base`
- `accent-foreground` → `light`
- `destructive` → `#FF6B6B`
- `border` → `light` at 10% opacity
- `input` → `light` at 15% opacity
- `ring` → `primary`

---

## Typography

| Token | Family | Size | Line Height | Weight | Usage |
|-------|--------|------|-------------|--------|-------|
| `display` | Serif | 48px | 56px | 400 | Hero headlines |
| `heading` | Serif | 24px | 32px | 400 | Section headings |
| `body` | Sans | 16px | 24px | 400 | UI text, paragraphs |
| `small` | Sans | 14px | 20px | 400 | Labels, metadata |
| `caption` | Sans | 12px | 16px | 400 | Fine print, badges |

### Font Stacks
- **Sans**: `"Inter Variable", ui-sans-serif, system-ui, sans-serif`
- **Serif**: `ui-serif, Georgia, Cambria, "Times New Roman", Times, serif`
- **Display/Heading**: Serif stack

---

## Spacing

Based on an **8pt grid**. Use multiples of 8 for consistent spacing and layout rhythm.

| Token | Value | Pixels |
|-------|-------|--------|
| `space-1` | 0.25rem | 4px |
| `space-2` | 0.5rem | 8px |
| `space-4` | 1rem | 16px |
| `space-6` | 1.5rem | 24px |
| `space-8` | 2rem | 32px |
| `space-10` | 2.5rem | 40px |
| `space-12` | 3rem | 48px |
| `space-16` | 4rem | 64px |
| `space-20` | 5rem | 80px |
| `space-24` | 6rem | 96px |

---

## Border Radius

Soft radius creates a calm, modern feel.

| Token | Value |
|-------|-------|
| `radius-xs` | 4px |
| `radius-sm` | 8px |
| `radius-md` | 12px |
| `radius-lg` | 16px |

---

## Elevation

Subtle elevation for the dark theme. Levels build cumulative depth.

| Token | Shadow |
|-------|--------|
| `elevation-0` | `none` |
| `elevation-1` | `0 1px 2px 0 rgb(0 0 0 / 0.15), 0 1px 3px 0 rgb(0 0 0 / 0.1)` |
| `elevation-2` | `0 4px 6px -1px rgb(0 0 0 / 0.2), 0 2px 4px -2px rgb(0 0 0 / 0.15)` |
| `elevation-3` | `0 10px 15px -3px rgb(0 0 0 / 0.25), 0 4px 6px -4px rgb(0 0 0 / 0.2)` |

---

## Motion

Smooth, subtle transitions that support focus and clarity.

| Token | Duration | Easing | Usage |
|-------|----------|--------|-------|
| `duration-hover` | 150ms | ease-out | Button states, link hover |
| `duration-fade` | 200ms | ease-in-out | Opacity transitions, overlays |
| `duration-scale` | 200ms | ease-out | Press/active scale feedback |
| `duration-slide` | 300ms | ease-out | Drawer, panel, toast entrance |

---

## Components

### Button

| Variant | Background | Border | Text | Hover | Pressed |
|---------|------------|--------|------|-------|---------|
| Primary | `primary` | transparent | `primary-foreground` | darken 10% | darken 15% |
| Secondary | transparent | `primary` | `primary` | `primary` at 10% | `primary` at 20% |
| Text | transparent | transparent | `primary` | underline | — |

- Border radius: `radius-md` (12px)
- Height (default): 40px
- Padding: 16px horizontal
- Icon gap: 8px

### Card

- Background: `card`
- Border radius: `radius-md` (12px)
- Padding: 24px
- Shadow: `elevation-1`
- Ring: 1px `foreground` at 10% opacity

### Tag

- Background: `primary`
- Border radius: `radius-sm` (8px)
- Padding: 4px 12px
- Text: `caption` size

### Badge

- Background: `muted-base`
- Border radius: `radius-lg` (16px) — pill shape
- Padding: 4px 12px
- Text: `caption` size, `light` color

### Feature Item

- Icon: 24px, `primary` color
- Title: `small` sans, `foreground`
- Description: `caption`, `muted-foreground`
- Spacing between items: 24px

### List Item

- Icon: 20px, `primary` color
- Title: `body` sans, `foreground`
- Description: `small`, `muted-foreground`
- Padding: 12px vertical

### Quote / Testimonial

- Quote marks: `primary`, 32px
- Text: `body` serif, `foreground`
- Attribution: `caption`, `muted-foreground`
- Left border: 2px `primary`

---

## Theme

The system uses a single **dark** theme with accessible contrast and warm accents.

- Dark mode is the only expressive surface (deep navy `night`).
- `primary` (`#FFB08A`) is the single warm accent used sparingly for focus and action.
- All text meets WCAG 2.1 AA contrast against the dark background.
