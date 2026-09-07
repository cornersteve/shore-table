# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primary: owners and general managers of independent restaurants and bars
(one to a few locations) in a defined local region. In the reference
deployment that region is Monmouth County, on the New Jersey shore. They
are on their feet between services, read on a phone, distrust software
that needs staff training, and measure a night by whether guests had a
good time and whether it turned into a Google review.

Secondary: the diner at the table (uses the app; never the audience of the
homepage) and the operator who runs a regional instance of the platform.

## Product Purpose

A printed table card with a QR code opens a web app branded for that
restaurant. Diners get games to play while they wait, an anonymous
suggestion box, and cards the owner sets (weekly schedule, tap list or
menu, announcements). The owner gets a private live dashboard, a monthly
guest report, and a neutral Google review prompt shown to every guest.
Success is a table enjoying the wait, complaints reaching the owner
privately before they become public reviews, and more happy guests
reaching the review page.

## Positioning

The app lives on the table itself, in front of a guest who is already in
the room, and it asks for nothing from staff after setup. Feedback is
anonymous and private to the venue; only a few general "what do diners
around here want" answers are pooled across venues, with no name and no
restaurant attached, which gives a small independent the kind of local
read chains pay analytics teams for. Each instance is run by a local
operator who eats in these restaurants and answers their own email.

## Operating Context

The homepage is the lead-facing bare domain. The diner app is reached only
by QR (app.html?v=<venue>); owner dashboard and monthly report are
capability links. Everything is static files on Cloudflare Pages with a
Supabase backend; no build step. Operator branding (name, color, icon or
logo, region wording, contact email) is injected at load from a generated
brand.js and must keep working through data attributes and class hooks
(.cfg-region, .cfg-regionshort, .cfg-brand, .cfg-email, .cfg-story,
.wordmark/.wm-mark/.wm-name, [data-mailto], [data-img]).

## Capabilities and Constraints

- Nine games today (Who Knows Who, Guess the Split, Who Invited You?,
  Wordy, Trivia, All Talk, Cornhole, Quick Pour, Fortune Teller); new
  games ship over time. Two more exist as venue exclusives and never
  appear on the homepage.
- Free first month, no contract, cancel any time. No public price on the
  page today (undecided; do not invent one).
- The Google review prompt is shown to everyone and never rating-gated
  (Google policy and FTC rules). Copy must never imply filtering reviews.
- Homepage copy is operator-neutral: the brand name, region, and story
  come from config. The page must read correctly for any region word.
- Preview-first: homepage changes are reviewed on a preview before they
  ship to any operator.

## Brand Commitments

- Flat color only. No gradients anywhere (a flat accent tint is fine).
- Sans-serif type only.
- No em dashes in copy; short sentences; plain words over jargon.
- The reference brand is "Shore Table" with accent #3a6ea5 and a
  wave-lines mark; other operators substitute their own, so the design
  must hold with any single accent color and any square mark or logo.
- Both homepage actions weigh the same: "Get in touch" (email) and
  "Try the demo".

## Evidence on Hand

- Real product screenshots: public/images/screenshot-1-landing.png,
  screenshot-2-hotseat.png, screenshot-3-survey.png (1170x2469 phone
  captures) and public/images/report.png (a sample monthly report).
- A live demo venue at app.html?v=demo.
- No customer names, counts, testimonials, or quotes may appear yet
  (confirmed 2026-09-07: screenshots only). Leave nothing that reads as a
  claim of scale.

## Product Principles

1. Show the table, not the software: the product is a card on a table
   and a phone in a hand, and the page should prove that first.
2. Nothing for staff to do is the promise; every section should keep
   that true.
3. Private feedback, public reviews, local read: three distinct benefits,
   never blurred into one.
4. Local and personal beats national and polished; the operator is a
   neighbor, and the page should sound like one.
5. Truth over volume: real screenshots and real mechanics; no invented
   proof.
