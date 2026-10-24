# Design system

> Mobile override (2026-10-25): the explicit mobile brief and [Flutter theme](../Auracare_mobile_app/auracare_mobile_app/lib/app/theme.dart) govern the new demo: five new palette tokens, system sans, 20px gutters, rounded cards/forms, five labeled bottom destinations and >=48px controls. The web/3D layout below is historical proposed scope. See [Mobile UI handoff](MOBILE_UI_HANDOFF.md).

## Status

Proposed only: no tokens, CSS, components or animation tools exist. [Brand identity](BRAND_IDENTITY.md) owns the canonical palette/voice. [Frontend](FRONTEND.md) owns shared navigation. Avoid duplicate conflicting specifications.

## Layout and components

Spacing: 4/8/12/16/24/32/48/64/96px. Public width approximately 1200px, reading width 60–72 characters; mobile gutters about 20px, desktop 40–64px. Content-driven 4/8/12-column layouts around 640/960/1280px are starting points. Support 320px without horizontal page scrolling and text zoom/reflow. Suggested type: fluid hero 40–88px, section 28–48px, card 20–24px, body 16–18px, metadata 14px. Suggested radius: fields 12px/cards 20px; restrained shadows/borders.

| Component | Convention |
| --- | --- |
| Navigation | Seven-module shell, active text/state, skip link, keyboard order and accessible mobile menu |
| Buttons | Verb labels; verified-contrast primary, outlined/text secondary, visible focus/hover/disabled/busy; confirm destructive action |
| Cards | Heading and grouped information; explicit actions, no nested click targets |
| Forms | Persistent labels, optional/required markers, inline help/errors, native controls where practical, preserved safe input and explicit save status |
| Calendar | Keyboard date movement, text selection, open/irregular periods and labeled estimates |
| Chart/table | Labels/patterns beyond colour, visible gaps/coverage, keyboard details and equivalent table/summary |
| Consent/summary | Selected records, purpose/recipient/version, review/withdrawal controls and stale warning |
| Community composer | Deliberate community text only, disclosure guidance and no private-record attachment/prefill |
| Dialog/status | Accessible name/focus/escape/return behavior; announce results without excessive live-region noise |

## Accessibility and states

Target WCAG 2.2 AA, pending verification: semantic headings/landmarks, explicit labels, visible unobscured focus, keyboard operation, accessible dialogs, zoom/reflow and approximately 44px touch targets where practical. Verify actual text/non-text contrast; errors/success cannot rely on colour.

Empty: optional next action. Loading: operation identified/duplicates prevented. Success: only confirmed action. Error: preserve safe input and offer recovery. Also distinguish insufficient data, stale summaries, withdrawn consent, expired sessions, extraction drafts and unknown provider outcomes. Timeouts cannot become apparent success.

## Motion and depth

Suggested feedback 150–220ms, one-time opacity/transform reveals 300–500ms. Page transitions preserve focus/order and never block forms. Progressive enhancement keeps content visible without scripts. Reduced motion removes smooth scrolling, parallax, morphing, chart drawing and animated transitions; use immediate/static equivalents. No scroll hijacking/flashing. Prefer CSS/SVG depth; 3D requires measured benefit, budget and accessible fallback.

Resolve actual tokens/contrast, browser matrix, component ownership, charts and font licenses during foundation work. No rendering/accessibility tests have run.
