# Frontend

## Status

No frontend, framework, package manifest, routes, components, styles, fonts, assets or animation library exists. No visual/browser/accessibility/performance test has run. All designs below are proposed; framework selection remains open.

## Shared navigation and boundaries

One authenticated shell exposes seven primary labels: Mind & Wellness, AI Assistant, Appointments & Clinic, Period Tracker, Sisterhood, Women's Health Library, PCOS Insights. Shared home/account/privacy are utilities, not extra primary modules. Desktop navigation is predictable; mobile makes every module reachable through an accessible menu or compact navigation without crowding seven tabs.

Proposed paths: `/app/wellness`, `/app/assistant`, `/app/appointments`, `/app/periods`, `/app/sisterhood`, `/library`, `/app/pcos`. Utilities: `/app`, `/app/settings/privacy`, `/sign-in`, `/onboarding`. Public examples: `/`, `/features`, `/library/articles/{slug}`, `/privacy`, `/accessibility`. These routes do not exist. Reuse public library content without private context.

Shared entry forms, calendars, chart/table pairs, consent selectors and summary previews should follow [Brand identity](BRAND_IDENTITY.md) and [Design system](DESIGN_SYSTEM.md). AI/PCOS/clinician transitions display selected inputs and purpose before access, never preload all records. Community cannot import private records/summaries/AI history.

## Landing storyboard

1. Obsidian/porcelain editorial hero with honest availability, welcoming copy and lightweight organic depth illustration.
2. Seven-module overview connecting record → understand → prepare, with separate private wellness/community boundaries.
3. Keyboard-accessible calendar/chart previews using visibly synthetic data, coverage labels and reset controls.
4. Synthetic summary-selection preview; no real upload/provider booking claims.
5. Transparent sources/review/privacy sections describing only verified capabilities when published.

Use CSS/SVG/static depth first. Optional lazy-loaded 3D needs measured benefit, performance budget, text/keyboard equivalent and static fallback; no dependency is currently justified. Smooth anchors, subtle scroll reveals and short page transitions respect reduced motion and cannot delay forms/hide content/hijack scrolling. Charts/calendars require keyboard access and text/table alternatives.

## States, performance and decisions

Provide empty/loading/success/error/expired-session states throughout. Show denied/revoked consent, insufficient data, stale summaries, offline/extraction/provider uncertainty explicitly. Preserve safe unsaved input on recoverable failures; sensitive persistent browser drafts require a reviewed design. Do not claim save/extraction/booking/delivery success without server evidence. No private results in public caches, static output, analytics or URLs; route guards supplement server authorization.

Proposed goals: WCAG 2.2 AA; 75th-percentile LCP ≤2.5s, INP ≤200ms, CLS ≤0.1. These are not measured results. Evaluate low-end mobile/slow networks before effects. Resolve framework/package manager, rendering model, browser matrix, chart tools, fonts and prototype/public-release scope.
