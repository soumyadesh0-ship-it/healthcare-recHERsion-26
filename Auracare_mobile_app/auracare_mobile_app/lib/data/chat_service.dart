import 'api_client.dart';
import 'auth_service.dart';

class AuthenticatedChatService {
  AuthenticatedChatService({
    required this.auth,
    required this.createClient,
  }) : _userId = auth.userId;

  final AuraAuthController auth;
  final String? _userId;
  final AuraApiClient Function() createClient;
  AuraApiClient? _client;
  bool _busy = false, _disposed = false;

  Future<String> send({
    required String prompt,
    required bool aiProcessingConfirmed,
  }) async {
    if (!aiProcessingConfirmed) {
      throw const ApiException(ApiFailure.forbidden);
    }
    if (_busy) throw const ApiException(ApiFailure.forbidden);
    if (_disposed ||
        auth.mode != AccessMode.authenticated ||
        auth.userId != _userId ||
        _userId == null) {
      throw const ApiException(ApiFailure.unauthenticated);
    }

    _busy = true;
    try {
      final response = await (_client ??= createClient()).chat(
        prompt: prompt,
        aiProcessingConfirmed: aiProcessingConfirmed,
      );
      if (_disposed ||
          auth.mode != AccessMode.authenticated ||
          auth.userId != _userId) {
        throw const ApiException(ApiFailure.unauthenticated);
      }
      return response;
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _client?.close();
  }
}
