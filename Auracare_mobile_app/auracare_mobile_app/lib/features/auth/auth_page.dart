import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../data/auth_service.dart';

enum AuthFormMode { login, register, forgot }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.auth});
  final AuraAuthController auth;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  AuthFormMode mode = AuthFormMode.login;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void changeMode(AuthFormMode next) {
    setState(() {
      mode = next;
      password.clear();
      confirm.clear();
      form.currentState?.reset();
    });
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final auth = widget.auth;
    if (auth.mode == AccessMode.recovery) {
      await auth.updatePassword(password.text);
    } else {
      switch (mode) {
        case AuthFormMode.login:
          await auth.signIn(email.text.trim(), password.text);
        case AuthFormMode.register:
          await auth.signUp(email.text.trim(), password.text);
        case AuthFormMode.forgot:
          await auth.requestPasswordReset(email.text.trim());
      }
    }
    // Passwords are never retained across completed attempts.
    if (mounted) {
      password.clear();
      confirm.clear();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      final recovery = auth.mode == AccessMode.recovery;
      final needsPassword = recovery || mode != AuthFormMode.forgot;
      final newPassword = recovery || mode == AuthFormMode.register;
      final title = recovery
          ? 'Choose a new password'
          : switch (mode) {
              AuthFormMode.login => 'Welcome to AuraCare',
              AuthFormMode.register => 'Create your account',
              AuthFormMode.forgot => 'Reset your password',
            };
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        const Center(child: AuraLogo(width: 230)),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Account access does not upload local records. Health features remain a synthetic local demo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (!recovery)
                          TextFormField(
                            key: const ValueKey('auth-email'),
                            controller: email,
                            enabled: !auth.busy,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) =>
                                value == null ||
                                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(value.trim()) ||
                                    value.length > 254
                                ? 'Enter a valid email address.'
                                : null,
                          ),
                        if (needsPassword) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('auth-password'),
                            controller: password,
                            enabled: !auth.busy,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            autofillHints: [
                              newPassword
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password.';
                              }
                              if (newPassword && value.length < 8) {
                                return 'Use at least 8 characters.';
                              }
                              if (value.length > 256) {
                                return 'Use at most 256 characters.';
                              }
                              return null;
                            },
                          ),
                        ],
                        if (newPassword) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('auth-confirm'),
                            controller: confirm,
                            enabled: !auth.busy,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                            validator: (value) => value != password.text
                                ? 'Passwords must match.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (!auth.configured)
                          const Text(
                            'Account access is not configured. Demo mode is available.',
                          ),
                        if (auth.error != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              auth.error!,
                              key: const ValueKey('auth-error'),
                            ),
                          ),
                        if (auth.message != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              auth.message!,
                              key: const ValueKey('auth-message'),
                            ),
                          ),
                        if (auth.busy)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: LinearProgressIndicator(),
                          ),
                        FilledButton(
                          key: const ValueKey('auth-submit'),
                          onPressed: auth.busy || !auth.configured
                              ? null
                              : submit,
                          child: Text(
                            recovery
                                ? 'Save new password'
                                : switch (mode) {
                                    AuthFormMode.login => 'Login',
                                    AuthFormMode.register => 'Create account',
                                    AuthFormMode.forgot => 'Send reset email',
                                  },
                          ),
                        ),
                        if (!recovery) ...[
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => changeMode(
                                    mode == AuthFormMode.register
                                        ? AuthFormMode.login
                                        : AuthFormMode.register,
                                  ),
                            child: Text(
                              mode == AuthFormMode.register
                                  ? 'Back to login'
                                  : 'Create account',
                            ),
                          ),
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () => changeMode(
                                    mode == AuthFormMode.forgot
                                        ? AuthFormMode.login
                                        : AuthFormMode.forgot,
                                  ),
                            child: Text(
                              mode == AuthFormMode.forgot
                                  ? 'Back to login'
                                  : 'Forgot password?',
                            ),
                          ),
                          TextButton(
                            onPressed: auth.busy || !auth.configured
                                ? null
                                : () {
                                    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                            .hasMatch(email.text.trim()) &&
                                        email.text.trim().length <= 254) {
                                      auth.resendVerification(
                                        email.text.trim(),
                                      );
                                    } else {
                                      form.currentState!.validate();
                                    }
                                  },
                            child: const Text('Resend verification email'),
                          ),
                          const Divider(),
                          OutlinedButton(
                            key: const ValueKey('auth-demo'),
                            onPressed: auth.busy ? null : auth.enterDemo,
                            child: const Text('Explore synthetic demo'),
                          ),
                        ] else
                          TextButton(
                            onPressed: auth.busy ? null : auth.signOut,
                            child: const Text('Cancel and return to login'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
