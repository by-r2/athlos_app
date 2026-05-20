import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_config.dart';
import '../../domain/entities/body_metric.dart';
import 'body_metric_remote_sync_gateway.dart';

class BodyMetricRemoteDataSource implements BodyMetricRemoteSyncGateway {
  static const _table = 'body_metrics';

  supabase.SupabaseClient? get _client =>
      isSupabaseConfigured ? supabase.Supabase.instance.client : null;

  @override
  String? get currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<List<BodyMetric>> fetchAllForCurrentUser() async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) return const [];

    final rows = await client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false);
    return rows.map<BodyMetric>(_fromJson).toList(growable: false);
  }

  @override
  Future<DateTime> upsert({
    required String remoteId,
    required BodyMetric metric,
  }) async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync body metrics.');
    }

    final syncedAt = DateTime.now().toUtc();
    await client.from(_table).upsert(
      _toJson(metric, userId: userId, remoteId: remoteId, syncedAt: syncedAt),
      onConflict: 'id',
    );
    return syncedAt;
  }

  @override
  Future<void> delete(String remoteId) async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync body metrics.');
    }

    await client.from(_table).delete().eq('id', remoteId).eq('user_id', userId);
  }

  Map<String, dynamic> _toJson(
    BodyMetric metric, {
    required String userId,
    required String remoteId,
    required DateTime syncedAt,
  }) => <String, dynamic>{
    'id': remoteId,
    'user_id': userId,
    'weight': metric.weight,
    'body_fat_percent': metric.bodyFatPercent,
    'recorded_at': metric.recordedAt.toUtc().toIso8601String(),
    'updated_at': syncedAt.toIso8601String(),
  };

  BodyMetric _fromJson(Map<String, dynamic> row) => BodyMetric(
    id: 0,
    weight: _asDouble(row['weight']) ?? 0,
    bodyFatPercent: _asDouble(row['body_fat_percent']),
    recordedAt: _asDateTime(row['recorded_at']) ?? DateTime.now().toUtc(),
    remoteId: row['id'] as String?,
    lastSyncedAt: _asDateTime(row['updated_at']),
  );

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  DateTime? _asDateTime(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
