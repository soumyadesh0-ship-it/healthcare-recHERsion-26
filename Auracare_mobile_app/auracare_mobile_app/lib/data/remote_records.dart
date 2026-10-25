import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'records.dart';

/// Explicit deployment gate. Never substitutes a local repository on failure.
const healthPersistenceEnabled = bool.fromEnvironment(
  'HEALTH_PERSISTENCE_ENABLED',
);

String _requestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Lossless adapter for the proposed journal and raw-observation schemas.
class HealthRowCodec {
  static String table(EntryType type) =>
      type == EntryType.journal ? 'journal_entries' : 'health_observations';

  static Map<String, Object?> encode(HealthEntry e) {
    final journal = e.type == EntryType.journal;
    final wall = e.when.toIso8601String().split('T')[1].replaceAll('Z', '');
    return {
      if (!journal) 'kind': e.type.name,
      'title': e.title,
      journal ? 'body' : 'notes': e.note,
      journal ? 'entry_date' : 'observation_date': dayLabel(e.when),
      journal ? 'entry_time' : 'observation_time': e.observationTimeKnown
          ? wall
          : null,
      journal ? 'entry_is_utc' : 'observation_is_utc': e.observationTimeKnown
          ? e.when.isUtc
          : null,
      journal ? 'timezone' : 'timezone_label': e.zone,
      'severity': e.severity.name,
      'mood_category': e.mood?.name,
      'period_start': e.periodStart,
      'period_end': e.periodEnd,
      'tracking_amount': e.tracking?.amount.name,
      'tracking_color': e.tracking?.color,
      'tracking_consistency': e.tracking?.consistency,
      'tracking_odor_change': e.tracking?.odorChange?.name,
      'tracking_irritation': e.tracking?.irritation?.name,
    };
  }

  static HealthEntry decode(String table, Map<String, dynamic> row) {
    final journal = table == 'journal_entries';
    final date = row[journal ? 'entry_date' : 'observation_date'] as String;
    final time = row[journal ? 'entry_time' : 'observation_time'] as String?;
    final utc = row[journal ? 'entry_is_utc' : 'observation_is_utc'] as bool?;
    if ((time == null) != (utc == null) || (!journal && time == null)) {
      throw const FormatException('Invalid observation timestamp');
    }
    final when = DateTime.parse(
      '${date}T${time ?? '00:00:00'}${utc == true ? 'Z' : ''}',
    );
    T? optional<T extends Enum>(List<T> values, String key) =>
        row[key] == null ? null : values.byName(row[key] as String);
    final amount = optional(TrackingAmount.values, 'tracking_amount');
    return HealthEntry(
      id: row['id'] as String,
      type: journal
          ? EntryType.journal
          : EntryType.values.byName(row['kind'] as String),
      title: row['title'] as String? ?? 'Journal entry',
      note: row[journal ? 'body' : 'notes'] as String,
      when: when,
      observationTimeKnown: time != null,
      zone: row[journal ? 'timezone' : 'timezone_label'] as String,
      version: (row['version'] as num).toInt(),
      savedAt: DateTime.parse(row['updated_at'] as String),
      severity: optional(Severity.values, 'severity') ?? Severity.unspecified,
      mood: optional(RecordedMood.values, 'mood_category'),
      periodStart: row['period_start'] as bool?,
      periodEnd: row['period_end'] as bool?,
      tracking: amount == null
          ? null
          : TrackingDetails(
              amount: amount,
              color: row['tracking_color'] as String?,
              consistency: row['tracking_consistency'] as String?,
              odorChange: optional(
                ObservationAnswer.values,
                'tracking_odor_change',
              ),
              irritation: optional(
                ObservationAnswer.values,
                'tracking_irritation',
              ),
            ),
    );
  }
}

abstract interface class HealthRecordsTransport {
  Future<List<Map<String, dynamic>>> read(String table);
  Future<Map<String, dynamic>> create(
    String table,
    String requestId,
    Map<String, Object?> values,
  );
  Future<Map<String, dynamic>> update(
    String table,
    String id,
    int version,
    Map<String, Object?> values,
  );
  Future<void> delete(String table, String id, int version);
  void close();
}

/// PostgREST requests use only the existing controller's current user token.
/// No privileged key, automatic retry, SDK exception text, or demo import.
class SupabaseHealthTransport implements HealthRecordsTransport {
  SupabaseHealthTransport({
    required this.config,
    required this.auth,
    required this.owner,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final SupabaseConfiguration config;
  final AuraAuthController auth;
  final String owner;
  final http.Client _client;
  bool _closed = false;

  Future<List<Map<String, dynamic>>> _request(
    String method,
    String table,
    Map<String, String> query, {
    Map<String, Object?>? values,
    String? prefer,
  }) async {
    try {
      if (_closed) throw RecordFailure(RecordProblem.closed);
      final token = await auth.accessToken();
      if (_closed) throw RecordFailure(RecordProblem.closed);
      if (token == null ||
          auth.userId != owner ||
          auth.mode != AccessMode.authenticated) {
        throw RecordFailure(RecordProblem.authentication);
      }
      final uri = Uri.parse(
        '${config.url.replaceAll(RegExp(r'/$'), '')}/rest/v1/$table',
      ).replace(queryParameters: {'user_id': 'eq.$owner', ...query});
      final request = http.Request(method, uri)
        ..headers.addAll({
          'apikey': config.anonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Prefer': ?prefer,
        });
      if (values != null) request.body = jsonEncode(values);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (_closed) throw RecordFailure(RecordProblem.closed);
      if (auth.userId != owner || auth.mode != AccessMode.authenticated) {
        throw RecordFailure(RecordProblem.cancelled);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (response.statusCode == 401) auth.rejectAccessToken(token);
        throw RecordFailure(RecordProblem.authentication);
      }
      if (response.statusCode == 404) {
        throw RecordFailure(RecordProblem.deployment);
      }
      if (response.statusCode == 409) {
        throw RecordFailure(RecordProblem.conflict);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RecordFailure(RecordProblem.unavailable);
      }
      if (response.body.isEmpty) return [];
      final rows = (jsonDecode(response.body) as List)
          .cast<Map<String, dynamic>>();
      if (rows.any((row) => row['user_id'] != owner)) {
        throw RecordFailure(RecordProblem.authentication);
      }
      return rows;
    } on RecordFailure {
      rethrow;
    } catch (_) {
      throw RecordFailure(RecordProblem.unavailable);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> read(String table) async {
    final result = <Map<String, dynamic>>[];
    const size = 500;
    for (var offset = 0; ; offset += size) {
      final page = await _request('GET', table, {
        'select': '*',
        'order': 'id.asc',
        'limit': '$size',
        'offset': '$offset',
      });
      result.addAll(page);
      if (page.length < size) return result;
    }
  }

  @override
  Future<Map<String, dynamic>> create(
    String table,
    String requestId,
    Map<String, Object?> values,
  ) async {
    // Unique(owner, client_request_id) makes ambiguous network retries safe.
    final rows = await _request(
      'POST',
      table,
      {'on_conflict': 'user_id,client_request_id', 'select': '*'},
      values: {...values, 'client_request_id': requestId},
      prefer: 'resolution=ignore-duplicates,return=representation',
    );
    if (rows.isNotEmpty) return rows.single;
    final existing = await _request('GET', table, {
      'select': '*',
      'client_request_id': 'eq.$requestId',
    });
    if (existing.length != 1) throw RecordFailure(RecordProblem.conflict);
    return existing.single;
  }

  @override
  Future<Map<String, dynamic>> update(
    String table,
    String id,
    int version,
    Map<String, Object?> values,
  ) async {
    final rows = await _request(
      'PATCH',
      table,
      {'id': 'eq.$id', 'version': 'eq.$version', 'select': '*'},
      values: values,
      prefer: 'return=representation',
    );
    if (rows.isEmpty) throw RecordFailure(RecordProblem.conflict);
    return rows.single;
  }

  @override
  Future<void> delete(String table, String id, int version) async {
    final rows = await _request('DELETE', table, {
      'id': 'eq.$id',
      'version': 'eq.$version',
      'select': '*',
    }, prefer: 'return=representation');
    if (rows.isEmpty) throw RecordFailure(RecordProblem.conflict);
  }

  @override
  void close() {
    _closed = true;
    _client.close();
  }
}

class RemoteRecordsRepository extends RecordsRepository {
  RemoteRecordsRepository({
    required this.transport,
    required this.isCurrentSession,
    this.enabled = healthPersistenceEnabled,
  });
  final HealthRecordsTransport? transport;
  final bool Function() isCurrentSession;
  final bool enabled;
  final List<HealthEntry> _entries = [];
  final Map<String, HealthEntry> _createdDrafts = {};
  int _generation = 0;
  bool _disposed = false, _loading = false, _loaded = false, _writing = false;
  String? _loadError;
  @override
  bool get isRemote => true;
  @override
  bool get loading => _loading;
  @override
  bool get loaded => _loaded;
  @override
  String? get loadError => _loadError;
  @override
  List<HealthEntry> get entries => List.unmodifiable(
    [..._entries]..sort((a, b) => b.when.compareTo(a.when)),
  );
  @override
  String newId() {
    _check(_generation);
    return 'draft-${_requestId()}';
  }

  void _check(int generation) {
    if (_disposed) throw RecordFailure(RecordProblem.closed);
    if (_generation != generation || !isCurrentSession()) {
      throw RecordFailure(RecordProblem.cancelled);
    }
  }

  void _available() {
    if (!enabled || transport == null) {
      throw RecordFailure(RecordProblem.deployment);
    }
  }

  @override
  Future<void> load() async {
    if (_disposed || !isCurrentSession() || _loading || _writing) return;
    final generation = _generation;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _check(generation);
      _available();
      final journals = await transport!.read('journal_entries');
      _check(generation);
      final observations = await transport!.read('health_observations');
      _check(generation);
      final entries = [
        ...journals.map((row) => HealthRowCodec.decode('journal_entries', row)),
        ...observations.map(
          (row) => HealthRowCodec.decode('health_observations', row),
        ),
      ];
      _entries
        ..clear()
        ..addAll(entries);
      _loaded = true;
    } catch (error) {
      if (!_disposed && generation == _generation && isCurrentSession()) {
        _loadError = recordErrorMessage(error, deleting: false);
      }
    } finally {
      if (!_disposed && generation == _generation && isCurrentSession()) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _write(Future<void> Function(int) action) async {
    final generation = _generation;
    _check(generation);
    _available();
    if (_loading || _writing) throw RecordFailure(RecordProblem.busy);
    if (!_loaded) throw RecordFailure(RecordProblem.unavailable);
    _writing = true;
    try {
      await action(generation);
    } on RecordFailure {
      rethrow;
    } catch (_) {
      throw RecordFailure(RecordProblem.unavailable);
    } finally {
      if (!_disposed && generation == _generation) _writing = false;
    }
  }

  @override
  Future<void> save(HealthEntry entry) => _write((generation) async {
    if (entry.title.trim().isEmpty ||
        entry.note.length > 50000 ||
        (entry.type != EntryType.journal && entry.note.length > 2000) ||
        entry.title.length > 200 ||
        entry.zone.isEmpty ||
        entry.zone.length > 100 ||
        (entry.tracking?.color?.length ?? 0) > 80 ||
        (entry.tracking?.consistency?.length ?? 0) > 80) {
      throw RecordFailure(RecordProblem.validation);
    }
    final table = HealthRowCodec.table(entry.type);
    final draft = entry.id.startsWith('draft-');
    final existing = _entries.where((e) => e.id == entry.id).firstOrNull;
    if (!draft && existing == null) throw RecordFailure(RecordProblem.notFound);
    if (draft && entry.version != 1 ||
        !draft &&
            (existing!.version + 1 != entry.version ||
                existing.type != entry.type)) {
      throw RecordFailure(RecordProblem.conflict);
    }
    // A repeated successful create in this session reuses its confirmed result.
    final confirmed = _createdDrafts[entry.id];
    if (confirmed != null) {
      if (jsonEncode(HealthRowCodec.encode(confirmed)) !=
          jsonEncode(HealthRowCodec.encode(entry))) {
        throw RecordFailure(RecordProblem.conflict);
      }
      return;
    }
    final row = draft
        ? await transport!.create(
            table,
            entry.id.substring(6),
            HealthRowCodec.encode(entry),
          )
        : await transport!.update(
            table,
            entry.id,
            entry.version - 1,
            HealthRowCodec.encode(entry),
          );
    _check(generation);
    final saved = HealthRowCodec.decode(table, row);
    if (draft &&
        jsonEncode(HealthRowCodec.encode(saved)) !=
            jsonEncode(HealthRowCodec.encode(entry))) {
      throw RecordFailure(RecordProblem.conflict);
    }
    if (draft) _createdDrafts[entry.id] = saved;
    _entries.removeWhere((e) => e.id == saved.id);
    _entries.add(saved);
    notifyListeners();
  });

  @override
  Future<void> delete(String id, {required int expectedVersion}) =>
      _write((generation) async {
        final existing = _entries.where((e) => e.id == id).firstOrNull;
        if (existing == null) throw RecordFailure(RecordProblem.notFound);
        if (existing.version != expectedVersion) {
          throw RecordFailure(RecordProblem.conflict);
        }
        await transport!.delete(
          HealthRowCodec.table(existing.type),
          id,
          expectedVersion,
        );
        _check(generation);
        _entries.removeWhere((e) => e.id == id);
        notifyListeners();
      });

  @override
  void reset({bool sample = false, DateTime? now}) {
    if (_disposed) return;
    _generation++;
    _entries.clear();
    _createdDrafts.clear();
    _loaded = false;
    _loading = false;
    _writing = false;
    _loadError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _entries.clear();
    _createdDrafts.clear();
    transport?.close();
    super.dispose();
  }
}

RecordsRepository authenticatedRecords(AuraAuthController auth) {
  final owner = auth.userId!;
  HealthRecordsTransport? transport;
  try {
    transport = SupabaseHealthTransport(
      config: SupabaseConfiguration.fromEnvironment(),
      auth: auth,
      owner: owner,
    );
  } catch (_) {
    // Safe deployment error is surfaced by load().
  }
  return RemoteRecordsRepository(
    transport: transport,
    isCurrentSession: () =>
        auth.mode == AccessMode.authenticated && auth.userId == owner,
  );
}
