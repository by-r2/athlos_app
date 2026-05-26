import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_config.dart';
import '../../domain/entities/user_profile.dart';
import 'user_profile_remote_sync_gateway.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/selected_module.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';

class UserProfileRemoteDataSource implements UserProfileRemoteSyncGateway {
  static const _table = 'user_profiles';

  supabase.SupabaseClient? get _client =>
      isSupabaseConfigured ? supabase.Supabase.instance.client : null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<UserProfile?> fetchCurrentProfile() async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) return null;

    final row = await client
        .from(_table)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _fromJson(row);
  }

  @override
  Future<UserProfile?> fetchUpdatedSince(DateTime lastPullAt) async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) return null;

    final row = await client
        .from(_table)
        .select()
        .eq('id', userId)
        .gt('updated_at', lastPullAt.toUtc().toIso8601String())
        .maybeSingle();
    if (row == null) return null;
    return _fromJson(row);
  }

  @override
  Future<DateTime> upsertCurrentProfile(UserProfile profile) async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) {
      throw const AuthAppException('User must be signed in to sync profile.');
    }

    final syncedAt = DateTime.now().toUtc();
    await client
        .from(_table)
        .upsert(
          _toJson(profile, userId: userId, syncedAt: syncedAt),
          onConflict: 'id',
        );
    return syncedAt;
  }

  Map<String, dynamic> _toJson(
    UserProfile profile, {
    required String userId,
    required DateTime syncedAt,
  }) {
    // IMPORTANT:
    // Do NOT send nullable fields as `null` because Postgres UPSERT would
    // overwrite existing remote values. Omitting keys preserves remote data.
    final json = <String, dynamic>{
      'id': userId,
      'last_active_module': profile.lastActiveModule.name,
      'current_cycle_streak': profile.currentCycleStreak,
      'best_cycle_streak': profile.bestCycleStreak,
      'current_frequency_streak': profile.currentFrequencyStreak,
      'best_frequency_streak': profile.bestFrequencyStreak,
      'training_streaks_schema': profile.trainingStreaksSchema,
      'updated_at': syncedAt.toIso8601String(),
    };

    void putIfNotNull(String key, Object? value) {
      if (value != null) json[key] = value;
    }

    putIfNotNull('name', profile.name);
    putIfNotNull('height', profile.height);
    putIfNotNull('age', profile.age);
    putIfNotNull('goal', profile.goal?.name);
    putIfNotNull('body_aesthetic', profile.bodyAesthetic?.name);
    putIfNotNull('training_style', profile.trainingStyle?.name);
    putIfNotNull('experience_level', profile.experienceLevel?.name);
    putIfNotNull('gender', profile.gender?.name);
    putIfNotNull('training_frequency', profile.trainingFrequency);
    putIfNotNull('available_workout_minutes', profile.availableWorkoutMinutes);
    putIfNotNull('trains_at_gym', profile.trainsAtGym);
    putIfNotNull('injuries', profile.injuries);
    putIfNotNull('bio', profile.bio);

    if (profile.ownedEquipmentNames.isNotEmpty) {
      json['owned_equipment_names'] = profile.ownedEquipmentNames;
    }

    return json;
  }

  UserProfile _fromJson(Map<String, dynamic> row) => UserProfile(
    id: row['id'] as String,
    name: row['name'] as String?,
    height: _asDouble(row['height']),
    age: _asInt(row['age']),
    goal: _enumByName(TrainingGoal.values, row['goal']),
    bodyAesthetic: _enumByName(BodyAesthetic.values, row['body_aesthetic']),
    trainingStyle: _enumByName(TrainingStyle.values, row['training_style']),
    experienceLevel: _enumByName(
      ExperienceLevel.values,
      row['experience_level'],
    ),
    gender: _enumByName(Gender.values, row['gender']),
    trainingFrequency: _asInt(row['training_frequency']),
    availableWorkoutMinutes: _asInt(row['available_workout_minutes']),
    trainsAtGym: row['trains_at_gym'] as bool?,
    injuries: row['injuries'] as String?,
    bio: row['bio'] as String?,
    ownedEquipmentNames: _asStringList(row['owned_equipment_names']),
    lastActiveModule:
        _enumByName(AppModule.values, row['last_active_module']) ??
        AppModule.training,
    currentCycleStreak: _asInt(row['current_cycle_streak']) ?? 0,
    bestCycleStreak: _asInt(row['best_cycle_streak']) ?? 0,
    currentFrequencyStreak: _asInt(row['current_frequency_streak']) ?? 0,
    bestFrequencyStreak: _asInt(row['best_frequency_streak']) ?? 0,
    trainingStreaksSchema: _asInt(row['training_streaks_schema']) ?? 0,
  );

  T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}
