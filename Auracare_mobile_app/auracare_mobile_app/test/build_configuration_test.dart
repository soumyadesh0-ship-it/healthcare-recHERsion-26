import 'package:auracare_mobile_app/app/controller_auth_service.dart';
import 'package:auracare_mobile_app/app/quiz_integration.dart';
import 'package:auracare_mobile_app/data/api_client.dart';
import 'package:auracare_mobile_app/data/auth_service.dart';
import 'package:auracare_mobile_app/data/remote_records.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'auth_test.dart' show FakeAuth;

void main() {
  test(
    'actual build defines configure one auth gateway or fail closed',
    () async {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_ANON_KEY');
      final gateway = FakeAuth();
      addTearDown(gateway.events.close);
      var calls = 0;
      final auth = await initializeAuthentication(
        gatewayInitializer: (config) async {
          calls++;
          // Boolean comparisons avoid printing any local configuration on failure.
          expect(config.url == url.trim(), isTrue);
          expect(config.anonKey == key.trim(), isTrue);
          return gateway;
        },
      );
      addTearDown(auth.dispose);
      if (url.isEmpty || key.isEmpty) {
        expect(auth.configured, isFalse);
        expect(auth.startupFailure?.problem, AuthProblem.configuration);
        expect(calls, 0);
      } else {
        expect(auth.configured, isTrue);
        expect(calls, 1);
        final client = MockClient(
          (_) async => throw StateError('No network in configuration test'),
        );
        addTearDown(client.close);
        final api = ApiConfig.fromEnvironment();
        final model = configuredModelQuizService(
          ControllerAuthService(auth),
          client,
        );
        expect(api.baseUri.hasAuthority, isTrue);
        expect(model, isNotNull);
      }
      expect(
        healthPersistenceEnabled,
        isFalse,
        reason: 'Repair validation must not enable the unverified schema.',
      );
    },
  );
}
