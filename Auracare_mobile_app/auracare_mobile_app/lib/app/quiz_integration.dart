import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../data/model_quiz_service.dart';

ModelQuizService? configuredModelQuizService(
  AuthService auth,
  http.Client client,
) {
  const base = String.fromEnvironment('AURACARE_API_BASE_URL');
  if (base.trim().isEmpty || auth is! AccessTokenProvider) return null;
  try {
    return AuthenticatedModelQuizService(
      baseUrl: Uri.parse(base.trim()),
      tokens: auth as AccessTokenProvider,
      client: client,
      allowLocalHttp:
          kDebugMode && const bool.fromEnvironment('AURACARE_ALLOW_LOCAL_API'),
    );
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
}

/// Above the Navigator so pushed quiz routes share the authenticated capability.
class QuizIntegrationScope extends InheritedWidget {
  const QuizIntegrationScope({
    super.key,
    required this.signedIn,
    required this.service,
    this.userId,
    required super.child,
  });

  final bool signedIn;
  final ModelQuizService? service;
  final String? userId;

  static QuizIntegrationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuizIntegrationScope>();

  @override
  bool updateShouldNotify(QuizIntegrationScope oldWidget) =>
      signedIn != oldWidget.signedIn ||
      service != oldWidget.service ||
      userId != oldWidget.userId;
}
