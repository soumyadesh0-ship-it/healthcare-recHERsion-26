import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Supplies a current Supabase user access token. No SDK/session flow is implied.
/// Implementations must never return a service-role key or log credentials.
abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
}

enum ApiFailure {
  configuration,
  unauthenticated,
  forbidden,
  validation,
  rateLimited,
  unavailable,
  network,
  timeout,
  invalidResponse,
  rejected,
  closed,
}

/// Contains only local, fixed messages and safe status metadata, never a body,
/// request, token, URL, or upstream exception.
class ApiException implements Exception {
  const ApiException(this.failure, {this.statusCode, this.retryAfter});

  final ApiFailure failure;
  final int? statusCode;
  final Duration? retryAfter;

  String get message => switch (failure) {
    ApiFailure.configuration => 'Configure a valid backend URL.',
    ApiFailure.unauthenticated => 'A current user session is required.',
    ApiFailure.forbidden => 'This request is not permitted.',
    ApiFailure.validation => 'Check the supplied fields and confirmation.',
    ApiFailure.rateLimited => 'Too many requests. Try again later.',
    ApiFailure.unavailable => 'The service is temporarily unavailable.',
    ApiFailure.network => 'The backend could not be reached.',
    ApiFailure.timeout => 'The request timed out. Its outcome may be unknown.',
    ApiFailure.invalidResponse =>
      'The backend returned an unexpected response.',
    ApiFailure.rejected => 'The backend rejected the request.',
    ApiFailure.closed => 'The API client has been closed.',
  };

  @override
  String toString() => 'ApiException(${failure.name}, status: $statusCode)';
}

class ApiConfig {
  ApiConfig({required String baseUrl, bool allowDevelopmentHttp = false})
    : baseUri = _validate(baseUrl, allowDevelopmentHttp);

  factory ApiConfig.fromEnvironment() => ApiConfig(
    baseUrl: const String.fromEnvironment('AURACARE_API_BASE_URL'),
    allowDevelopmentHttp: kDebugMode,
  );

  final Uri baseUri;

  static Uri _validate(String value, bool allowHttp) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        RegExp(
          r'(^|/)(\.|%2e){1,2}(/|$)',
          caseSensitive: false,
        ).hasMatch(value.trim()) ||
        uri.pathSegments.any((s) => s == '.' || s == '..') ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                kDebugMode &&
                allowHttp &&
                _localHost(uri.host)))) {
      throw const ApiException(ApiFailure.configuration);
    }
    return uri.replace(path: '${uri.path.replaceAll(RegExp(r'/+$'), '')}/');
  }

  static bool _localHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    return parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }
}

/// The FastAPI survey contract, intentionally separate from demo QuizAnswers.
class PcosSurveyAnswers {
  const PcosSurveyAnswers({
    this.irregularPeriods,
    this.acne,
    this.excessHairGrowth,
    this.scalpHairThinning,
  });

  final bool? irregularPeriods, acne, excessHairGrowth, scalpHairThinning;

  Map<String, bool?> toJson() => {
    'irregular_periods': irregularPeriods,
    'acne': acne,
    'excess_hair_growth': excessHairGrowth,
    'scalp_hair_thinning': scalpHairThinning,
  };
}

class PcosAssessment {
  const PcosAssessment._(this._json);
  final Map<String, dynamic> _json;

  String get assessmentId => _json['assessment_id'] as String;
  String get prediction => _json['prediction'] as String;

  /// A symptom count, never a clinical risk or probability.
  int get riskScore => _json['risk_score'] as int;
  int get answeredQuestions => _json['answered_questions'] as int;
  int get totalQuestions => _json['total_questions'] as int;
  List<String> get reportedSymptoms =>
      List<String>.unmodifiable(_json['reported_symptoms'] as List);
  String get methodVersion => _json['method_version'] as String;
  String get limitations => _json['limitations'] as String;

  static PcosAssessment _parse(Map<String, dynamic> json) {
    for (final key in [
      'assessment_id',
      'prediction',
      'method_version',
      'limitations',
    ]) {
      if (json[key] is! String || (json[key] as String).isEmpty) {
        throw const ApiException(ApiFailure.invalidResponse);
      }
    }
    for (final key in ['risk_score', 'answered_questions', 'total_questions']) {
      if (json[key] is! int) {
        throw const ApiException(ApiFailure.invalidResponse);
      }
    }
    if (json['reported_symptoms'] is! List ||
        (json['reported_symptoms'] as List).any((v) => v is! String) ||
        !['survey_summary', 'insufficient_data'].contains(json['prediction']) ||
        json['total_questions'] != 4 ||
        (json['answered_questions'] as int) < 1 ||
        (json['answered_questions'] as int) > 4 ||
        (json['risk_score'] as int) < 0 ||
        (json['risk_score'] as int) > (json['answered_questions'] as int)) {
      throw const ApiException(ApiFailure.invalidResponse);
    }
    return PcosAssessment._(Map.unmodifiable(json));
  }

  // Avoid the default representation ever including health-response fields.
  @override
  String toString() => 'PcosAssessment';
}

/// Opt-in infrastructure only. Nothing constructs this from app/session/screens.
/// No retries, logging, token caching, or persistence. Injected HTTP clients
/// remain owned by their caller; close() still aborts this client's requests.
class AuraApiClient {
  AuraApiClient({
    required this.config,
    required this.tokenProvider,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 45),
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null {
    if (requestTimeout <= Duration.zero) {
      throw const ApiException(ApiFailure.configuration);
    }
  }

  final ApiConfig config;
  final AccessTokenProvider tokenProvider;
  final Duration requestTimeout;
  final http.Client _http;
  final bool _ownsHttp;
  final Set<Completer<void>> _pending = {};
  bool _closed = false;

  Future<String> chat({
    required String prompt,
    required bool aiProcessingConfirmed,
  }) async {
    if (!aiProcessingConfirmed) {
      throw const ApiException(ApiFailure.forbidden);
    }
    if (prompt.trim().isEmpty || prompt.trim().length > 10000) {
      throw const ApiException(ApiFailure.validation);
    }
    final json = await _request(
      'chat',
      body: {'prompt': prompt.trim(), 'ai_processing_confirmed': true},
    );
    if (json['response'] is! String ||
        (json['response'] as String).trim().isEmpty) {
      throw const ApiException(ApiFailure.invalidResponse);
    }
    return json['response'] as String;
  }

  Future<PcosAssessment> predictPcos(PcosSurveyAnswers survey) async {
    final body = survey.toJson();
    if (body.values.every((v) => v == null)) {
      throw const ApiException(ApiFailure.validation);
    }
    return PcosAssessment._parse(await _request('predict-pcos', body: body));
  }

  /// Public contract probe only, NOT database/AI readiness or RLS verification.
  /// Never asks for a token, calls authenticated routes, or fetches user data.
  Future<bool> checkConnection() async {
    final json = await _request('openapi.json', authenticated: false);
    final paths = json['paths'];
    return paths is Map &&
        paths['/chat'] is Map &&
        (paths['/chat'] as Map)['post'] is Map &&
        paths['/predict-pcos'] is Map &&
        (paths['/predict-pcos'] as Map)['post'] is Map;
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    if (_closed) throw const ApiException(ApiFailure.closed);
    final abort = Completer<void>();
    _pending.add(abort);
    try {
      return await _perform(path, body, authenticated, abort).timeout(
        requestTimeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw const ApiException(ApiFailure.timeout);
        },
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(_closed ? ApiFailure.closed : ApiFailure.network);
    } finally {
      if (!abort.isCompleted) abort.complete();
      _pending.remove(abort);
    }
  }

  Future<Map<String, dynamic>> _perform(
    String path,
    Map<String, dynamic>? body,
    bool authenticated,
    Completer<void> abort,
  ) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (authenticated) {
      String? token;
      try {
        token = await tokenProvider.accessToken();
      } catch (_) {
        throw const ApiException(ApiFailure.unauthenticated);
      }
      if (token == null ||
          token.trim().isEmpty ||
          RegExp(r'\s').hasMatch(token)) {
        throw const ApiException(ApiFailure.unauthenticated);
      }
      headers['Authorization'] = 'Bearer $token';
    }
    // Token retrieval may finish after the deadline or after close().
    if (_closed) throw const ApiException(ApiFailure.closed);
    if (abort.isCompleted) throw const ApiException(ApiFailure.timeout);
    final request = http.AbortableRequest(
      body == null ? 'GET' : 'POST',
      config.baseUri.resolve(path),
      abortTrigger: abort.future,
    )..followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final streamed = await _http.send(request);
    final status = streamed.statusCode;
    final expected = path == 'predict-pcos' ? 201 : 200;
    if (status != expected) {
      final seconds = int.tryParse(streamed.headers['retry-after'] ?? '');
      throw ApiException(
        switch (status) {
          401 => ApiFailure.unauthenticated,
          403 => ApiFailure.forbidden,
          400 || 422 => ApiFailure.validation,
          429 => ApiFailure.rateLimited,
          >= 500 => ApiFailure.unavailable,
          _ => ApiFailure.rejected,
        },
        statusCode: status,
        retryAfter: seconds != null && seconds >= 0
            ? Duration(seconds: seconds)
            : null,
      );
    }
    try {
      final bytes = await streamed.stream.toBytes();
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) {
        throw const ApiException(ApiFailure.invalidResponse);
      }
      return json;
    } on FormatException {
      throw const ApiException(ApiFailure.invalidResponse);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final abort in _pending) {
      if (!abort.isCompleted) abort.complete();
    }
    if (_ownsHttp) _http.close();
  }
}
