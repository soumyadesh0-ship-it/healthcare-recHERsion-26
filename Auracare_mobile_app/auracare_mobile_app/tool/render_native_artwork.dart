// Regenerate Android launcher sizes and UI crops from the integrated logo lockup.
// Run: flutter test tool/render_native_artwork.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('derive brand crops and Android launcher artwork', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        await File('assets/brand/auracare-lockup.png').readAsBytes(),
      );
      final source = (await codec.getNextFrame()).image;
      final w = source.width.toDouble(), h = source.height.toDouble();
      Future<void> render(
        String path,
        ui.Rect crop,
        int width,
        int height,
      ) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
        final scale = (width / crop.width) < (height / crop.height)
            ? width / crop.width
            : height / crop.height;
        final dw = crop.width * scale, dh = crop.height * scale;
        canvas.drawImageRect(
          source,
          crop,
          ui.Rect.fromLTWH((width - dw) / 2, (height - dh) / 2, dw, dh),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }

      final icon = ui.Rect.fromLTRB(w * .155, h * .04, w * .84, h * .775);
      await render('assets/brand/auracare-icon.png', icon, 1024, 1024);
      final wordmark = ui.Rect.fromLTRB(w * .13, h * .785, w * .87, h * .985);
      await render(
        'assets/brand/auracare-wordmark.png',
        wordmark,
        1024,
        (wordmark.height / wordmark.width * 1024).round(),
      );
      for (final item in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        await render(
          'android/app/src/main/res/mipmap-${item.key}/ic_launcher.png',
          icon,
          item.value,
          item.value,
        );
      }
      source.dispose();
      codec.dispose();
    });
  });
}
