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
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tablet = size.width >= 600 && size.height >= 500;
    final navigation = tablet ? _tabletNavigation() : _phoneNavigation(context);
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: IndexedStack(index: index, children: pages),
      ),
    );

    return Scaffold(
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
        child: tablet
            ? Row(
                children: [
                  navigation,
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: tablet ? null : navigation,
    );
  }

  Widget _tabletNavigation() => NavigationRail(
    selectedIndex: index,
    onDestinationSelected: select,
    labelType: NavigationRailLabelType.all,
    indicatorColor: Palette.blush,
    destinations: List.generate(
      labels.length,
      (i) => NavigationRailDestination(
        icon: Icon(icons[i], key: ValueKey('tab-${labels[i]}')),
        selectedIcon: Icon(icons[i], key: ValueKey('tab-${labels[i]}')),
        label: Text(labels[i]),
      ),
    ),
  );

  Widget _phoneNavigation(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      color: Palette.mist,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(12);
          final scrolls = constraints.maxWidth < 360 || textScale > 15;
          final itemWidth = scrolls
              ? 72.0
              : constraints.maxWidth / labels.length;
          final destinations = List.generate(
            labels.length,
            (i) => SizedBox(
              width: itemWidth,
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
                      vertical: 6,
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
                            color: index == i ? Palette.blush : Palette.mist,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icons[i], color: Palette.plum, size: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: scrolls
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: destinations,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: destinations
                        .map((destination) => Expanded(child: destination))
                        .toList(),
                  ),
          );
        },
      ),
    ),
  );
}
