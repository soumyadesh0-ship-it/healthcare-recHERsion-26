import 'package:flutter/material.dart';

import 'theme.dart';
import 'session.dart';
import '../core/widgets.dart';
import '../features/home/home.dart';
import '../features/timeline/timeline.dart';
import '../features/learn/learn.dart';
import '../features/insights/insights.dart';
import '../features/profile/profile.dart';
import '../features/appointments/doctor.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  int? lastHomeRequest;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final request = SessionScope.of(context).homeRequest;
    if (lastHomeRequest != null && lastHomeRequest != request) index = 0;
    lastHomeRequest = request;
  }

  void select(int value) {
    setState(() => index = value);
    final repo = SessionScope.of(context).appointments;
    if (value == 4 && !repo.loaded && !repo.busy) repo.load();
  }

  static const labels = [
    'Home',
    'Timeline',
    'Learn',
    'Insights',
    'Doctor',
    'Profile',
  ];
  static const icons = [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.menu_book_outlined,
    Icons.insights_outlined,
    Icons.medical_services_outlined,
    Icons.person_outline,
  ];
  final pages = const [
    HomePage(),
    TimelinePage(),
    LearnPage(),
    InsightsPage(),
    DoctorPage(),
    ProfilePage(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(index == 0 ? 'auracare' : labels[index]),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(demoBadgeHeight(context)),
        child: DemoBadge(),
      ),
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: IndexedStack(index: index, children: pages),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Material(
        color: Palette.mist,
        child:
            MediaQuery.textScalerOf(context).scale(14) > 20 ||
                MediaQuery.sizeOf(context).width < 360
            ? LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  children: List.generate(
                    labels.length,
                    (i) => SizedBox(
                      width: constraints.maxWidth / 2,
                      child: Semantics(
                        selected: index == i,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: TextButton(
                            key: ValueKey('tab-${labels[i]}'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 56),
                              backgroundColor: index == i
                                  ? Palette.blush
                                  : Palette.mist,
                            ),
                            onPressed: () => select(i),
                            child: Text(labels[i], textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    labels.length,
                    (i) => Expanded(
                      child: Semantics(
                        selected: index == i,
                        button: true,
                        label: labels[i],
                        excludeSemantics: true,
                        child: InkWell(
                          key: ValueKey('tab-${labels[i]}'),
                          onTap: () => select(i),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 2,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index == i
                                        ? Palette.blush
                                        : Palette.mist,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(icons[i], color: Palette.plum),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  labels[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: index == i
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
