# Brand identity

> Mobile override (2026-10-25): the explicit mobile brief supersedes the historical palette and typography below for the Flutter app. Use Plum `#45364B`, Orchid `#DD7ED9`, Mist `#F4EFF4`, Apricot `#F5B07E` and Blush Cloud `#F9E3D8`; system sans-serif and original Flutter-painted characters. Orchid is decorative/selected emphasis, not a normal-text background. See [Mobile UI handoff](MOBILE_UI_HANDOFF.md) and immutable [theme tokens](../Auracare_mobile_app/auracare_mobile_app/lib/app/theme.dart). No old palette is used in the product UI.

## Verified status

No logo, fonts, assets, styles or components exist; no existing visual implementation is being replaced. This is the user's specified direction. [Design system](DESIGN_SYSTEM.md) defines component details.

## Personality and voice

Premium, editorial, welcoming, calm, human and contemporary. Confident navigation with empathetic plain-language explanations. Say "Your records, in context" and "These dates are estimates." Avoid diagnoses, judgment about missed entries or pressure to disclose. Respect diverse life stages, bodies and goals.

## Canonical five-colour palette

| Colour | Hex | Role |
| --- | --- | --- |
| Obsidian Black | #17151C | Primary text, dark hero and strong surfaces |
| Porcelain White | #FAF8F5 | Main canvas and text on dark surfaces |
| Electric Violet | #8B5CF6 | Brand emphasis, selected states and focus accents |
| Living Coral | #FF746C | Warm accent and labeled data series |
| Vital Teal | #43C6AC | Secondary data and completion accents |

Porcelain/obsidian dominate. Accent colour alone cannot signal error, success, symptoms or clinical meaning. Prefer obsidian text on accent fills, then verify actual pairs/focus states. Porcelain on violet is not approved for normal text without contrast verification. Target 4.5:1 normal text, 3:1 large text and applicable non-text UI contrast. Base colours are fixed; semantic variants need documented contrast evaluation.

## Typography, layout and interaction

Direction: editorial serif marketing headlines and readable sans-serif body/application UI. Fraunces-like and Source Sans 3-like styles are references, not installed/final licensed choices. Review licenses/subsets before self-hosting; retain system fallbacks. Body 16–18px, line height 1.5–1.7, reading width 60–72 characters and tabular data numerals.

Generous whitespace and selective asymmetric public layouts; predictable aligned private records. Buttons use concise verbs, cards group related content, forms retain labels/optional indicators/errors, and charts include text/table equivalents. Responsive reading order, keyboard access and privacy controls take priority over decorative layout.

Make the landing memorable through labeled synthetic interactive previews, gentle scrolling/reveals, thoughtful page continuity and lightweight depth. Respect reduced motion and performance; keep content visible without animation/scripts. No forced 3D dependency. Empty states welcome optional participation, loading identifies the operation, success requires evidence and errors explain recovery. Preserve honest booking/estimate/report-draft status.

Open: wordmark, final font licenses, imagery rights, contrast-qualified tokens and user research. No visual/accessibility/performance validation has occurred. See [Frontend](FRONTEND.md).
