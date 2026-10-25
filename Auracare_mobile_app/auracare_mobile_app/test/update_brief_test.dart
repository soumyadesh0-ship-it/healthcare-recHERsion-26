import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/shell.dart';
import 'package:auracare_mobile_app/data/cycles.dart';
import 'package:auracare_mobile_app/data/appointments.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:auracare_mobile_app/features/wellbeing/breathing.dart';
import 'package:auracare_mobile_app/features/wellbeing/breath_haptics.dart';
import 'package:auracare_mobile_app/features/wellbeing/ball_face.dart';
import 'package:auracare_mobile_app/features/wellbeing/merge_world.dart';

import 'widget_test.dart' as helper;

class _MemoryAppointmentStore implements AppointmentStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String json) async {}
}

void main() {
  test(
    'experimental contract encoding preserves nulls, BMI and regular meaning',
    () {
      final answers = QuizAnswers();
      expect(answers.toJson()['known_pcos_diagnosis'], isNull);
      expect(
        answers.toModelJson().containsKey('known_pcos_diagnosis'),
        isFalse,
      );
      expect(answers.toModelJson()['bmi'], isNull);
      for (final key in quizFields.keys) {
        expect(answers.toModelJson()[key], isNull);
      }
      answers.binary['regular_periods'] = 1;
      answers.binary['acne'] = 0;
      answers.kg = 64;
      answers.cm = 160;
      answers.knownDiagnosis = true;
      expect(answers.toModelJson()['regular_periods'], 1);
      expect(answers.toModelJson()['acne'], 0);
      expect(answers.toModelJson()['known_pcos_diagnosis'], true);
      expect(answers.toModelJson()['bmi'], closeTo(25, .001));
      expect(answers.toModelJson().keys.toSet(), {
        'age',
        'bmi',
        ...quizFields.keys,
        'known_pcos_diagnosis',
      });
      for (final d in AppDestination.values) {
        expect(AppDestination.fromRoute(d.route), d);
      }
    },
  );
  test(
    'all ten face states render; radii increase; physics cap remains ten',
    () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (var value = 1; value <= 10; value++) {
        canvas.save();
        canvas.translate(value * 50, 50);
        paintBallFace(canvas, value, MergeWorld.radiusFor(value));
        canvas.restore();
        expect(ballColor(value).a, 1);
        if (value > 1) {
          expect(
            MergeWorld.radiusFor(value),
            greaterThan(MergeWorld.radiusFor(value - 1)),
          );
        }
      }
      recorder.endRecording().dispose();
      expect(
        MergeWorld.canMerge(
          MergeBall(id: 1, value: 5, x: 10, y: 10),
          MergeBall(id: 2, value: 5, x: 10, y: 10),
        ),
        isTrue,
      );
      expect(
        MergeWorld.canMerge(
          MergeBall(id: 1, value: 6, x: 10, y: 10),
          MergeBall(id: 2, value: 6, x: 10, y: 10),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'breathing haptics occur once per phase and cancel on pause/background/dispose',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cues = <BreathCue>[];
      final haptics = BreathHaptics(
        pulse: (cue) async {
          cues.add(cue);
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BreathingSection(haptics: haptics),
            ),
          ),
        ),
      );
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
        true,
      );
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      expect(cues, [BreathCue.inhale]);
      await tester.pump(const Duration(seconds: 4));
      expect(cues, [BreathCue.inhale, BreathCue.exhale]);
      await tester.pump(const Duration(milliseconds: 120));
      expect(cues, [BreathCue.inhale, BreathCue.exhale, BreathCue.exhale]);
      await tester.pump(const Duration(seconds: 1));
      expect(cues.length, 3);
      await tester.tap(find.text('Pause breathing'));
      await tester.pump();
      expect(cues.last, BreathCue.pause);
      await tester.tap(find.text('Resume breathing'));
      await tester.pump();
      expect(cues.last, BreathCue.exhale);
      final count = cues.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(cues.length, count);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Resume breathing'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      final disposed = cues.length;
      await tester.pump(const Duration(seconds: 1));
      expect(cues.length, disposed);
    },
  );
  testWidgets('unsupported haptics are safe and stop scheduled pulses', (
    tester,
  ) async {
    var calls = 0;
    final haptics = BreathHaptics(
      pulse: (_) async {
        calls++;
        throw MissingPluginException();
      },
    );
    await haptics.cue(BreathCue.exhale);
    await tester.pump(const Duration(seconds: 1));
    await haptics.cue(BreathCue.finish);
    expect(calls, 1);
    expect(haptics.supported, isFalse);
    haptics.cancel();
  });
  testWidgets(
    'haptic completion and explicit reset cancel pending exhale pulse',
    (tester) async {
      final cues = <BreathCue>[];
      final haptics = BreathHaptics(pulse: (cue) async => cues.add(cue));
      await haptics.cue(BreathCue.exhale);
      haptics.cancel();
      await tester.pump(const Duration(seconds: 1));
      expect(cues, [BreathCue.exhale]);
      await haptics.cue(BreathCue.finish);
      await tester.pump(const Duration(seconds: 1));
      expect(cues, [BreathCue.exhale, BreathCue.finish]);
      haptics.cancel();
    },
  );
  testWidgets(
    'breathing completion cues once and inactive tabs cancel pending pulses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cues = <BreathCue>[];
      final haptics = BreathHaptics(
        pulse: (cue) async {
          cues.add(cue);
        },
      );
      Future<void> frame(bool active) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BreathingSection(active: active, haptics: haptics),
            ),
          ),
        ),
      );
      await frame(true);
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
        true,
      );
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(cues.where((c) => c == BreathCue.finish).length, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(cues.where((c) => c == BreathCue.finish).length, 1);
      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      final count = cues.length;
      await frame(false);
      await tester.pump(const Duration(seconds: 1));
      expect(cues.length, count);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'period calendar opens immediately; end without start stays an end',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      addTearDown(session.dispose);
      await helper.show(tester, const LogEntryPage(), session);
      expect(find.text('Mood'), findsNothing);
      await helper.tapText(tester, 'Period');
      expect(
        find.byKey(ValueKey('calendar-day-${dayLabel(DateTime.now())}')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(ValueKey('calendar-day-${dayLabel(DateTime.now())}')),
      );
      await tester.tap(
        find.byKey(ValueKey('calendar-day-${dayLabel(DateTime.now())}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(find.byKey(const ValueKey('entry-note')), findsNothing);
      await helper.tapText(tester, 'Medium');
      await helper.tapText(tester, 'Period end');
      await helper.tapText(tester, 'Save demo entry');
      final saved = session.records.entries.single;
      expect(saved.flowIntensity, FlowIntensity.moderate);
      expect(saved.periodStart, isFalse);
      expect(saved.periodEnd, isTrue);
      expect(CycleHistory(session.records.entries).periods, isEmpty);
    },
  );
  testWidgets('inline period calendar keeps both date digits at doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    addTearDown(session.dispose);
    await helper.show(
      tester,
      EntryEditor(type: EntryType.bleeding, day: DateTime(2026, 10, 25)),
      session,
    );
    final day = find.text('25');
    await tester.ensureVisible(day);
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(day);
    // Paragraph widths round to logical pixels; glyph metrics stay fractional.
    final secondDigit = paragraph.getBoxesForSelection(
      const TextSelection(baseOffset: 1, extentOffset: 2),
    );
    expect(secondDigit, isNotEmpty);
    expect(secondDigit.last.right, lessThanOrEqualTo(paragraph.size.width + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'historical period retains unknown flags, flow, date and hidden notes when edited',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      addTearDown(session.dispose);
      final entry = HealthEntry(
        id: 'legacy',
        type: EntryType.bleeding,
        title: 'Bleeding',
        when: DateTime(2026, 4, 2, 11, 30),
        zone: 'UTC',
        note: '  Original note.  ',
      );
      await tester.runAsync(() => session.records.save(entry));
      await helper.show(
        tester,
        EntryEditor(type: entry.type, entry: session.records.entries.single),
        session,
      );
      await helper.tapText(tester, 'Save demo entry');
      final saved = session.records.entries.single;
      expect(saved.periodStart, isNull);
      expect(saved.periodEnd, isNull);
      expect(saved.flowIntensity, FlowIntensity.unspecified);
      expect(saved.note, entry.note);
      expect(saved.when, entry.when);
      expect(saved.version, 2);
      expect(saved.toJson()['note'], entry.note);
    },
  );
  testWidgets('quiz system Back steps within quiz before returning Home', (
    tester,
  ) async {
    await tester.pumpWidget(const AuracareApp(showOnboarding: false));
    await tester.pumpAndSettle();
    await helper.tapTab(tester, 'PCOS Quiz');
    await helper.tapText(tester, 'Begin questionnaire');
    await helper.tapText(tester, 'No');
    await helper.tapText(tester, 'Continue');
    expect(find.text('Question 2 of 9'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 9'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Begin questionnaire'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('A little space\nfor you.'), findsOneWidget);
  });

  testWidgets(
    'drawer logo, footer and all destinations reuse existing screens',
    (tester) async {
      final session = DemoSession(
        appointments: AppointmentsRepository(store: _MemoryAppointmentStore()),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-Learn')), findsNothing);
      expect(find.byKey(const ValueKey('tab-Profile')), findsNothing);
      expect(find.text('More from Auracare'), findsNothing);
      for (final item in [
        'Profile',
        'Learn',
        'Insights',
        'AI Assistant',
        'Sisterhood',
      ]) {
        await helper.drawerPage(tester, item);
        expect(find.byType(Drawer), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('open-drawer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-footer')));
      await tester.pumpAndSettle();
      expect(find.text('Fictional demo profile'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await helper.drawerPage(tester, 'Appointment & Clinic');
      expect(find.text('Your next conversation.'), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
    },
  );
}
