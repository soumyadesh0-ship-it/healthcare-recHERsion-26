import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatException implements Exception {
  const ChatException(this.message);
  final String message;
}

class ChatService {
  ChatService({
    required this.client,
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
  });

  final http.Client client;
  final String baseUrl;

  bool get configured {
    final uri = Uri.tryParse(baseUrl.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  Future<String> send(String prompt) async {
    if (!configured) {
      throw const ChatException(
        'Chat is not configured. Set API_BASE_URL and rebuild the app.',
      );
    }
    try {
      final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      final result = await client
          .post(
            Uri.parse('$base/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt.trim()}),
          )
          .timeout(const Duration(seconds: 60));
      if (result.statusCode != 200) {
        // Do not display raw backend errors, which may contain provider details.
        final message = switch (result.statusCode) {
          429 => 'The assistant has reached its request limit. Please try again later.',
          503 => 'The assistant is temporarily unavailable. Please try again shortly.',
          504 => 'The AI provider took too long to reply. Please try again.',
          _ => 'The assistant is unavailable. Please try again. If this continues, check the backend and its Gemini API key.',
        };
        throw ChatException(message);
      }
      final data = jsonDecode(utf8.decode(result.bodyBytes));
      final response = data is Map<String, dynamic> ? data['response'] : null;
      if (response is! String || response.trim().isEmpty) {
        throw const ChatException(
          'The assistant returned an empty or invalid reply. Please try again.',
        );
      }
      return response.trim();
    } on ChatException {
      rethrow;
    } on TimeoutException {
      throw const ChatException(
        'The assistant took too long to reply. Please try again.',
      );
    } on FormatException {
      throw const ChatException(
        'The backend returned an invalid reply. Please try again.',
      );
    } catch (_) {
      throw const ChatException(
        'Could not reach the assistant. Check your connection and that the backend is running.',
      );
    }
  }
}
