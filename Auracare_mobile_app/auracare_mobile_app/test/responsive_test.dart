import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/appointments.dart';

class _ResponsiveAppointmentStore implements AppointmentStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String json) async {}
}

void main() {
  const destinations = [
    'Home',
    'Timeline',
    'Learn',
    'Insights',
    'Doctor',
    'Profile',
  ];
  const viewports = [
    (width: 320.0, height: 844.0, name: 'very narrow portrait'),
    (width: 360.0, height: 800.0, name: 'compact portrait'),
    (width: 390.0, height: 844.0, name: 'reference portrait'),
    (width: 430.0, height: 932.0, name: 'large phone portrait'),
    (width: 600.0, height: 960.0, name: 'tablet portrait'),
    (width: 844.0, height: 390.0, name: 'landscape'),
  ];

  for (final viewport in viewports) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('all destinations remain available at ${viewport.name}, '
          '${viewport.width} dp and ${textScale}x text', (tester) async {
        tester.view.physicalSize = Size(viewport.width, viewport.height);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        final session = DemoSession(
          appointments: AppointmentsRepository(
            store: _ResponsiveAppointmentStore(),
          ),
        );
        await tester.pumpWidget(
          AuracareApp(session: session, showOnboarding: false),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < destinations.length; i++) {
          final tablet = viewport.width >= 600 && viewport.height >= 500;
          final tab = tablet
              ? find.text(destinations[i])
              : find.byKey(ValueKey('tab-${destinations[i]}'));
          expect(tab, findsOneWidget);
          await tester.ensureVisible(tab);
          if (!tablet) {
            expect(tester.getSemantics(tab).label, destinations[i]);
          }
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (tablet) {
            expect(
              tester
                  .widget<NavigationRail>(find.byType(NavigationRail))
                  .selectedIndex,
              i,
            );
          } else {
            final tabSemantics = find.ancestor(
              of: tab,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == destinations[i],
              ),
            );
            expect(
              tester.widget<Semantics>(tabSemantics).properties.selected,
              true,
            );
          }
        }

        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      });
    }
  }
}
