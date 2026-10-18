# Submission Checklist — mapped to the 12-mark rubric

Deliverables: **PPT · Figma · HTML & CSS** (all three) for topic *Marg — Pune Bus Planner*.

| Marks | Criterion | Evidence to show | Done |
|---|---|---|---|
| 2 | Persona relevance (1) + user needs (1) | Persona slide (Riya, 21, Kothrud → Viman Nagar commuter); needs→feature table; instant commute re-run in Saved | ☑ |
| 2 | Layout structure (1) + logical grouping (1) | Wireframes slide + 8-pt grid callout; Explore/Plan/Results grouping; 3-snap glass draggable sheet (0.14/0.5/0.92) | ☑ |
| 2 | Colour (.5) + alignment (.5) + visual balance (1) | Palette slide with roles; token-driven MargColors; 48dp touch targets; 8-pt rhythm; WCAG AAA contrast | ☑ |
| 1 | Key screens (.5) + components (1→ shown) + timely (.5) | 8 screens light + dark in `proof/final/`; shared components (BusChip, Badge, Card, Sheet, TabBar); early submission | ☑ |
| 3 | Neatness (1) + annotations (1) + completeness (1) | Numbered callouts on every screen; full 60-s walkthrough video `proof/final/marg_demo.mp4`; zero analyze/lint errors | ☑ |

## Deck order (12 slides)
1 Title · 2 Problem/objective · 3 Persona · 4 Needs→features · 5 User flow · 6 Low-fi wireframes · 7 Palette+type · 8 Components · 9–11 Annotated screens · 12 HTML/CSS shots, Figma link, future scope (Metro)

## Figma
- Frame 390×844 (iPhone, matches the Apple brief) and optionally 412×915 (Pixel) variant.
- Variables = `design/tokens.json`. Styles: Large/Title/Headline/Body/Footnote. Auto Layout everywhere. Components with variants (BusChip, Badge, Card selected/default).
- Prototype links: Welcome → Home → Plan → Results → Itinerary → Trip. Add smart-animate on sheet.

## Viva — be ready
- **Why Apple HIG?** Clarity, deference, depth: content-first map, glass sheets don't compete with it.
- **Why blue/green/orange?** System semantic colours: blue = action/bus, green = on-time/fastest, orange = caution/less walking; metro purple reserved.
- **Why bottom sheet?** One-handed reach, keeps map context, three snap heights.
- **How does it serve Riya?** Fast "Where to?", ranked options with trade-offs labelled, saved commute.
- **What would you change after testing?** Add real-time feed if PMPML publishes one; alerts; Marathi localisation.
- **Is "Live" real?** No — it is schedule-based and labelled so; honest by design.
- **Android vs iOS?** Same visual language, platform adaptations: 48 dp targets, gesture insets, predictive back.
- **Future scope?** Pune Metro: data already processed, UI slot + purple tokens reserved.
