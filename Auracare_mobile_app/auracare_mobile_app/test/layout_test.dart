import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/features/cycle/cycle.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/quiz.dart';

const capture = bool.fromEnvironment('CAPTURE_PREVIEWS');
const flutterSdk = String.fromEnvironment('FLUTTER_SDK');
void main() {
  setUpAll(() async {
    if (capture && flutterSdk.isNotEmpty) {
      final font = FontLoader('Roboto');
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$flutterSdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$flutterSdk/bin/cache/artifacts/material_fonts/roboto-bold.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$flutterSdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    }
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'forms, cycle and quiz at $width / $scale with keyboard inset',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.view.resetViewInsets();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final session = DemoSession()..cycleEnabled = true;
          final boundary = GlobalKey();
          Future<void> frame(
            Widget page,
            String name, {
            bool keyboard = false,
          }) async {
            tester.view.viewInsets = FakeViewPadding(
              bottom: keyboard ? 280 : 0,
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: SessionScope(
                  session: session,
                  child: MaterialApp(
                    key: ValueKey(name),
                    theme: auracareTheme(),
                    home: page,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            if (keyboard) {
              final field = find.byType(TextFormField).last;
              await tester.ensureVisible(field);
              await tester.pumpAndSettle();
              await tester.tap(field);
              await tester.pump();
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$name at $width / $scale',
            );
            if (capture) {
              await tester.runAsync(() async {
                final render =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await render.toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/previews/${name}_${width.toInt()}_${scale.toInt()}x.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }

          await frame(const CyclePage(), 'cycle');
          await frame(
            const EntryEditor(type: EntryType.journal),
            'journal_keyboard',
            keyboard: true,
          );
          await frame(
            const EntryEditor(
              type: EntryType.symptom,
              key: ValueKey('symptom'),
            ),
            'symptom_keyboard',
            keyboard: true,
          );
          await frame(const QuizPage(), 'quiz_intro');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.view.viewInsets = const FakeViewPadding();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: AuracareApp(session: session, showOnboarding: false),
            ),
          );
          await tester.pumpAndSettle();
          if (capture) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'build/previews/home_${width.toInt()}_${scale.toInt()}x.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          session.dispose();
        },
      );
    }
  }
}
