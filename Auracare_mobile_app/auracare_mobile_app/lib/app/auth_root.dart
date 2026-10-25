import 'package:flutter/material.dart';

import '../data/appointments.dart';
import '../data/auth_service.dart';
import '../data/records.dart';
import '../data/api_client.dart';
import '../data/services.dart';
import '../features/auth/auth_page.dart';
import 'app.dart';
import 'session.dart';
import 'theme.dart';

class _MemoryAppointmentStore implements AppointmentStore {
  String? _json;
  @override
  Future<String?> read() async => _json;
  @override
  Future<void> write(String json) async {
    _json = json;
  }
}

/// Changes only the entry boundary. The existing shell and health pages remain
/// local prototypes. Each account/mode boundary disposes its previous records.
class AuthenticationRoot extends StatefulWidget {
  const AuthenticationRoot({super.key, required this.auth});
  final AuraAuthController auth;
  @override
  State<AuthenticationRoot> createState() => _AuthenticationRootState();
}

class _AuthenticationRootState extends State<AuthenticationRoot> {
  DemoSession? _session;
  String? _boundary;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_changed);
    _syncSession();
  }

  void _syncSession() {
    final auth = widget.auth;
    final next = switch (auth.mode) {
      AccessMode.demo => 'demo',
      AccessMode.authenticated => 'account:${auth.userId}',
      _ => null,
    };
    if (_boundary == next) return;
    final previous = _session;
    _boundary = next;
    _session = next == null
        ? null
        : DemoSession(
            quizService: auth.mode == AccessMode.authenticated
                ? AuthenticatedQuizService(
                    auth: auth,
                    createClient: () => AuraApiClient(
                      config: ApiConfig.fromEnvironment(),
                      tokenProvider: auth,
                    ),
                  )
                : null,
            records: DemoRecordsRepository(sample: false),
            appointments: auth.mode == AccessMode.demo
                ? null
                : AppointmentsRepository(store: _MemoryAppointmentStore()),
          );
    // Existing widgets detach their listeners before the old session is disposed.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(_syncSession);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_changed);
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    if (_session == null) {
      return MaterialApp(
        title: 'AuraCare',
        theme: auracareTheme(),
        debugShowCheckedModeBanner: false,
        home: AuthPage(auth: auth),
      );
    }
    return AuracareApp(
      key: ValueKey(_boundary),
      session: _session,
      showOnboarding: auth.mode == AccessMode.demo,
      accessWrapper: (context, child) => Column(
        children: [
          Material(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        auth.mode == AccessMode.demo
                            ? 'Synthetic demo • No account access'
                            : 'Signed in • Health records stay local',
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('auth-exit'),
                      onPressed: auth.busy
                          ? null
                          : auth.mode == AccessMode.demo
                          ? auth.leaveDemo
                          : auth.signOut,
                      child: Text(
                        auth.mode == AccessMode.demo ? 'Exit demo' : 'Sign out',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
