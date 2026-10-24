// Development utility: render the original Flutter-painted blossom as native
// launcher assets. Run explicitly with `flutter test tool/render_native_artwork.dart`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/core/widgets.dart';

void main() {
  testWidgets('render original native launcher artwork', (tester) async {
    tester.view.physicalSize = const Size(192, 192);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: const ColoredBox(
          color: Palette.mist,
          child: Center(child: Blossom(size: 168)),
        ),
      ),
    );
    await tester.pump();
    final sizes = <String, int>{
      for (final item in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries)
        'android/app/src/main/res/mipmap-${item.key}/ic_launcher.png':
            item.value,
    };
    final ios = jsonDecode(
      File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final item in ios['images'] as List) {
      sizes['ios/Runner/Assets.xcassets/AppIcon.appiconset/${item['filename']}'] =
          (double.parse((item['size'] as String).split('x').first) *
                  int.parse((item['scale'] as String)[0]))
              .round();
    }
    await tester.runAsync(() async {
      for (final item in sizes.entries) {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: item.value / 192);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(item.key).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }
    });
  });
}
