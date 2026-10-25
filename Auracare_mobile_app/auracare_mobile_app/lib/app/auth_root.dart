import 'dart:async';

import 'package:flutter/material.dart';

import '../data/appointments.dart';
import '../data/auth_service.dart';
import '../data/records.dart';
import '../data/remote_records.dart';
import '../data/api_client.dart';
import '../data/chat_service.dart';
import '../data/services.dart';
import '../features/auth/auth.dart';
import 'controller_auth_service.dart';
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
  const AuthenticationRoot({
    super.key,
    required this.auth,
    this.recordsFactory,
  });
  final AuraAuthController auth;
  final RecordsRepository Function(AuraAuthController auth)? recordsFactory;
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
    // Immediately cancel pending records before old widgets detach next frame.
    previous?.records.reset();
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
            chatService: auth.mode == AccessMode.authenticated
                ? AuthenticatedChatService(
                    auth: auth,
                    createClient: () => AuraApiClient(
                      config: ApiConfig.fromEnvironment(),
                      tokenProvider: auth,
                    ),
                  )
                : null,
            records: auth.mode == AccessMode.demo
                ? DemoRecordsRepository(sample: false)
                : (widget.recordsFactory ?? authenticatedRecords)(auth),
            appointments: auth.mode == AccessMode.demo
                ? null
                : AppointmentsRepository(store: _MemoryAppointmentStore()),
          );
    if (_session?.records.isRemote == true) unawaited(_session!.records.load());
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
        home: auth.mode == AccessMode.recovery
            ? UpdatePasswordPage(
                auth: ControllerAuthService(auth),
                onPasswordUpdated: (_) {},
              )
            : LoginPage(
                auth: ControllerAuthService(auth),
                onAuthenticated: (_) {},
                onDemoSelected: (sample) {
                  auth.enterDemo();
                  if (sample) _session?.records.reset(sample: true);
                },
                onResendVerification: ControllerAuthService(auth)
                    .resendVerification,
                initialMessage: auth.message ?? auth.error,
              ),
      );
    }
    return AuracareApp(
      key: ValueKey(_boundary),
      session: _session,
      authService: ControllerAuthService(auth),
      externalAuthUser: ControllerAuthService(auth).user,
      externalSignOut: auth.mode == AccessMode.demo
          ? () async => auth.leaveDemo()
          : auth.signOut,
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
                            : _session!.records.isRemote
                            ? _session!.records.loaded
                                  ? 'Signed in • Connected to private cloud records'
                                  : 'Signed in • Cloud records unavailable; status shown below'
                            : 'Signed in • Session-only records; cloud sync is disabled',
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
          if (_session!.records.isRemote)
            ListenableBuilder(
              listenable: _session!.records,
              builder: (context, _) {
                final records = _session!.records;
                return Material(
                  child: Column(
                    children: [
                      if (records.loading) const LinearProgressIndicator(),
                      if (records.loadError != null || !records.loaded)
                        ListTile(
                          title: Text(
                            records.loadError ?? 'Loading health records…',
                          ),
                          trailing: TextButton(
                            onPressed: records.loading ? null : records.load,
                            child: const Text('Retry records'),
                          ),
                        )
                      else
                        TextButton(
                          onPressed: records.load,
                          child: const Text('Refresh records'),
                        ),
                    ],
                  ),
                );
              },
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
