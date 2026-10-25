# Brand assets

The supplied AuraCare presentation reference is the design source. No editable SVG or original transparent master was supplied. `auracare-lockup.png` is a cleaned, reference-derived raster prepared using the imagegen skill; it retains the woman/aura/heart composition, lowercase wordmark and tagline without the presentation heading or icon samples. It is white-backed because the transparent extraction damaged the dark lettering. It should not be described as the original editable or pixel-identical master.

- `auracare-lockup.png`: splash logo, aspect ratio preserved.
- `auracare-wordmark.png`: wordmark and tagline crop for onboarding.
- `auracare-icon.png`: icon-only crop, also used to derive Android launcher PNGs.

Regenerate the crops and Android density sizes with:

```powershell
flutter test tool/render_native_artwork.dart
```

The deterministic crop rectangles live in that utility. No iOS icons or build configuration are changed by it. If the original transparent/vector master becomes available, replace the reference-derived asset and review the crop bounds before regenerating. All app surfaces and code-drawn illustrations use solid centralized color tokens; no gradient, shadow or network-image effects were introduced.
