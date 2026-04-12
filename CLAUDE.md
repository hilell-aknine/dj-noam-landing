# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DJ Noam Loichter (דיג'יי נועם לויכטר) landing page. Static single-page site, no build tools or frameworks.

## Architecture

Single `index.html` with all CSS and JS inline. Images in `images/` folder. Deployed to Vercel via GitHub (`master` branch auto-deploys).

**Sections flow:** Nav → Hero (2-col) → Marquee → About → Experience (soundwave bg) → Services (10 cards) → Testimonials (screenshots + text) → CTA/Contact Form → Footer

## Brand

- **Colors:** Orange `#F27A1A`, Black `#1A1A1A`, White `#ffffff`
- **Font:** Heebo (Google Fonts)
- **Phone:** 052-8963977 / `972528963977`
- **Direction:** RTL Hebrew

## CSS Custom Properties

All colors defined in `:root` — use `var(--orange)`, `var(--black)`, etc. Never hardcode colors.

## Responsive Breakpoints

- `1024px` — tablet (3-col services, 2-col experience)
- `768px` — mobile (stacked layouts, full-width buttons, hamburger nav)
- `380px` — small phones (1-col everything, tighter spacing)

## JS Behavior

- Scroll reveal via IntersectionObserver (`.rv` → `.v`)
- Form submit opens WhatsApp with pre-filled message
- Nav adds `.scrolled` class at 50px scroll

## Images

- `noam.jpeg` — cropped hero photo (use in hero + about)
- `icon-*.png` — Gemini-generated service icons (orange+black on white)
- `bg-soundwave.png` — experience section background
- `review1-4.jpeg` — real WhatsApp testimonial screenshots

## Deployment

```bash
git push  # auto-deploys to Vercel from master
```

## Rules

- No em-dash (—) characters in any text. Use commas, periods, or pipes instead.
- All text in Hebrew, RTL. Marketing copy should be customer-focused (benefits, not features).
- Keep everything in one HTML file. No external CSS/JS files.
- Service icons are custom images, not SVGs or emoji.

## Remote Server
A secondary machine at `192.168.1.125` is available. Not needed for this project — it's a static single-page site deployed via Vercel.
