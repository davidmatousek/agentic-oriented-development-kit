# Anti-Patterns -- {{BRAND_NAME}}

> This file lists design patterns and choices that AI agents must **avoid** when generating UI for this brand. Agents load this file as a constraint layer alongside `brand.md` and `tokens.css`.
>
> Copy this template to your brand directory and replace the examples below with actual client constraints. Remove any items that do not apply.

---

## How Agents Use This File

When a `brands/{brand-name}/` directory is detected, agents read this file before generating any UI components. Each constraint listed here acts as a negative rule -- the agent must verify its output does not violate any of these items.

---

## Visual Constraints

- [ ] Avoid border-radius values larger than 8px on interactive elements (buttons, inputs, cards)
- [ ] Never use gradient backgrounds on primary action buttons
- [ ] No drop shadows deeper than `--shadow-md` on card components
- [ ] Do not use colored backgrounds behind body text -- maintain white or neutral surfaces
- [ ] Avoid full-width hero sections with background images
- [ ] Never apply opacity below 0.7 to interactive elements in their default state

## Typography Constraints

- [ ] Do not use emoji in UI copy (button labels, headings, navigation items)
- [ ] Never use decorative or script fonts for any UI element
- [ ] Avoid font weights below 400 (light/thin) for body text
- [ ] Do not use ALL CAPS for text longer than 3 words
- [ ] Never set body text smaller than 14px / 0.875rem
- [ ] Avoid letter-spacing wider than 0.05em on body text

## Motion / Animation Constraints

- [ ] Avoid animations longer than 300ms for micro-interactions (hover, focus, toggle)
- [ ] Never use bounce or elastic easing curves
- [ ] Do not auto-play animations or transitions on page load
- [ ] Avoid parallax scrolling effects
- [ ] All animations must respect `prefers-reduced-motion: reduce`

## Layout Constraints

- [ ] Do not place more than 3 primary action buttons in a single viewport
- [ ] Avoid horizontal scrolling containers on mobile breakpoints
- [ ] Never use fixed/sticky positioning for elements taller than 64px on mobile
- [ ] Do not use multi-column text layouts (CSS `column-count`) for body content

## Color Constraints

- [ ] Never use pure black (`#000000`) for text -- use the brand's foreground token
- [ ] Do not combine more than 2 brand colors in a single component
- [ ] Avoid using the destructive color for non-destructive actions
- [ ] Never use color as the sole indicator of state -- always pair with an icon, label, or pattern

---

## Notes for Adopters

- **Be specific**: "Avoid rounded corners larger than 8px" is actionable. "Keep it clean" is not.
- **Explain the why** (optional): Add a brief rationale after any constraint if it helps agents make better judgments in edge cases.
- **Remove unused items**: Only keep constraints that reflect actual brand requirements. A shorter, precise list is more effective than a long generic one.
- **Test with generation**: After customizing, generate a sample component and verify the agent respects each constraint.
