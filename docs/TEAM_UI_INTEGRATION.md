# Teammate UI and PCOS integration

The missing sidebar was on `origin/md_modification` at `87de90b`, not on `main`.
Pulling `main` alone brought in `cf374ab` (ui-9) but could not include the other
branch's drawer/navigation and wellbeing controls. The phone also retained an
APK built before the main sync until it was rebuilt and installed.

Local branch `integration/teammate-ui-pcos` combines main's `fbcac6d` with that
UI branch. The intended resolution is:

- Keep the drawer, profile footer and Home / Wellbeing / Doctor / Timeline /
  PCOS Quiz destinations, including route names, lazy tab state and back handling.
- Keep the teammate's period flow editor, breathing haptics and wellbeing/game
  controls. Profile, Learn and Insights use their original screens in the drawer.
- Preserve Supabase login/session restoration, authenticated badge and profile
  sign-out. Drawer profile links receive the real account and sign-out callback.
- Preserve the approved pastel flashcards and live Random Forest integration.
  The quiz supports both standalone routes and the new embedded tab; inactive
  tabs do not intercept system Back. Switching accounts still clears answers and
  discards pending results. The six binary model feature keys are unchanged.
- Keep the existing centralized palette and official icon-only brand artwork.
  The logo opens the navigation drawer. No second profile bottom tab is added.
- Reconcile old six-tab/onboarding tests with the five-tab/drawer and retained
  login flow rather than restoring obsolete navigation or bypassing sign-in.

No code from the unrelated `integration/frontend-backend` branch is included;
that branch implements an alternative authentication/networking stack. Remote
branches are separate histories, not additional folders automatically copied by
`git pull`.

GitHub `main` remains separate while the combined UI is checked locally. The
source tree reflects the current local integration branch; a rebuilt APK is
required to reflect those source changes on the phone. Existing local backend
and USB-forwarding instructions remain in `PCOS_MODEL_INTEGRATION.md`.

Validation on 2026-10-25: Flutter analysis reported no issues and all 139 tests
passed. The combined debug APK built successfully and was installed on the
connected Motorola Edge 30. The five destinations and sidebar were verified
on-device with the restored signed-in account. Sidebar capture is available in
the Flutter app's ignored `build/previews/teammate-sidebar-phone.png`.
The resolved merge is staged locally for review; it has not been committed or
pushed. The existing `main` commit remains unchanged.
