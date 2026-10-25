import 'package:flutter/material.dart';

import '../../app/auth_service.dart';
import '../../app/theme.dart';
import '../../core/brand.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.auth,
    required this.onAuthenticated,
    required this.onDemoSelected,
    this.initialMessage,
  });

  final AuthService auth;
  final ValueChanged<AuthUser> onAuthenticated;
  final ValueChanged<bool> onDemoSelected;
  final String? initialMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscurePassword = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    error = widget.initialMessage;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (busy || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final user = await widget.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      widget.onAuthenticated(user);
    } on AuthException catch (exception) {
      if (mounted) {
        setState(() => error = authFailureMessage(exception.failure));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> google() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final user = await widget.auth.signInWithGoogle();
      if (mounted && user != null) widget.onAuthenticated(user);
    } on AuthException catch (exception) {
      if (mounted) {
        setState(() => error = authFailureMessage(exception.failure));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseDemo() async {
    final sample = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Continue in demo mode'),
        content: const Text(
          'Demo mode uses fictional, session-only records. It does not create an account or sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Start empty'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use sample records'),
          ),
        ],
      ),
    );
    if (sample != null && mounted) widget.onDemoSelected(sample);
  }

  void open(Widget page) =>
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => _AuthPageFrame(
    logoWidth: 220,
    children: [
      Text(
        'Welcome to AuraCare',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 6),
      const Text(
        'Your body. Your space.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Palette.secondary),
      ),
      const SizedBox(height: 28),
      Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('login-email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _authInputDecoration('Email address'),
              validator: _emailError,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('login-password'),
              controller: password,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => login(),
              decoration: _authInputDecoration('Password').copyWith(
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: busy
              ? null
              : () => open(ResetPasswordPage(auth: widget.auth)),
          child: const Text('Forgot password?'),
        ),
      ),
      if (error != null) _AuthMessage(error!, isError: true),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : login,
          child: busy ? const _ButtonProgress() : const Text('Log in'),
        ),
      ),
      const SizedBox(height: 22),
      const _AuthDivider(),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy || !widget.auth.supportsGoogleSignIn ? null : google,
          child: Text(
            widget.auth.supportsGoogleSignIn
                ? 'Continue with Google'
                : 'Continue with Google · unavailable',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      if (!widget.auth.isConfigured) ...[
        const SizedBox(height: 12),
        const _AuthMessage(
          'Account sign-in is not configured in this build. Connect the shared authentication provider to enable login, Google sign-in, registration, and password recovery.',
        ),
      ],
      if (widget.auth.isConfigured && !widget.auth.supportsGoogleSignIn) ...[
        const SizedBox(height: 12),
        const _AuthMessage(
          'Google sign-in is not configured for this Supabase project.',
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text("Don't have an account? "),
          TextButton(
            onPressed: busy
                ? null
                : () => open(
                    CreateAccountPage(
                      auth: widget.auth,
                      onAuthenticated: widget.onAuthenticated,
                    ),
                  ),
            child: const Text('Create account'),
          ),
        ],
      ),
      TextButton(
        onPressed: busy ? null : chooseDemo,
        child: const Text('Continue in demo mode'),
      ),
    ],
  );
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({
    super.key,
    required this.auth,
    required this.onAuthenticated,
  });

  final AuthService auth;
  final ValueChanged<AuthUser> onAuthenticated;

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  bool busy = false;
  String? message;
  bool messageIsError = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    if (busy || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await widget.auth.createAccount(
        fullName: name.text.trim(),
        email: email.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      if (!result.accountCreated) {
        setState(() {
          message = authFailureMessage(AuthFailure.rejected);
          messageIsError = true;
        });
      } else if (result.emailVerificationRequired) {
        setState(() {
          message = 'If registration was accepted, follow the verification instructions sent to your email, then return to log in.';
          messageIsError = false;
        });
      } else if (result.user != null) {
        widget.onAuthenticated(result.user!);
      } else {
        setState(() {
          message = authFailureMessage(AuthFailure.rejected);
          messageIsError = true;
        });
      }
    } on AuthException catch (exception) {
      if (mounted) {
        setState(() {
          message = authFailureMessage(exception.failure);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPageFrame(
    logoWidth: 170,
    children: [
      Text(
        'Create your account',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 24),
      Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              key: const ValueKey('create-name'),
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: _authInputDecoration('Full name'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Enter your name.';
                if (trimmed.length > 100) {
                  return 'Use 100 characters or fewer.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('create-email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _authInputDecoration('Email address'),
              validator: _emailError,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('create-password'),
              controller: password,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _authInputDecoration('Password').copyWith(
                helperText: 'Use at least 8 characters.',
                suffixIcon: _visibilityButton(
                  obscurePassword,
                  () => setState(() => obscurePassword = !obscurePassword),
                ),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('create-confirm-password'),
              controller: confirmation,
              obscureText: obscureConfirmation,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => createAccount(),
              decoration: _authInputDecoration('Confirm password').copyWith(
                suffixIcon: _visibilityButton(
                  obscureConfirmation,
                  () => setState(
                    () => obscureConfirmation = !obscureConfirmation,
                  ),
                ),
              ),
              validator: (value) =>
                  value != password.text ? 'Passwords do not match.' : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (message != null) _AuthMessage(message!, isError: messageIsError),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : createAccount,
          child: busy ? const _ButtonProgress() : const Text('Create account'),
        ),
      ),
      if (!widget.auth.isConfigured) ...[
        const SizedBox(height: 12),
        const _AuthMessage(
          'Registration is unavailable until the shared authentication provider is connected.',
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Already have an account? '),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Log in'),
          ),
        ],
      ),
    ],
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  bool busy = false;
  String? message;
  bool messageIsError = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> sendResetLink() async {
    if (busy || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.auth.sendPasswordReset(email.text.trim());
      if (mounted) {
        setState(() {
          message = 'If an account matches that address, password reset instructions will be sent.';
          messageIsError = false;
        });
      }
    } on AuthException catch (exception) {
      if (mounted) {
        setState(() {
          message = authFailureMessage(exception.failure);
          messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPageFrame(
    logoWidth: 150,
    children: [
      Text(
        'Reset your password',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      const Text(
        'Enter the email address associated with your account. If it matches an account, we’ll send reset instructions.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Palette.secondary),
      ),
      const SizedBox(height: 24),
      Form(
        key: formKey,
        child: TextFormField(
          key: const ValueKey('reset-email'),
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onFieldSubmitted: (_) => sendResetLink(),
          decoration: _authInputDecoration('Email address'),
          validator: _emailError,
        ),
      ),
      const SizedBox(height: 18),
      if (message != null) _AuthMessage(message!, isError: messageIsError),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : sendResetLink,
          child: busy ? const _ButtonProgress() : const Text('Send reset link'),
        ),
      ),
      if (!widget.auth.isConfigured) ...[
        const SizedBox(height: 12),
        const _AuthMessage(
          'Password recovery is unavailable until the shared authentication provider is configured.',
        ),
      ],
      const SizedBox(height: 12),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Back to login'),
      ),
    ],
  );
}

class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({
    super.key,
    required this.auth,
    required this.onPasswordUpdated,
  });

  final AuthService auth;
  final ValueChanged<AuthUser> onPasswordUpdated;

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirmation = true;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    if (busy || !formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final user = await widget.auth.updatePassword(password.text);
      if (mounted) widget.onPasswordUpdated(user);
    } on AuthException catch (exception) {
      if (mounted) {
        setState(() => error = authFailureMessage(exception.failure));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPageFrame(
    logoWidth: 150,
    children: [
      Text(
        'Choose a new password',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 10),
      const Text(
        'Your reset link is verified. Choose a new password for your account.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Palette.secondary),
      ),
      const SizedBox(height: 24),
      Form(
        key: formKey,
        child: Column(
          children: [
            TextFormField(
              key: const ValueKey('recovery-password'),
              controller: password,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: _authInputDecoration('New password').copyWith(
                helperText: 'Use at least 8 characters.',
                suffixIcon: _visibilityButton(
                  obscurePassword,
                  () => setState(() => obscurePassword = !obscurePassword),
                ),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('recovery-confirm-password'),
              controller: confirmation,
              obscureText: obscureConfirmation,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => updatePassword(),
              decoration: _authInputDecoration('Confirm new password').copyWith(
                suffixIcon: _visibilityButton(
                  obscureConfirmation,
                  () => setState(
                    () => obscureConfirmation = !obscureConfirmation,
                  ),
                ),
              ),
              validator: (value) =>
                  value != password.text ? 'Passwords do not match.' : null,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (error != null) _AuthMessage(error!, isError: true),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: busy ? null : updatePassword,
          child: busy ? const _ButtonProgress() : const Text('Update password'),
        ),
      ),
    ],
  );
}

class _AuthPageFrame extends StatelessWidget {
  const _AuthPageFrame({required this.logoWidth, required this.children});

  final double logoWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Palette.white,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: AuraLogo(width: logoWidth)),
                      const SizedBox(height: 22),
                      ...children,
                    ],
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

InputDecoration _authInputDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: Palette.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE5DEE9)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xFFE5DEE9)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Palette.purple, width: 1.5),
  ),
  errorMaxLines: 2,
);

String? _emailError(String? value) {
  final address = value?.trim() ?? '';
  if (address.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
    return 'Enter a valid email address.';
  }
  return null;
}

IconButton _visibilityButton(bool obscure, VoidCallback onPressed) =>
    IconButton(
      tooltip: obscure ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final enlargedText = MediaQuery.textScalerOf(context).scale(13) > 18;
      if (enlargedText || constraints.maxWidth < 280) {
        return Column(
          children: [
            const Divider(color: Color(0xFFE5DEE9)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'or continue with',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(color: Color(0xFFE5DEE9)),
          ],
        );
      }
      return Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE5DEE9))),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE5DEE9))),
        ],
      );
    },
  );
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError
              ? Theme.of(context).colorScheme.error
              : Palette.secondary,
        ),
      ),
    ),
  );
}
