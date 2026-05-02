# Brand Identity -- {{BRAND_NAME}}

> Replace `{{BRAND_NAME}}` with the client or project brand name.
> Copy this entire `_example/` directory to `brands/{brand-name}/` and customize.
> Agents automatically consume this file as mandatory context when generating UI.

---

## Brand Name

**{{BRAND_NAME}}**

Tagline: _"{{BRAND_TAGLINE}}"_

---

## Primary Colors

| Token          | Hex       | OKLCH                   | Usage                           |
|----------------|-----------|-------------------------|---------------------------------|
| `primary`      | `#1a365d` | `oklch(30% 0.06 260)`  | Primary actions, links, headers |
| `primary-light`| `#2a4a7f` | `oklch(40% 0.08 260)`  | Hover states, secondary accents |
| `primary-dark` | `#0f2240` | `oklch(22% 0.05 260)`  | Active states, emphasis text    |
| `primary-muted`| `#e8edf4` | `oklch(94% 0.02 260)`  | Backgrounds, subtle highlights  |

## Secondary Colors

| Token         | Hex       | OKLCH                   | Usage                          |
|---------------|-----------|-------------------------|--------------------------------|
| `secondary`   | `#2d6a4f` | `oklch(45% 0.09 160)`  | Success states, CTAs           |
| `accent`      | `#c05621` | `oklch(55% 0.14 50)`   | Alerts, highlights, badges     |
| `neutral`     | `#4a5568` | `oklch(45% 0.01 260)`  | Body text, borders, dividers   |

## Semantic Colors

Use the project's core design token layer for semantic colors (success, warning, error, info).
Override only if the brand requires specific semantic color values.

| Token     | Hex       | Usage                                |
|-----------|-----------|--------------------------------------|
| `success` | `#2d6a4f` | Confirmation, positive feedback      |
| `warning` | `#c05621` | Caution states, pending actions      |
| `error`   | `#c53030` | Destructive actions, validation errors |
| `info`    | `#2b6cb0` | Informational callouts, tooltips     |

---

## Typography

### Heading Font Stack

```
"{{HEADING_FONT}}", ui-sans-serif, system-ui, sans-serif
```

- **Weights**: 600 (semibold), 700 (bold)
- **Letter-spacing**: -0.02em (headings H1-H3), normal (H4+)
- **Style note**: _Replace `{{HEADING_FONT}}` with the brand's heading typeface (e.g., "DM Sans", "Plus Jakarta Sans", "Bricolage Grotesque")._

### Body Font Stack

```
"{{BODY_FONT}}", ui-sans-serif, system-ui, sans-serif
```

- **Weights**: 400 (regular), 500 (medium), 600 (semibold)
- **Line-height**: 1.6 for body text, 1.3 for headings
- **Style note**: _Replace `{{BODY_FONT}}` with the brand's body typeface (e.g., "IBM Plex Sans", "Source Sans 3", "Geist")._

### Monospace Font Stack

```
"{{MONO_FONT}}", ui-monospace, monospace
```

- **Weights**: 400 (regular), 500 (medium)
- **Style note**: _Replace `{{MONO_FONT}}` with the brand's monospace typeface (e.g., "JetBrains Mono", "IBM Plex Mono", "Geist Mono")._

---

## Personality / Voice

- Professional but approachable
- Technical yet accessible to non-technical stakeholders
- Confident without being aggressive
- Concise -- every word earns its place
- Empathetic -- acknowledges user effort and context

> Customize these bullet points to reflect the brand's actual communication style.
> These guide AI agents when generating UI copy, button labels, error messages, and tooltips.

---

## Visual Tone

Clean, modern, and purposeful. Whitespace is treated as a design element, not empty space. Interfaces feel calm and organized rather than dense or cluttered. Visual hierarchy is established through typography scale and color weight rather than decorative elements.

> Replace this paragraph with the brand's actual visual aesthetic.
> Examples of different tones:
> - "Warm, organic, textured -- rounded shapes, earth tones, generous padding"
> - "Bold, high-contrast, editorial -- large type, strong color blocks, tight grid"
> - "Minimal, monochrome, precise -- sharp edges, restrained palette, dense information"

---

## Usage Notes

- Always use the dark mode color variant for dashboard and admin interfaces
- Logo minimum clear space is 24px on all sides
- Primary color must not be used for large background fills -- use `primary-muted` instead
- Never place body text directly on primary-colored backgrounds without sufficient contrast (4.5:1 minimum)
- Heading font is reserved for H1-H3; use body font for H4 and smaller headings

> Replace these with the brand's actual constraints and preferences.
> These notes provide agents with context that does not fit neatly into color or typography tables.
