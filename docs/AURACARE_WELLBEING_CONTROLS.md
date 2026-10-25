# Wellbeing controls and screenshot palette

Latest UI update, 25 October 2026. This handoff supersedes the older five-color palette and the earlier mood-to-editor flow. No applicable AGENTS.md or existing breathing implementation was found. Existing game physics, records, appointments, illustrations, six-tab navigation and typography are retained. No packages, backend calls, analytics, commits or pushes were added.

## Appearance

Shared tokens match the approved reference: white #FFFFFF, inputs #FAF8FB, pink cards/selection #F9DFEA, blue #A6BCE1, lavender #E7DEF1 and dark plum text #34283C. Existing illustration accents and semantic calendar colors remain. Filled buttons use dark plum on lavender; interactive text uses the darker action token. Rounded card shapes and spacing are retained.

## Wellbeing

Home → Wellbeing check-in retains the Merge & Unwind card and its exact subtitle. Mood tiles follow three columns: Happy / Sad / Tired, then Calm / Anxious / Energetic. Tiles use existing characters, responsive illustration sizes and wrapping labels. Selection highlights pink and updates one supportive live-region message beneath the grid. The initially blank feedback area reserves 100 logical pixels and can grow. No decorative animation was added, so there are no mood effect controllers or repeating effects.

Mood selection lives only in this screen's state. It does not navigate, write records, persist data or emit analytics. Anxious feedback offers explicit Try breathing (scroll to section, no auto-start) and Play Merge & Unwind actions. Separate mood tracking remains available from Home/Timeline → Log entry → Mood, which opens the existing record editor directly.

## Game input

The board supports tap-to-position-and-drop and drag-to-position/release-to-drop. Flutter's gesture arena separates tap and pan recognition, with one completion handler and a gesture flag cleared after release/cancellation. The slider updates the same pending position; onChangeStart arms a user gesture and onChangeEnd drops once. onChanged alone only positions, allowing accessibility adjustments without unintended drops. The existing Drop ball button remains an accessible explicit drop alternative. Preview and slider stay synchronized; positions clamp using the pending radius and walls. Pause clears gesture flags and world.canDrop rejects cooldown, pause and game-over drops. Physics, scoring, random previews and the maximum value of 10 are unchanged.

## Breathing pause

The inline section offers 1, 3 and 5 minutes, default 1, remaining time, Start, Pause breathing / Resume breathing and Reset. Inhale lasts 4 seconds, exhale 6, with no hold. A circle expands/contracts with elapsed phase; reduced motion leaves it still while text/time continue. Guidance and completion copy follow the brief. Nothing starts automatically.

BreathingClock accumulates differences between monotonic system frame timestamps, rather than counting ticks, so delayed frames do not lose session time. A ticker refreshes the UI only while running. Backgrounding, covering routes and leaving the screen pause it; returning requires explicit resume. Automatic keep-alive retains an in-memory session when its list item scrolls out of view. Observers and ticker are cleaned up on disposal. No health logging, storage, sound or therapeutic claims were added.

## Changed files

Paths relative to Auracare_mobile_app/auracare_mobile_app:

- lib/app/theme.dart — reference palette and button contrast.
- lib/features/logging/editor.dart — ordered ephemeral mood feedback, explicit activities, direct separate logging route.
- lib/features/wellbeing/merge_game.dart — release-to-drop slider, gesture guards and synchronized radius-clamped aim.
- lib/features/wellbeing/breathing.dart — new inline timer, clock, lifecycle handling and reduced motion.
- test/wellbeing_controls_test.dart — gesture, feedback layout, timing, lifecycle and reduced-motion checks.
- test/merge_world_test.dart — explicit paused/game-over drop rejection assertions.
- test/redesign_test.dart — replace superseded mood-save interaction with ephemeral feedback check.
- test/refinement_test.dart and test/unwind_tracking_test.dart — current palette/contrast expectations.

Repository docs/MOBILE_UI_HANDOFF.md points here. Earlier feature handoffs remain historical.

## Validation

- `dart format lib test`: 43 files formatted; final formatting completed.
- `flutter analyze --no-pub`: no issues.
- Final `flutter test --no-pub --concurrency=4`: all 72 tests passed (1 minute 21 seconds), log `build/wellbeing-final-tests.log`.
- Layout coverage includes 320/390/430 widths at normal and doubled text sizes. Additional reduced-motion tests verify the breathing circle stays still while time/guidance advances. Gesture tests exercise actual slider drag/release, board tap and board drag; physics tests reject paused/game-over drops. Mood tests verify layout, replacing feedback, no editor/navigation and no repository writes.
- Preview images from the earlier capture run are under ignored `build/previews/`; inspected narrow Wellbeing previews at normal/doubled text. One superseded mood workflow test failed in that first run; it was updated to exercise separate Log entry → Mood tracking, then the full suite passed as above.
- `git diff --check`: clean. No APK was rebuilt or installed for this update. Physical Android gestures, TalkBack announcements and device background/resume behavior have not been tested on hardware.
