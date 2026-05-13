import 'package:drift/drift.dart';
import 'dart:convert';

import '../../../domain/enums/body_aesthetic.dart';
import '../../../domain/enums/experience_level.dart';
import '../../../domain/enums/gender.dart';
import '../../../domain/enums/selected_module.dart';
import '../../../domain/enums/training_goal.dart';
import '../../../domain/enums/training_style.dart';

class StringListJsonConverter extends TypeConverter<List<String>, String> {
  const StringListJsonConverter();

  @override
  List<String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Object?>()
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Display name chosen by the user.
  TextColumn get name => text().nullable()();

  /// Height in cm.
  RealColumn get height => real().nullable()();

  IntColumn get age => integer().nullable()();
  TextColumn get goal => textEnum<TrainingGoal>().nullable()();
  TextColumn get bodyAesthetic => textEnum<BodyAesthetic>().nullable()();
  TextColumn get trainingStyle => textEnum<TrainingStyle>().nullable()();
  TextColumn get experienceLevel => textEnum<ExperienceLevel>().nullable()();

  /// Gender for personalized recommendations.
  TextColumn get gender => textEnum<Gender>().nullable()();

  /// Preferred training days per week (1-7).
  IntColumn get trainingFrequency => integer().nullable()();

  /// Available time per workout in minutes (e.g. 45, 60). Null = not set.
  IntColumn get availableWorkoutMinutes => integer().nullable()();

  /// Whether the user trains at a gym.
  BoolColumn get trainsAtGym =>
      boolean().nullable().withDefault(const Constant(null))();

  /// Free-text injuries or physical limitations.
  TextColumn get injuries => text().nullable()();

  /// Free-text background/history, enriched by Chiron.
  TextColumn get bio => text().nullable()();

  /// Free-text list of equipment names owned by the user.
  TextColumn get ownedEquipmentNames =>
      text().nullable().map(const StringListJsonConverter())();

  /// Last module the user was in.
  TextColumn get lastActiveModule =>
      textEnum<AppModule>().withDefault(Constant(AppModule.training.name))();

  /// Consecutive sessions following expected cycle order (cross-program).
  IntColumn get currentCycleStreak =>
      integer().withDefault(const Constant(0))();

  /// Best ever cycle streak.
  IntColumn get bestCycleStreak => integer().withDefault(const Constant(0))();

  /// Consecutive weeks hitting weekly session target (Mon–Sun).
  IntColumn get currentFrequencyStreak =>
      integer().withDefault(const Constant(0))();

  /// Best ever weekly frequency streak.
  IntColumn get bestFrequencyStreak =>
      integer().withDefault(const Constant(0))();

  /// Bump when streak algorithm changes; 0 triggers one recompute from history.
  IntColumn get trainingStreaksSchema =>
      integer().withDefault(const Constant(0))();

  /// Supabase Auth user id linked to this local profile cache.
  TextColumn get remoteUserId => text().nullable()();

  /// Last successful profile sync with the remote account.
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
