import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_config.dart';

/// Supabase push/pull for user-owned training tables.
class TrainingRemoteClient {
  supabase.SupabaseClient? get _client =>
      isSupabaseConfigured ? supabase.Supabase.instance.client : null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchUpdatedSince({
    required String table,
    required String userId,
    required DateTime lastPullAt,
    String? userIdColumn,
    String? ownerColumn,
    String? ownerId,
  }) async {
    final client = _client;
    if (client == null) return const [];

    var query = client.from(table).select();

    if (ownerColumn != null && ownerId != null) {
      query = query.eq(ownerColumn, ownerId);
    } else {
      final column = userIdColumn ?? 'user_id';
      query = query.eq(column, userId);
    }

    final rows = await query
        .gt('updated_at', lastPullAt.toUtc().toIso8601String());
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> upsert({
    required String table,
    required Map<String, dynamic> row,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthAppException('User must be signed in to sync training data.');
    }
    await client.from(table).upsert(row, onConflict: 'id');
  }

  Future<void> deleteRow({
    required String table,
    required String id,
    String? userId,
    String? userIdColumn,
    String? ownerColumn,
    String? ownerId,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthAppException('User must be signed in to sync training data.');
    }

    var query = client.from(table).delete().eq('id', id);
    if (ownerColumn != null && ownerId != null) {
      query = query.eq(ownerColumn, ownerId);
    } else if (userId != null) {
      query = query.eq(userIdColumn ?? 'user_id', userId);
    }
    await query;
  }

  Future<List<Map<String, dynamic>>> fetchSegmentsForSets(
    List<String> setIds,
  ) async {
    final client = _client;
    if (client == null || setIds.isEmpty) return const [];

    final rows = await client
        .from('execution_set_segments')
        .select()
        .inFilter('execution_set_id', setIds);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> replaceSegmentsForSet({
    required String setId,
    required List<Map<String, dynamic>> segments,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthAppException('User must be signed in to sync training data.');
    }

    await client
        .from('execution_set_segments')
        .delete()
        .eq('execution_set_id', setId);

    if (segments.isEmpty) return;
    await client.from('execution_set_segments').upsert(segments, onConflict: 'id');
  }

  Future<void> deleteSegmentsForSet(String setId) async {
    final client = _client;
    if (client == null) return;
    await client
        .from('execution_set_segments')
        .delete()
        .eq('execution_set_id', setId);
  }
}
