import 'dart:async';
import 'dart:convert';

import 'package:auracare_mobile_app/data/auth_service.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/remote_records.dart';
import 'package:auracare_mobile_app/app/auth_root.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_test.dart' show FakeAuth, now;
import 'local_records_correctness_test.dart' show problem;
import 'widget_test.dart' show show, tapText;

HealthEntry fixture({
  String id = 'draft-00000000-0000-4000-8000-000000000001',
  EntryType type = EntryType.journal,
  String title = 'Synthetic record',
  int version = 1,
  bool utc = true,
}) => HealthEntry(
  id: id,
  type: type,
  title: title,
  note: 'Fictional note',
  version: version,
  when: utc
      ? DateTime.utc(2026, 10, 20, 9, 15, 12, 345, 678)
      : DateTime(2026, 10, 20, 9, 15, 12, 345, 678),
  zone: 'Original zone label',
  severity: Severity.moderate,
  mood: RecordedMood.calm,
  periodStart: false,
  periodEnd: true,
  tracking: const TrackingDetails(
    amount: TrackingAmount.light,
    color: 'pink',
    consistency: 'thin',
    odorChange: ObservationAnswer.unsure,
    irritation: ObservationAnswer.no,
  ),
);

Map<String, dynamic> row(HealthEntry entry, {String? id}) => {
  ...HealthRowCodec.encode(entry),
  'id': id ?? entry.id,
  'user_id': 'synthetic-user',
  'version': entry.version,
  'updated_at': '2026-10-25T12:00:00.123456Z',
};

class MemoryTransport implements HealthRecordsTransport {
  final tables = <String, List<Map<String, dynamic>>>{
    'journal_entries': [],
    'health_observations': [],
  };
  Completer<void>? pending;
  bool fail = false;
  int creates = 0;
  Future<void> wait() async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('synthetic raw token secret');
  }

  @override
  Future<List<Map<String, dynamic>>> read(String table) async {
    await wait();
    return tables[table]!.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> create(
    String table,
    String requestId,
    Map<String, Object?> values,
  ) async {
    await wait();
    creates++;
    final existing = tables[table]!
        .where((r) => r['client_request_id'] == requestId)
        .firstOrNull;
    if (existing != null) return existing;
    final result = <String, dynamic>{
      ...values,
      'id': '00000000-0000-4000-8000-${creates.toString().padLeft(12, '0')}',
      'client_request_id': requestId,
      'user_id': 'synthetic-user',
      'version': 1,
      'updated_at': '2026-10-25T12:00:00.123456Z',
    };
    tables[table]!.add(result);
    return result;
  }

  @override
  Future<Map<String, dynamic>> update(
    String table,
    String id,
    int version,
    Map<String, Object?> values,
  ) async {
    await wait();
    final index = tables[table]!.indexWhere(
      (r) => r['id'] == id && r['version'] == version,
    );
    if (index < 0) throw RecordFailure(RecordProblem.conflict);
    return tables[table]![index] = {
      ...tables[table]![index],
      ...values,
      'version': version + 1,
    };
  }

  @override
  Future<void> delete(String table, String id, int version) async {
    await wait();
    final before = tables[table]!.length;
    tables[table]!.removeWhere((r) => r['id'] == id && r['version'] == version);
    if (before == tables[table]!.length) {
      throw RecordFailure(RecordProblem.conflict);
    }
  }

  @override
  void close() {}
}

void main() {
  testWidgets(
    'legacy journal edit retains unknown time instead of inventing midnight',
    (tester) async {
      final transport = MemoryTransport();
      transport.tables['journal_entries']!.add(
        row(fixture(id: 'legacy-server-id'))
          ..['entry_time'] = null
          ..['entry_is_utc'] = null,
      );
      final repo = RemoteRecordsRepository(
        transport: transport,
        enabled: true,
        isCurrentSession: () => true,
      );
      await repo.load();
      final session = DemoSession(records: repo);
      await show(
        tester,
        EntryEditor(type: EntryType.journal, entry: repo.entries.single),
        session,
      );
      expect(find.text('Time: not recorded'), findsOneWidget);
      await tapText(tester, 'Save entry');
      expect(repo.entries.single.observationTimeKnown, isFalse);
      expect(transport.tables['journal_entries']!.single['entry_time'], isNull);
      expect(repo.entries.single.toJson()['wallClock'], '2026-10-20');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'remote editor delete conflict keeps the newer server record and draft',
    (tester) async {
      final transport = MemoryTransport();
      final repo = RemoteRecordsRepository(
        transport: transport,
        enabled: true,
        isCurrentSession: () => true,
      );
      await repo.load();
      await repo.save(fixture());
      final session = DemoSession(records: repo);
      await show(
        tester,
        EntryEditor(type: EntryType.journal, entry: repo.entries.single),
        session,
      );
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'Fictional pending edit',
      );
      transport.tables['journal_entries']!.single['version'] = 2;
      await tapText(tester, 'Delete entry');
      await tapText(tester, 'Delete');
      expect(find.textContaining('This entry changed'), findsOneWidget);
      expect(find.text('Fictional pending edit'), findsOneWidget);
      expect(transport.tables['journal_entries']!.single['version'], 2);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  test(
    'changed retry cannot silently accept an earlier create payload',
    () async {
      final transport = MemoryTransport();
      final repo = RemoteRecordsRepository(
        transport: transport,
        enabled: true,
        isCurrentSession: () => true,
      );
      addTearDown(repo.dispose);
      await repo.load();
      await repo.save(fixture());
      await expectLater(
        repo.save(fixture(title: 'Unsaved changed draft')),
        throwsA(problem(RecordProblem.conflict)),
      );
      expect(repo.entries.single.title, 'Synthetic record');
      expect(transport.creates, 1);
    },
  );

  for (final deleting in [false, true]) {
    test(
      'server-side ${deleting ? 'delete' : 'update'} conflict preserves cache',
      () async {
        final transport = MemoryTransport();
        final repo = RemoteRecordsRepository(
          transport: transport,
          enabled: true,
          isCurrentSession: () => true,
        );
        addTearDown(repo.dispose);
        await repo.load();
        await repo.save(fixture());
        final id = repo.entries.single.id;
        transport.tables['journal_entries']!.single['version'] = 2;
        await expectLater(
          deleting
              ? repo.delete(id, expectedVersion: 1)
              : repo.save(fixture(id: id, version: 2)),
          throwsA(problem(RecordProblem.conflict)),
        );
        expect(repo.entries.single.version, 1);
        await repo.load();
        expect(repo.entries.single.version, 2);
      },
    );
  }

  test('token rejection expires only the matching current session', () async {
    final gateway = FakeAuth();
    final auth = AuraAuthController(gateway: gateway, clock: () => now);
    await auth.signIn('synthetic@example.com', 'password');
    auth.rejectAccessToken('old-synthetic-token');
    expect(auth.mode, AccessMode.authenticated);
    auth.rejectAccessToken('synthetic-token');
    expect(auth.mode, AccessMode.signedOut);
    expect(await auth.accessToken(), isNull);
    auth.dispose();
    await gateway.events.close();
  });

  test('PostgREST pages records and rejects foreign-owner responses', () async {
    final gateway = FakeAuth();
    final auth = AuraAuthController(gateway: gateway, clock: () => now);
    await auth.signIn('synthetic@example.com', 'password');
    var calls = 0;
    var foreign = false;
    final transport = SupabaseHealthTransport(
      config: SupabaseConfiguration(
        url: 'https://synthetic.invalid',
        anonKey: 'sb_publishable_synthetic_key_only',
      ),
      auth: auth,
      owner: 'synthetic-user',
      client: MockClient((request) async {
        calls++;
        if (foreign) {
          return http.Response(
            jsonEncode([
              {...row(fixture()), 'user_id': 'another-synthetic-user'},
            ]),
            200,
          );
        }
        if (request.url.queryParameters['offset'] == '0') {
          return http.Response(
            jsonEncode(
              List.generate(500, (i) => row(fixture(id: 'synthetic-$i'))),
            ),
            200,
          );
        }
        expect(request.url.queryParameters['offset'], '500');
        return http.Response('[]', 200);
      }),
    );
    expect(await transport.read('journal_entries'), hasLength(500));
    expect(calls, 2);
    foreign = true;
    await expectLater(
      transport.read('journal_entries'),
      throwsA(problem(RecordProblem.authentication)),
    );
    transport.close();
    auth.dispose();
    await gateway.events.close();
  });

  testWidgets('deployment-gated authenticated UI never imports demo records', (
    tester,
  ) async {
    final gateway = FakeAuth();
    final auth = AuraAuthController(gateway: gateway, clock: () => now);
    await tester.pumpWidget(AuthenticationRoot(auth: auth));
    auth.enterDemo();
    await tester.pumpAndSettle();
    final demo = tester
        .widget<SessionScope>(find.byType(SessionScope))
        .notifier!;
    demo.records.reset(sample: true);
    expect(demo.records.entries, isNotEmpty);
    auth.leaveDemo();
    await tester.pumpAndSettle();
    await auth.signIn('synthetic@example.com', 'password');
    await tester.pumpAndSettle();
    final account = tester
        .widget<SessionScope>(find.byType(SessionScope))
        .notifier!;
    expect(account.records.isRemote, isTrue);
    expect(account.records.entries, isEmpty);
    expect(find.textContaining('Database deployment'), findsOneWidget);
    expect(find.text('Retry records'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
    await gateway.events.close();
  });

  for (final type in EntryType.values) {
    for (final utc in [true, false]) {
      test('${type.name} lossless codec, UTC=$utc', () {
        final original = fixture(type: type, utc: utc);
        final decoded = HealthRowCodec.decode(
          HealthRowCodec.table(type),
          row(original),
        );
        expect(decoded.toJson(), {
          ...original.toJson(),
          'savedAt': '2026-10-25T12:00:00.123456Z',
        });
        expect(decoded.when.isUtc, utc);
        expect(
          HealthRowCodec.encode(original).keys,
          isNot(contains(anyOf('user_id', 'version', 'updated_at', 'id'))),
        );
      });
    }
  }
  for (final title in ['Mood', 'Energy', 'Stress', 'Sleep']) {
    test('wellbeing $title retains exact subtype and notes', () {
      final entry = fixture(type: EntryType.wellness, title: title);
      expect(
        HealthRowCodec.decode('health_observations', row(entry)).title,
        title,
      );
    });
  }
  test('legacy date-only journal keeps unknown time on re-save', () {
    final data = row(fixture())
      ..['entry_time'] = null
      ..['entry_is_utc'] = null;
    final decoded = HealthRowCodec.decode('journal_entries', data);
    expect(decoded.observationTimeKnown, isFalse);
    expect(HealthRowCodec.encode(decoded)['entry_time'], isNull);
    expect(HealthRowCodec.encode(decoded)['entry_is_utc'], isNull);
  });

  test(
    'deployment gate performs no reads or writes and never falls back',
    () async {
      final transport = MemoryTransport();
      final repo = RemoteRecordsRepository(
        transport: transport,
        enabled: false,
        isCurrentSession: () => true,
      );
      addTearDown(repo.dispose);
      await repo.load();
      expect(repo.loadError, contains('deployment'));
      expect(repo.loaded, isFalse);
      await expectLater(
        repo.save(fixture()),
        throwsA(problem(RecordProblem.deployment)),
      );
      repo.reset(sample: true);
      expect(repo.entries, isEmpty);
      expect(transport.creates, 0);
    },
  );

  for (final type in EntryType.values) {
    test('${type.name} remote CRUD survives repository restart', () async {
      final transport = MemoryTransport();
      final repo = RemoteRecordsRepository(
        transport: transport,
        enabled: true,
        isCurrentSession: () => true,
      );
      await repo.load();
      final draft = fixture(type: type);
      await repo.save(draft);
      await repo.save(draft);
      expect(transport.creates, 1);
      final id = repo.entries.single.id;
      expect(id, isNot(draft.id));
      await repo.save(fixture(id: id, type: type, title: 'Edited', version: 2));
      await expectLater(
        repo.delete(id, expectedVersion: 1),
        throwsA(problem(RecordProblem.conflict)),
      );
      repo.dispose();
      final restarted = RemoteRecordsRepository(
        transport: transport,
        enabled: true,
        isCurrentSession: () => true,
      );
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.entries.single.title, 'Edited');
      expect(restarted.entries.single.version, 2);
      await restarted.delete(id, expectedVersion: 2);
      await expectLater(
        restarted.save(fixture(id: id, type: type, version: 3)),
        throwsA(problem(RecordProblem.notFound)),
      );
      expect(restarted.entries, isEmpty);
    });
  }

  for (final operation in ['load', 'save', 'update', 'delete']) {
    for (final dispose in [true, false]) {
      test(
        'pending $operation cannot publish after ${dispose ? 'disposal' : 'account change'}',
        () async {
          final transport = MemoryTransport();
          var current = true;
          final repo = RemoteRecordsRepository(
            transport: transport,
            enabled: true,
            isCurrentSession: () => current,
          );
          await repo.load();
          if (operation == 'update' || operation == 'delete') {
            await repo.save(fixture());
          }
          transport.pending = Completer<void>();
          var notifications = 0;
          repo.addListener(() => notifications++);
          final pending = switch (operation) {
            'load' => repo.load(),
            'delete' => repo.delete(repo.entries.single.id, expectedVersion: 1),
            'update' => repo.save(
              fixture(id: repo.entries.single.id, version: 2),
            ),
            _ => repo.save(fixture()),
          };
          final checked = operation == 'load'
              ? pending
              : expectLater(
                  pending,
                  throwsA(
                    problem(
                      dispose ? RecordProblem.closed : RecordProblem.cancelled,
                    ),
                  ),
                );
          if (dispose) {
            repo.dispose();
          } else {
            current = false;
            repo.reset();
          }
          final before = notifications;
          transport.pending!.complete();
          await checked;
          expect(repo.entries, isEmpty);
          expect(notifications, before);
          if (!dispose) repo.dispose();
        },
      );
    }
  }

  test('failed refresh keeps confirmed cache and retry replaces it', () async {
    final transport = MemoryTransport();
    final repo = RemoteRecordsRepository(
      transport: transport,
      enabled: true,
      isCurrentSession: () => true,
    );
    addTearDown(repo.dispose);
    await repo.load();
    await repo.save(fixture());
    transport.fail = true;
    await repo.load();
    expect(repo.entries, hasLength(1));
    expect(repo.loadError, isNot(contains('secret')));
    transport.fail = false;
    await repo.load();
    expect(repo.loadError, isNull);
  });

  test('concurrent save is rejected, not duplicated', () async {
    final transport = MemoryTransport();
    final repo = RemoteRecordsRepository(
      transport: transport,
      enabled: true,
      isCurrentSession: () => true,
    );
    addTearDown(repo.dispose);
    await repo.load();
    transport.pending = Completer<void>();
    final pending = repo.save(fixture());
    await expectLater(
      repo.save(fixture()),
      throwsA(problem(RecordProblem.busy)),
    );
    transport.pending!.complete();
    await pending;
    expect(transport.creates, 1);
  });

  test('PostgREST authenticates, omits server metadata, filters CAS and recovers ambiguous create', () async {
    final gateway = FakeAuth();
    final auth = AuraAuthController(gateway: gateway, clock: () => now);
    await auth.signIn('synthetic@example.com', 'password');
    final requests = <http.Request>[];
    var createCalls = 0;
    final stored = row(fixture(id: 'server-id'));
    final transport = SupabaseHealthTransport(
      config: SupabaseConfiguration(
        url: 'https://synthetic.invalid',
        anonKey: 'sb_publishable_synthetic_key_only',
      ),
      auth: auth,
      owner: 'synthetic-user',
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        expect(request.url.queryParameters['user_id'], 'eq.synthetic-user');
        if (request.method == 'POST') {
          createCalls++;
          expect(jsonDecode(request.body), isNot(contains('id')));
          if (createCalls == 1) {
            throw http.ClientException('synthetic token secret');
          }
          return http.Response('[]', 201);
        }
        return http.Response(jsonEncode([stored]), 200);
      }),
    );
    addTearDown(() async {
      transport.close();
      auth.dispose();
      await gateway.events.close();
    });
    await expectLater(
      transport.create(
        'journal_entries',
        'request-id',
        HealthRowCodec.encode(fixture()),
      ),
      throwsA(problem(RecordProblem.unavailable)),
    );
    expect(
      (await transport.create(
        'journal_entries',
        'request-id',
        HealthRowCodec.encode(fixture()),
      ))['id'],
      'server-id',
    );
    expect(
      requests
          .where((r) => r.method == 'POST')
          .map((r) => jsonDecode(r.body)['client_request_id'])
          .toSet(),
      {'request-id'},
    );
    await transport.update(
      'journal_entries',
      'server-id',
      7,
      HealthRowCodec.encode(fixture()),
    );
    await transport.delete('journal_entries', 'server-id', 8);
    expect(
      requests[requests.length - 2].url.queryParameters['version'],
      'eq.7',
    );
    expect(requests.last.url.queryParameters['version'], 'eq.8');
    await auth.signOut();
    final count = requests.length;
    await expectLater(
      transport.read('journal_entries'),
      throwsA(problem(RecordProblem.authentication)),
    );
    expect(requests.length, count);
  });

  test('enabled storage with no configuration differs from the closed deployment gate', () async {
    final enabled = RemoteRecordsRepository(
      transport: null,
      enabled: true,
      isCurrentSession: () => true,
    );
    final gated = RemoteRecordsRepository(
      transport: null,
      enabled: false,
      isCurrentSession: () => true,
    );
    addTearDown(enabled.dispose);
    addTearDown(gated.dispose);
    await enabled.load();
    await gated.load();
    expect(enabled.loaded, isFalse);
    expect(enabled.loadError, contains('configuration'));
    expect(gated.loadError, contains('Database deployment'));
    await expectLater(
      enabled.save(fixture()),
      throwsA(problem(RecordProblem.configuration)),
    );
    await expectLater(
      gated.save(fixture()),
      throwsA(problem(RecordProblem.deployment)),
    );
  });

  test('missing schema and permission failures do not masquerade as a disabled flag', () async {
    final gateway = FakeAuth();
    final auth = AuraAuthController(gateway: gateway, clock: () => now);
    addTearDown(auth.dispose);
    addTearDown(gateway.events.close);
    await auth.signIn('synthetic@example.com', 'synthetic-password');
    for (final failure in [
      (404, '{}', RecordProblem.schema),
      (
        400,
        '{"code":"PGRST204","message":"private schema detail"}',
        RecordProblem.schema,
      ),
      (
        400,
        '{"code":"42703","message":"private schema detail"}',
        RecordProblem.schema,
      ),
      (
        403,
        '{"message":"private permission detail"}',
        RecordProblem.permission,
      ),
    ]) {
      final transport = SupabaseHealthTransport(
        config: SupabaseConfiguration(
          url: 'https://synthetic.invalid',
          anonKey: 'sb_publishable_synthetic_key_only',
        ),
        auth: auth,
        owner: 'synthetic-user',
        client: MockClient((_) async => http.Response(failure.$2, failure.$1)),
      );
      try {
        await expectLater(
          transport.read('journal_entries'),
          throwsA(problem(failure.$3)),
        );
        expect(auth.mode, AccessMode.authenticated);
      } finally {
        transport.close();
      }
    }
  });

  for (final status in [401, 403, 404, 409, 500]) {
    test('PostgREST $status is mapped to a safe failure', () async {
      final gateway = FakeAuth();
      final auth = AuraAuthController(gateway: gateway, clock: () => now);
      await auth.signIn('synthetic@example.com', 'password');
      final transport = SupabaseHealthTransport(
        config: SupabaseConfiguration(
          url: 'https://synthetic.invalid',
          anonKey: 'sb_publishable_synthetic_key_only',
        ),
        auth: auth,
        owner: 'synthetic-user',
        client: MockClient(
          (_) async => http.Response('raw secret SDK details', status),
        ),
      );
      await expectLater(
        transport.read('journal_entries'),
        throwsA(
          isA<RecordFailure>().having(
            (e) => e.safeMessage,
            'safe',
            isNot(contains('secret')),
          ),
        ),
      );
      transport.close();
      auth.dispose();
      await gateway.events.close();
    });
  }

  testWidgets(
    'remote editor retains draft on failure and retries to server UUID',
    (tester) async {
      final transport = MemoryTransport();
      final repo = RemoteRecordsRepository(
        transport: transport,
        enabled: true,
        isCurrentSession: () => true,
      );
      await repo.load();
      final session = DemoSession(records: repo);
      await show(tester, const EntryEditor(type: EntryType.journal), session);
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'Fictional cloud draft',
      );
      transport.fail = true;
      await tapText(tester, 'Save entry');
      expect(find.text('Fictional cloud draft'), findsOneWidget);
      expect(find.textContaining('raw token'), findsNothing);
      transport.fail = false;
      await tapText(tester, 'Retry save');
      expect(repo.entries.single.note, 'Fictional cloud draft');
      expect(find.byType(EntryEditor), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'authenticated root loads shared remote records and clears logout cache',
    (tester) async {
      final gateway = FakeAuth();
      final auth = AuraAuthController(gateway: gateway, clock: () => now);
      await auth.signIn('synthetic@example.com', 'password');
      final transport = MemoryTransport();
      transport.tables['journal_entries']!.add(
        row(fixture(id: 'remote-fixture')),
      );
      await tester.pumpWidget(
        AuthenticationRoot(
          auth: auth,
          recordsFactory: (auth) => RemoteRecordsRepository(
            transport: transport,
            enabled: true,
            isCurrentSession: () => auth.mode == AccessMode.authenticated,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final session = tester
          .widget<SessionScope>(find.byType(SessionScope))
          .notifier!;
      expect(session.records.entries.single.id, 'remote-fixture');
      expect(find.textContaining('1 records in this session'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Synthetic record'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Synthetic record'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('auth-exit')));
      await tester.pumpAndSettle();
      expect(session.records.entries, isEmpty);
      expect(find.text('Synthetic record'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
      await gateway.events.close();
    },
  );
}
