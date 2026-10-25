# Merge & Unwind, spotting/discharge and demo directory

Implemented in the existing Flutter project on 25 October 2026. Initial branch was `main` and the working tree was clean. No branch changes, commits, pushes, database migrations, new packages or Android build-configuration edits were made.

## Entry points and preserved behavior

The actual app has six main destinations and an existing Wellbeing check-in route, rather than a separate Wellbeing tab. The **Merge & Unwind** card is inside that route, reached from Home → Wellbeing check-in. It opens one game screen using the existing Navigator/back behavior; no new main tab was added.

Home/Timeline → Log entry now includes Spotting and Discharge alongside the existing choices. The existing editor, repository, timeline filters, calendar event markers, confirmation dialogs and selected-record appointment summary are reused. The Doctor tab now includes the fictional directory below the existing personal organizer and appointment-preparation entry.

PCOS questionnaire/service code and the separate model/backend projects were not modified. Existing PCOS boundary/failure/retry tests remain part of the passing suite. The Flutter quiz's existing fixture/live-unavailable behavior was preserved; this change does not claim a new live model integration.

## Game implementation

`merge_world.dart` owns the simulation and rules, independently of widgets. It uses a fixed 1/120-second step, gravity, circle contacts, side walls, floor constraints, separation and velocity impulses. The 100 × 140 physics coordinate space is scaled uniformly to the available layout width; these are logical world units, not fixed screen dimensions.

A value maps to radius as `2.6 + 0.8 × value` in world units. New previews are random integers from 1 through 5. Tap or drag on the board to choose a horizontal position and release to drop; a slider and Drop ball button provide an alternative. A brief cooldown prevents accidental rapid duplicate drops.

Only touching equal values merge, and only when their sum is at most 10. Each pair contributes its merged value to the score. Contact processing reserves IDs and queues mutations until after iteration, preventing a ball from being consumed twice. New balls appear near the pair center, are clamped to the walls/floor and are separated from neighbors by subsequent fixed steps. Chain merges continue on later steps. Values 6–10 cannot merge with an equal ball beyond the cap.

The overflow line is visible near the top. A ball must be older than 0.8 seconds, supported and positionally quiet for at least 0.55 seconds before it counts as settled. Settled balls above the line must remain there for 1.8 seconds to end the round. Freshly dropped falling balls therefore do not immediately end a round. Position-based rest detection also handles the small residual velocities produced by support impulses in a tall stack.

Score, next preview, pause/resume, confirmed restart, a calm game-over panel, Play Again and Back are provided. Pause is available in the app bar even when the page is scrolled. The ticker stops on app backgrounding, covering routes, deactivation and disposal. Returning from the background or another route leaves the game paused for explicit resume. Restart clears only the game round. No timers or physics bodies survive disposal. Sound is always off; no audio, ads, purchases, accounts, leaderboards or health-benefit claims were added.

No existing game/physics dependency was present. A small deterministic Dart circle solver was sufficient, so Flame/Forge2D were not added and no external package APIs were introduced. Native device performance, accessibility-service behavior and long-session stress testing remain unverified.

## New health tracking fields

`EntryType` appends `spotting` and `discharge`, preserving prior enum positions/names. `HealthEntry.tracking` is optional, so old records need no new fields or migration. Saving/versioning copies preserve the structured data.

| Field | Spotting | Discharge |
|---|---|---|
| Date/time and declared timezone | Existing editor controls | Existing editor controls |
| Amount | Required: light/moderate/heavy | Required: light/moderate/heavy |
| Color | Optional, free text, up to 80 characters | Optional, free text, up to 80 characters |
| Consistency | Not collected | Optional, free text, up to 80 characters |
| Odor change | Not collected | Optional: yes/no/unsure; null means not recorded |
| Itching/irritation | Not collected | Optional: yes/no/unsure; null means not recorded |
| Notes | Existing optional notes | Existing optional notes |

The UI does not classify choices as normal/abnormal or infer a diagnosis. Spotting never becomes period flow; neither new type adds cycle starts/ends or affects prediction inputs. Timeline cards have distinct icons and readable structured summaries. Date/type filters, empty states, edit, confirmed deletion, failure handling and optimistic versions use the same existing logic.

Selected entries contribute their structured observations to appointment preparation. Free-text notes remain excluded unless the existing include-notes switch is enabled. Unselected observations are not added. Session export includes the optional nested `tracking` map when present. No sensitive input was added to logging or analytics.

**Actual persistence:** health records, including these new observations, remain in memory and disappear on app restart, as before. The UI explicitly says so. The separate Android-persistent personal appointment organizer is unchanged. Game rounds are also memory-only and are not included in health insights or summaries.

## Demo directory

Six fictional doctors cover gynecology, endocrinology and general practice. Every name includes Demo and every clinic includes Example. Cities are labels only. All phone values are the non-dialable `+91 XXXXX XXXXX`; emails use reserved `example.com` addresses.

The notice **Demo directory — fictional doctors and contact details.** appears before the list. Name search, specialty filtering and a no-results state are local operations. Contacts are plain text, with no call, email, map, booking or confirmation action. No real provider credentials, availability or booking status is invented. This directory does not seed or change saved personal appointments.

## Design

The five requested base tokens are exact: Plum `#45364B`, Orchid `#DD7ED9`, Mist `#F4EFF4`, Apricot `#F5B07E`, Blush cloud `#F9E3D8`. Shared compatibility aliases use those base tokens, with Mist foreground on Plum buttons. Existing semantic flow/mood/phase colors were retained to preserve prior calendar distinctions. Existing Roboto typography, rounded cards, spacing and navigation remain. The game uses flat circles, outlines and the base colors; no image, font or package assets were added.

Forms and directory content scroll; the game board uses layout constraints and an aspect ratio. External text/controls respond to system text size, while ball numerals fit their world-scaled circles. System safe areas and keyboard insets are respected.

## Changed files

Paths below are relative to `Auracare_mobile_app/auracare_mobile_app/`.

| Files | Change |
|---|---|
| `lib/features/wellbeing/merge_world.dart` (new) | Pure Dart gravity/contact simulation, merge rules, scoring, rest/overflow and reset. |
| `lib/features/wellbeing/merge_game.dart` (new) | Responsive game UI, painter, input, pause/resume/restart and lifecycle cleanup. |
| `lib/app/navigation.dart` (new), `lib/app/app.dart` | Route observer for covered-route pause. |
| `lib/app/theme.dart` | Exact five requested base tokens, compatibility aliases and readable primary-button contrast. |
| `lib/data/records.dart` | New entry types, optional observation fields, summaries and export/copy preservation. |
| `lib/features/logging/editor.dart` | Game entry card, new log choices and shared tracking forms. |
| `lib/features/timeline/timeline.dart` | Generic Log entry opens the existing chooser; journal-specific entry remains direct. |
| `lib/core/widgets.dart`, `lib/core/calendar.dart` | Distinct new icons, readable summaries and calendar event colors/legend entries. |
| `lib/data/services.dart` | Structured observations in explicitly selected appointment summaries. |
| `lib/data/demo_doctors.dart` (new) | Six fictional non-actionable contacts and search/filter. |
| `lib/features/appointments/demo_directory.dart` (new), `doctor.dart` | Directory embedded in the existing appointment section. |
| `test/merge_world_test.dart` (new) | 13 deterministic physics/rules tests. |
| `test/unwind_tracking_test.dart` (new) | Exact palette, observation CRUD/filtering/summary, legacy compatibility, directory behavior and game lifecycle. |
| `test/layout_test.dart`, `test/redesign_test.dart`, `test/refinement_test.dart` | Expanded layouts, full-tile mood interactions and contrast expectations for the requested palette. |

Relevant FEATURES, USER_FLOWS, DATA_MODEL, DESIGN_SYSTEM, TESTING and MOBILE_UI_HANDOFF Markdown files link to this current implementation note; prior audit history is retained.

## Executed validation

- `dart format lib test`: clean.
- `flutter analyze --no-pub`: no issues found.
- Full Flutter suite with preview capture: **68 tests passed**.
- Includes 13 physics tests for equal/different/non-touching pairs, cap 10, shared collision de-duplication, chain merges, gravity/floor/stacking, overflow grace, pause/reset/random preview range, monotonic radii and finite overlap recovery.
- Includes spotting/discharge create/edit/delete, required amount, optional and unsure values, existing records, date coverage/type filters, selected appointment summaries, distinct icons, directory filtering/no-results/no contact actions, and route/background pause/disposal.
- Layout cases cover 320/390/430 logical pixels at normal and 200% text, including keyboard insets. Game captures pause the actual simulation; the physics behavior is separately exercised by model tests.
- Widget previews generated in ignored `build/previews/`. Game at 390 normal text, spotting at 390 and directory at 320/200% were visually inspected.
- Android ARM64 debug build succeeded: `build/app/outputs/flutter-apk/app-debug.apk`.
- Physical-device gameplay, device-native keyboard and real screen-reader testing were **not performed**. No APK installation or device screen interaction was performed during this task. No claims of native gameplay/performance validation are made.

No known implementation blockers remain. The original application's backend/privacy/clinical limitations remain unchanged; the game makes no treatment claim and the directory is strictly a fictional demo.

## Viewing

Run `flutter run` from the Flutter project folder, then open Home → Wellbeing check-in → Merge & Unwind. Find the two new observation types through Log entry, and the directory by scrolling the Doctor section. Use a full restart for the new route observer; subsequent Dart UI edits can use Hot Reload. Restarting clears the existing in-memory health/game session, but not the independent saved appointment organizer. No commit or push was made.
