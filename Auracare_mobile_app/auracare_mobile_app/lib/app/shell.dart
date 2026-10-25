import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'session.dart';
import 'theme.dart';
import '../core/brand.dart';
import '../core/widgets.dart';
import '../features/home/home.dart';
import '../features/timeline/timeline.dart';
import '../features/learn/learn.dart';
import '../features/insights/insights.dart';
import '../features/profile/profile.dart';
import '../features/appointments/doctor.dart';
import '../features/pcos_quiz/quiz.dart';
import '../features/logging/editor.dart';
import '../features/sisterhood/sisterhood.dart';
import '../features/chat/chat.dart';

enum AppDestination {
  home('Home', Icons.home_outlined),
  wellbeing('Wellbeing', Icons.spa_outlined),
  doctor('Doctor', Icons.medical_services_outlined),
  timeline('Timeline', Icons.calendar_month_outlined),
  quiz('PCOS Quiz', Icons.assignment_outlined);

  const AppDestination(this.label, this.icon);
  final String label;
  final IconData icon;
  String get route => '/app/$name';
  static AppDestination? fromRoute(String? route) => values
      .where((d) => d.route == route || (d == quiz && route == '/app/pcos'))
      .firstOrNull;
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialDestination = AppDestination.home,
    this.authUser,
    this.onSignOut,
  });
  final AppDestination initialDestination;
  final AuthUser? authUser;
  final Future<void> Function()? onSignOut;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final scaffold = GlobalKey<ScaffoldState>();
  late AppDestination selected = widget.initialDestination;
  int? lastHomeRequest;
  final visited = <AppDestination>{};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final request = SessionScope.of(context).homeRequest;
    if (lastHomeRequest != null && lastHomeRequest != request) {
      selected = AppDestination.home;
    }
    lastHomeRequest = request;
    visited.add(selected);
    if (selected == AppDestination.doctor) loadAppointments();
  }

  void loadAppointments() {
    final repo = SessionScope.of(context).appointments;
    if (!repo.loaded && !repo.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) repo.load();
      });
    }
  }

  void select(AppDestination destination) {
    setState(() {
      selected = destination;
      visited.add(destination);
    });
    if (destination == AppDestination.doctor) loadAppointments();
  }

  Widget page(AppDestination d) => switch (d) {
    AppDestination.home => HomePage(
      displayName: widget.authUser?.displayName,
      onWellbeing: () => select(AppDestination.wellbeing),
      onQuiz: () => select(AppDestination.quiz),
    ),
    AppDestination.wellbeing => MoodCheckInPage(
      embedded: true,
      active: selected == d,
    ),
    AppDestination.doctor => const DoctorPage(),
    AppDestination.timeline => const TimelinePage(),
    AppDestination.quiz => QuizPage(
      embedded: true,
      active: selected == d,
      onDoctor: () => select(AppDestination.doctor),
      onExit: () => select(AppDestination.home),
    ),
  };
  void drawerPage(Widget page, String route) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: route),
        builder: (_) => page is UnavailablePage || page is ChatPage
            ? page
            : Scaffold(
                appBar: AppBar(title: const AuraCareBrandHeader()),
                body: SafeArea(child: page),
              ),
      ),
    );
  }

  Future<void> signOutAndReturn() async {
    await widget.onSignOut?.call();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget get profile => ProfilePage(
    authUser: widget.authUser,
    onSignOut: widget.onSignOut == null ? null : signOutAndReturn,
  );

  Widget drawerItem(String title, IconData icon, Widget page, String route) =>
      ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: () => drawerPage(page, route),
      );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: selected == AppDestination.home || selected == AppDestination.quiz,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && selected != AppDestination.quiz) {
        select(AppDestination.home);
      }
    },
    child: Scaffold(
      key: scaffold,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('open-drawer'),
          tooltip: 'Open navigation menu',
          onPressed: () => scaffold.currentState!.openDrawer(),
          icon: const AuraLogoIcon(),
        ),
        title: const Text('auracare'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            demoBadgeHeight(context, isAuthenticated: widget.authUser != null),
          ),
          child: DemoBadge(isAuthenticated: widget.authUser != null),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const AuraLogo(width: 160),
                    drawerItem(
                      'Profile',
                      Icons.person_outline,
                      profile,
                      '/app/profile',
                    ),
                    drawerItem(
                      'Learn',
                      Icons.menu_book_outlined,
                      const LearnPage(),
                      '/app/learn',
                    ),
                    drawerItem(
                      'Insights',
                      Icons.insights_outlined,
                      const InsightsPage(),
                      '/app/insights',
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('More from Auracare'),
                    ),
                    drawerItem(
                      'AI Assistant',
                      Icons.chat_bubble_outline,
                      const ChatPage(),
                      '/app/assistant',
                    ),
                    drawerItem(
                      'Sisterhood',
                      Icons.people_outline,
                      const SisterhoodPage(),
                      '/app/sisterhood',
                    ),
                    ListTile(
                      leading: const Icon(Icons.local_hospital_outlined),
                      title: const Text('Appointment & Clinic'),
                      onTap: () {
                        Navigator.pop(context);
                        select(AppDestination.doctor);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('profile-footer'),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  widget.authUser?.displayName ??
                      (widget.authUser == null ? 'Alex' : 'Your account'),
                ),
                subtitle: Text(
                  widget.authUser?.email ??
                      (widget.authUser == null ? 'Demo profile' : 'Signed in'),
                ),
                onTap: () => drawerPage(profile, '/app/profile'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: AppDestination.values.indexOf(selected),
          children: [
            for (final d in AppDestination.values)
              TickerMode(
                enabled: selected == d,
                child: visited.contains(d) ? page(d) : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: Palette.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelSize = MediaQuery.textScalerOf(context).scale(12);
              final minimumWidth =
                  64.0 + (labelSize > 12 ? (labelSize - 12) * 5 : 0);
              final itemWidth =
                  (constraints.maxWidth / AppDestination.values.length).clamp(
                    minimumWidth,
                    double.infinity,
                  );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.sizeOf(context).width,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final d in AppDestination.values)
                        Semantics(
                          selected: selected == d,
                          button: true,
                          label: d.label,
                          excludeSemantics: true,
                          child: SizedBox(
                            width: itemWidth,
                            child: InkWell(
                              key: ValueKey('tab-${d.label}'),
                              onTap: () => select(d),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: selected == d
                                            ? Palette.blush
                                            : Palette.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        child: Icon(d.icon, color: Palette.ink),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected == d
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
