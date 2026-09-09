---
name: Shore Table Platform (marketing homepage)
description: A boardwalk ticket counter in the operator's own color. Flat enamel panels, perforated ticket stock, tags on a rail, wide sign lettering.
colors:
  accent: "#3a6ea5"
  accent-deep: "#30547a"
  accent-tint: "#eff2f4"
  on-accent: "#ffffff"
  ink: "#1b1813"
  ink-dim: "#6f6a61"
  ink-faint: "#a49d90"
  on-ink: "#f4f2ee"
  on-ink-dim: "#cfc9bf"
  bg: "#ffffff"
  stock: "#fbf9f4"
  line: "rgba(22,17,10,.11)"
  line-2: "rgba(22,17,10,.2)"
typography:
  display:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "clamp(28px, 3.4vw, 41px)"
    fontWeight: 700
    lineHeight: 1.14
    letterSpacing: "0"
  display-offer:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "clamp(28px, 4.4vw, 50px)"
    fontWeight: 800
    lineHeight: 1.04
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "clamp(24px, 3.6vw, 38px)"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.015em"
  title:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "clamp(19px, 2.4vw, 24px)"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.01em"
  title-tag:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1.3
    letterSpacing: "-0.005em"
  ticket-number:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "clamp(22px, 3vw, 30px)"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "-0.01em"
  lede:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "clamp(16px, 1.9vw, 19px)"
    fontWeight: 400
    lineHeight: 1.5
  body:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.55
  body-sm:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "14.5px"
    fontWeight: 400
    lineHeight: 1.55
  button:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "0.005em"
  ticket-lettering:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.16em"
  tag-lettering:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "10.5px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.14em"
  caption:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "0.06em"
  wordmark:
    fontFamily: "Unbounded, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "0.02em"
  fineprint:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "12.5px"
    fontWeight: 400
    lineHeight: 1.55
rounded:
  hairline: "2px"
  xs: "8px"
  sm: "10px"
  md: "14px"
  lg: "18px"
  ticket: "20px"
  pill: "999px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "22px"
  xl: "28px"
  2xl: "44px"
  3xl: "56px"
  section: "72px"
  section-wide: "104px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "16px 30px"
  button-primary-hover:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
  button-ink:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-accent}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "16px 30px"
  button-ghost:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "16px 30px"
  button-small:
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "13px 24px"
  header-cta:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.pill}"
    padding: "10px 18px"
  header-cta-hover:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
  ticket:
    backgroundColor: "{colors.stock}"
    textColor: "{colors.ink}"
    rounded: "{rounded.ticket}"
    padding: "22px 24px"
  ticket-stub-lettering:
    textColor: "{colors.accent-deep}"
    typography: "{typography.ticket-lettering}"
  game-tag:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "30px 22px 22px"
  game-tag-category:
    textColor: "{colors.accent-deep}"
    typography: "{typography.tag-lettering}"
  board-icon:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.sm}"
    size: "38px"
  phone-caption:
    backgroundColor: "{colors.stock}"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.sm}"
    padding: "9px 14px 9px 30px"
  wordmark-mark:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.xs}"
    size: "28px"
  panel-accent:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.on-accent}"
    padding: "64px 0 56px"
  panel-night:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-ink}"
    padding: "72px 0"
  panel-tint:
    backgroundColor: "{colors.accent-tint}"
    textColor: "{colors.ink}"
    padding: "72px 0"
---

# Design System: Shore Table Platform (marketing homepage)

**Scope.** This file records the world of the lead-facing marketing homepage (`public/index.html`) only. The diner app (`app.html`), the owner dashboard, the monthly report, and admin have their own established visual system that this world does not touch; do not apply anything below to them. Four rules bind the whole platform regardless of surface: flat color only, no gradients; sans-serif type only; no em dashes in copy; and every operator instance injects its own accent, name, region words, and mark or logo at load (`brand.js`), so every rule here is written against tokens (`--accent`, `--accent-deep`, `--accent-tint`, `--stock`, `--ink`), never against Shore Table's blue.

## Overview

**Creative North Star: "The Boardwalk Ticket Counter"**

The homepage is a ticket booth painted in the operator's color. The product it sells is an admission ticket to a better night at the table, and every object on the page is something you would find at a counter on a boardwalk: flat enamel sign panels, a perforated ticket with a tear-off stub, prize tags hanging from a rail on strings, a price board behind the counter with hairlines between rows, and a tally sheet pinned up with a dashed edge. Nothing floats; everything is laid down, pinned, or hung, and the few objects that are lifted off the counter get a slight tilt to prove they are loose.

The palette is deliberately two inks plus one accent. Ink (a warm near-black) and white do all the work of text and structure; the accent paints the panels and the buttons. Because the accent is injected per operator, the system never assumes a hue: the deep and tint variants are computed from the accent with `color-mix`, the hero shadow is tinted from it, and the white ticket stock stays fixed so the counter reads the same whether the booth is blue, red, or green. Type is two sans faces with a hard split of duty: Unbounded is lettering painted on objects (signs, ticket stubs, tags, the wordmark), Hanken Grotesk is everything a person reads as prose or presses as a button.

Density is generous and single-column at heart: one 1080px column, sections of 72 to 104px, and objects sized to be recognized at a glance from across the room. Confirmed rejections: gradients anywhere, serif or system display faces, and the SaaS arrangement of hero plus three floating phones plus four icon cards (the phones stand on the enamel panel inside the hero, and the benefits are a counter board, not a card grid).

**Key Characteristics:**
- Two inks plus one operator accent; nothing else is colored
- Full-bleed flat panels in accent, ink, or accent tint; white between them
- Physical counter objects: ticket with stub and notches, tags on a rail, price board, pinned tally
- Unbounded for lettering on objects, Hanken Grotesk for prose and buttons
- Shadows only under objects that sit on the counter; panels are flat
- Slight tilts (under 1.5 degrees) on loose objects; one entrance moment in the hero

## Colors

Two inks (ink and white) plus one operator accent, with every accent variant derived rather than chosen, and one warm off-white reserved for ticket stock.

### Primary
- **Operator Accent** (`--accent`, reference `#3a6ea5`): The enamel paint. Fills the hero booth panel and the closing offer panel edge to edge, the primary button, the board icon squares, the wordmark mark, the ticket notches, the placeholder diamonds, and text selection. It is set on `:root` before first paint from `OPERATOR_CONFIG`/`OPERATOR_BRAND`; the value in this file is only the reference brand's.
- **Accent Deep** (`--accent-deep`, `color-mix(in srgb, var(--accent) 72%, #16110a)`; falls back to the accent where `color-mix` is unsupported): The accent darkened with ink, never a second hue. Used for small lettering that must clear contrast on white or stock (ticket stub lettering, tag category lettering, the footer mail link) and for the focus ring.
- **Accent Tint** (`--accent-tint`, `color-mix(in srgb, var(--accent) 7%, #fdfcfa)`; falls back to `#f2f5f9`): The lightest wash of the accent on a warm white. Section background for the game library and the monthly report, and and nothing else. It is the only permitted "tinted" surface and it is flat.
- **On Accent** (`--on-accent`, white): All text and outlines on accent panels. Prose on accent runs at 94% opacity; headings at full.

### Neutral
- **Ink** (`--ink`): Warm near-black. Body text, headings, the night sign section background, the phone frames, the rail bar and its end caps, the ink button, and the header pill. Ink hover on the ink button goes to pure black.
- **Ink Dim** (`--ink-dim`): Secondary prose: section subheads, board explanations, game descriptions, ticket sub-lines, footer copy.
- **Ink Faint** (`--ink-faint`): Fineprint and placeholder text only.
- **On Ink** (`--on-ink`, `#f4f2ee`) and **On Ink Dim** (`#cfc9bf`): Heading and prose colors on the ink panel. Warm whites, never pure white, so the night sign stays in the same warm family as the ticket stock.
- **Page White** (`--bg`): The counter itself. Body background, header bar, footer, game tags, ghost button.
- **Ticket Stock** (`--stock`, `#fbf9f4`): The one warm surface. Used only on things printed on ticket paper: the two tickets, the prize-tag captions, and the pinned report. Never a section background.
- **Line** (`--line`) and **Line 2** (`--line-2`): Ink at 11% and 20% alpha. Line is the hairline for the header and footer rules and the game tag border; Line 2 is the perforation dash on tickets and the tally, the board row separators, the ghost button border, the caption strings.

### Named Rules
**The Two Inks Rule.** Ink, white, and the operator accent are the entire palette. No second hue, no success or warning color, no grey that is not a tint of ink. If something needs to be colored and it is not accent, it is ink.

**The Derived Accent Rule.** Never hand-pick a darker or lighter version of the accent. `--accent-deep` and `--accent-tint` are computed from `--accent` with `color-mix` so they follow whatever color the operator injects; new surfaces use those two tokens and nothing else.

**The Stock Rule.** `--stock` appears only on objects printed on ticket paper (tickets, tags, the pinned report). Sections are white, accent, ink, or accent tint. A stock-colored section would flatten the ticket into the counter.

## Typography

**Display Font:** Unbounded (with system-ui, sans-serif), weights 500, 700, 800
**Body Font:** Hanken Grotesk (with system-ui, sans-serif), weights 400 to 700
**Label/Mono Font:** none; small lettering is Unbounded, tracked wide

**Character:** Wide, blunt sign lettering over a plain, friendly grotesk. Unbounded reads as paint on an object and is used only where the text belongs to an object: a sign, a ticket, a tag, a board row title, the wordmark. Hanken Grotesk carries everything a person reads as sentences or presses as a button, so the page sounds like a neighbor, not a poster.

### Hierarchy
- **Display** (Unbounded 700, `clamp(28px, 3.4vw, 41px)`, line-height 1.14, tracking 0, max 24ch): The hero headline on the accent panel. Deliberately lighter and looser than the offer sign so it sets in three rows inside a half column. The night sign heading is the same voice at `clamp(26px, 4vw, 44px)`, line-height 1.08, max 16ch.
- **Display, offer** (Unbounded 800, `clamp(28px, 4.4vw, 50px)`, line-height 1.04, tracking -0.02em, max 14ch): The closing sign only; the one place the heaviest weight and tightest tracking appear.
- **Headline** (Unbounded 700, `clamp(24px, 3.6vw, 38px)`, line-height 1.12, tracking -0.015em): Section headings on white and tint sections. The report heading is the same style capped at 36px.
- **Title** (Unbounded 700, `clamp(19px, 2.4vw, 24px)`, line-height 1.15, tracking -0.01em): Counter board row titles, set with the accent icon square beside them. Game tag titles are the fixed small size (17px, tracking -0.005em).
- **Ticket number** (Unbounded 800, `clamp(22px, 3vw, 30px)`, line-height 1.05, tracking -0.01em): The big line on a ticket stub ("Free first month"). On the offer ticket it caps at 26px.
- **Lede** (Hanken 400, `clamp(16px, 1.9vw, 19px)`, line-height 1.5, max 56ch): Hero paragraph under the headline.
- **Body** (Hanken 400, 17px, line-height 1.55, 48 to 64ch): Section subheads and board explanations. Board explanations run 16.5px; the games note 16px; ticket sub-lines 14px; game descriptions 14.5px; footer 15px.
- **Button** (Hanken 700, 17px, tracking 0.005em; small 15px; header 14px): All buttons, in the body face so they read as things to press, not signs.
- **Ticket lettering** (Unbounded 700, 11px, tracking 0.16em, uppercase, `--accent-deep`): The small line printed at the top of a ticket stub ("Admit one table", "Free trial"). Ticket typography, belonging to the ticket object.
- **Tag lettering** (Unbounded 700, 10.5px, tracking 0.14em, uppercase, `--accent-deep`): The category printed on a game tag above its title. Tag typography, belonging to the tag object.
- **Caption** (Unbounded 500, 11.5px, tracking 0.06em, uppercase, ink): Prize-tag captions under the phones and the report; the only 500-weight use of Unbounded.
- **Wordmark** (Unbounded 700, 16px, tracking 0.02em, uppercase): Brand name next to the mark, header and footer.
- **Fineprint** (Hanken 400, 12.5px, `--ink-faint`): Footer fineprint only.

### Named Rules
**The Sign Lettering Rule.** Unbounded is for text that belongs to an object (sign panel headings, ticket stubs, tags, board row titles, the wordmark). Hanken Grotesk is for text a person reads or presses (prose, ledes, descriptions, buttons). Never set a paragraph in Unbounded and never set a heading in Hanken.

**The Balanced Heading Rule.** Every h1 through h3 sets `text-wrap: balance` and carries a `max-width` in ch (24ch hero, 16ch night sign, 14ch offer) so sign lettering never leaves a one-word last line.

**The Small Lettering Rule.** Tracked uppercase Unbounded lives only on printed objects: ticket stubs, tags, captions, and the wordmark. It is not a section eyebrow; sections open with the headline itself.

## Layout

One centered column, `max-width: 1080px`, with a 22px gutter on both sides (`.wrap`). Panels (accent, ink, tint) run full bleed and the column sits inside them; white sections are the counter between panels. Vertical rhythm is section padding of 72px, rising to 104px at 760px and up; the hero booth runs 64px top / 56px bottom, rising to 88 / 80. Section heads sit 44px above their content, capped at 720px wide (centered for the game library).

Two-column layouts appear only at width and always collapse to one column below their breakpoint: the hero at 760px (1.1fr / 0.9fr, 48px gap; 1.05fr / 0.95fr, 56px gap from 1000px), the night sign at 900px (equal halves, 56px gap), the report at 820px (1fr / 1.1fr, 56px gap), the offer at 860px (equal halves, 56px gap). The game rail is one column, two at 600px, three at 900px (gaps 18px/16px rising to 26px/22px). The counter board is a two-column row at 760px (0.9fr / 1.5fr, 40px gap, 34px vertical padding; 12px gap and 28px padding stacked).

The three phones are 232px frames in a wrapping flex row with 22px gaps, standing 56px (72px at width) below the hero ticket on the accent panel; at width the middle phone drops 36px so the row steps. The sticky white header is 14px tall padding on a 1px hairline. Spacing steps the build actually reuses: 8, 12, 14, 16, 18, 22, 24, 28, 34, 40, 44, 56.

## Elevation & Depth

Depth is physical, not atmospheric. Panels and sections are perfectly flat; the only things that cast shadows are objects that sit on the counter or hang from the rail: tickets, phone frames, game tags, and buttons. Two soft, warm-ink shadows do all of it, and in browsers with `color-mix` the large shadow is tinted 16% with the accent so a ticket on the enamel panel throws a shadow in the panel's own color. The pinned report uses `filter: drop-shadow` instead of `box-shadow` so the shadow follows its dashed edge. Loose objects also tilt: the hero ticket at -1.2 degrees (at 760px and up), the offer ticket at 1.4, the report at 0.8, and a game tag rotates -0.6 degrees as it lifts on hover.

### Shadow Vocabulary
- **Resting object** (`--shadow-sm`: `0 1px 2px rgba(22,17,10,.06), 0 6px 16px rgba(22,17,10,.07)`): Game tags and buttons at rest.
- **Lifted object** (`--shadow`: `0 2px 4px rgba(22,17,10,.04), 0 18px 44px color-mix(in srgb, var(--accent) 16%, rgba(22,17,10,.08))`; fallback `0 2px 4px rgba(22,17,10,.05), 0 18px 44px rgba(22,17,10,.12)`): Tickets, phone frames, and any object on hover.
- **Pinned sheet** (`filter: drop-shadow(0 2px 3px rgba(22,17,10,.05)) drop-shadow(0 16px 30px rgba(22,17,10,.1))`): The report, whose dashed edge needs a shape-following shadow.

### Named Rules
**The Counter Object Rule.** A shadow means the thing is physically on the counter. Panels, sections, headers, rails, and boards never cast one; tickets, phones, tags, frames, and buttons always do.

**The Slight Tilt Rule.** Loose objects tilt between 0.6 and 1.5 degrees, alternating direction across the page, and only at widths where they have room (the hero ticket is square below 760px). Nothing tilts further, and text panels never tilt.

## Shapes

Rounded, cut-paper geometry. Buttons and the header CTA are full pills (999px). Tickets are 20px, game tags and the pinned report 14px, board icon squares and captions 10px, the wordmark mark and focus ring 8px. Phone frames are 34px with a 26px screen inside 10px of ink bezel. The rail and placeholder diamonds use a 2px radius so they stay crisp.

Perforation is a 2px dashed `--line-2` rule: it separates a ticket's stub from its body (bottom edge stacked, right edge from 1000px in the hero) and outlines the pinned report. The tear is completed by two 28px circular notches painted in the panel accent at each end of the perforation, so the cut reads as a real hole against the enamel. Hanging objects carry a 1.5px string in ink or `--line-2` and no eyelet (rejected: the eyelets read as radio buttons); the rail is a 3px ink bar with 13px ink end caps. Borders elsewhere are 1px `--line` (tags, header, footer) or 1.5px `--line-2` (ghost button, captions).

## Components

### Buttons
Ticket stubs you can press: pill, bold body face, lifted on hover.
- **Shape:** Full pill (999px), no border.
- **Primary:** Accent fill, white text, Hanken 700 17px, 16px 30px padding, resting shadow (`--shadow-sm`). Inside a ticket body it goes full width and never wraps.
- **Hover / Focus:** Rises 2px and takes the lifted shadow (`--shadow`), 160ms transform / 200ms shadow on the standard ease; active returns to rest at 98% scale. Focus-visible is a 3px `--accent-deep` outline offset 3px (white on accent panels).
- **Ink:** Same shape, `--ink` fill, hovers to pure black. Sits beside the primary in the hero ticket at equal weight ("Try the demo").
- **Ghost:** White fill, ink text, 1.5px `--line-2` border, no shadow at rest or hover; hover darkens the border to ink. Used once, for "Suggest a game".
- **Small:** 15px text, 13px 24px padding, on any variant.
- **Header CTA:** Ink pill, Hanken 700 14px, 10px 18px padding; hover fills with the accent and rises 1px.

### Ticket (signature)
White ticket stock with a perforated stub, laid on the accent panel at a slight tilt, and the only object carrying both actions.
- **Shape:** 20px radius, `--stock` fill, ink text, lifted shadow. Stacks stub over body below 1000px in the hero (stub bottom edge dashed); from 1000px the stub is a 232px-minimum left column with a dashed right edge. The offer ticket stays stacked.
- **Stub:** 22px 24px padding. Ticket lettering (Unbounded 700 11px, 0.16em, uppercase, `--accent-deep`), then the ticket number (Unbounded 800), then a `--ink-dim` 14px sub-line. Two 28px accent notches sit at the ends of the perforation.
- **Body:** 22px 24px padding, 12px gap, buttons full width.
- **Entrance:** In the hero the ticket slides in 40px from the right over 900ms, 180ms after the copy rises 14px over 700ms in three staggered steps; both are removed under `prefers-reduced-motion`.

### Game Tag (card)
A white prize tag hung from the rail by a string.
- **Corner Style:** 14px.
- **Background:** Page white, 1px `--line` border, resting shadow.
- **String:** No eyelet; only the tags in the top row (one, two, or three depending on the grid) hang a 1.5px ink string 34px up to the rail, so no string ever runs into a tag above it.
- **Internal Padding:** 24px top, 22px sides, 22px bottom.
- **Contents:** Tag lettering category (`--accent-deep`), Unbounded 17px title, `--ink-dim` 14.5px description.
- **Hover:** Lifts 3px, rotates -0.6 degrees, takes the lifted shadow.

### Rail
A 3px ink bar across the full column width with 13px ink end caps, 34px above the first row of tags. It is the fixture tags hang from; nothing else hangs from it.

### Counter Board (list)
A price board behind the counter, not a card grid. Hairlines between rows only; no rule above the board and no subheading under its title.
- **Structure:** no top rule; rows separated by 1px `--line-2` hairlines; title left, explanation right.
- **Row title:** Unbounded 700 title size with a 38px accent icon square (10px radius, 20px white stroke icon, inline SVG) leading it by 14px and pulled up 4px to sit on the cap line.
- **Row body:** `--ink-dim` 16.5px, max 64ch.

### Prize-Tag Caption (chip)
The small label under a phone or the pinned report, hung on a string.
- **Style:** `--stock` fill, 1.5px `--line-2` border, 10px radius, 9px 14px padding; caption lettering (Unbounded 500 11.5px, 0.06em, uppercase). A 1.5px string rises 22px from its top center. On the accent panel the border goes transparent and the string is white at 60%.

### Phone Frame
A 232px ink slab (34px radius, 10px bezel) with a 26px-radius screen at 9:19, lifted shadow. Until a screenshot URL is set the screen shows a `#efece6` placeholder with a small accent diamond and `--ink-faint` text.

### Pinned Report
Ticket stock sheet, 2px dashed `--line-2` edge, 14px radius, 12px padding around a 6px-radius image, drop-shadow filter, tilted 0.8 degrees, captioned with a prize tag 24px below.

### Panels
- **Accent panel** (booth, offer): `--accent` fill, white text, prose at 94% opacity; focus rings switch to white.
- **Night sign** (local section): `--ink` fill, `--on-ink` heading, `--on-ink-dim` prose.
- **Tint section** (games, report): `--accent-tint` fill, ink text.

### Navigation
A sticky white bar on a 1px hairline. Left: the wordmark (28px accent mark, 8px radius, with the operator's SVG, icon, or initial; or a 26px-tall logo image replacing the pair) and the brand name in wordmark lettering. Right: the header CTA. No menu, no links; the page is one scroll.

### Wordmark
The mark is a 28px accent square at 8px radius holding the operator's logo SVG or icon (background turns transparent) or the brand initial in Unbounded 800 15px white. The name sits 10px to its right in wordmark lettering. Repeated centered in the footer.

## Do's and Don'ts

### Do:
- **Do** build every color from the five tokens `--accent`, `--accent-deep`, `--accent-tint`, `--stock`, `--ink` (plus white and the ink alphas); a new surface must look right when `--accent` is any hex.
- **Do** derive darker and lighter accent values with `color-mix` from `--accent` and ship the plain fallback inside `@supports`.
- **Do** put shadows only under counter objects (tickets, tags, phones, frames, buttons) and use `--shadow-sm` at rest, `--shadow` on lift.
- **Do** set lettering on objects in Unbounded 700 and prose and buttons in Hanken Grotesk; balance headings and cap them in ch.
- **Do** run panels full bleed with content inside the 1080px column and 22px gutters; sections at 72px / 104px.
- **Do** keep loose objects tilted under 1.5 degrees and untilt them below 760px.
- **Do** keep both hero actions at equal visual weight (accent pill and ink pill, same size, same width).
- **Do** use the standard ease `cubic-bezier(.16, 1, .3, 1)` for every transition and honor `prefers-reduced-motion`.

### Don't:
- **Don't** use gradients, glows, or blurred backgrounds anywhere; flat fills only, including the accent tint.
- **Don't** introduce a second hue, a semantic color, or a cool grey; every neutral is a tint or alpha of ink.
- **Don't** hard-code `#3a6ea5` or any accent-derived hex in new CSS; reference the token.
- **Don't** use `--stock` as a section background or on anything that is not printed on ticket paper.
- **Don't** set serif, system, or any third typeface; the platform is sans-serif only.
- **Don't** open a section with tracked small caps above the heading; small lettering belongs to tickets, tags, captions, and the wordmark.
- **Don't** lay benefits out as an icon card grid; the counter board (rows with hairlines) is the pattern.
- **Don't** use em dashes in copy, on this page or anywhere on the platform.
- **Don't** put a shadow, border glow, or tilt on a panel, section, rail, or board.
