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
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  RealColumn get height => real().nullable()();
  IntColumn get age => integer().nullable()();
  TextColumn get goal => textEnum<TrainingGoal>().nullable()();
  TextColumn get bodyAesthetic => textEnum<BodyAesthetic>().nullable()();
  TextColumn get trainingStyle => textEnum<TrainingStyle>().nullable()();
  TextColumn get experienceLevel => textEnum<ExperienceLevel>().nullable()();
  TextColumn get gender => textEnum<Gender>().nullable()();
  IntColumn get trainingFrequency => integer().nullable()();
  IntColumn get availableWorkoutMinutes => integer().nullable()();
  BoolColumn get trainsAtGym =>
      boolean().nullable().withDefault(const Constant(null))();
  TextColumn get injuries => text().nullable()();
  TextColumn get bio => text().nullable()();
  TextColumn get ownedEquipmentNames =>
      text().nullable().map(const StringListJsonConverter())();
  TextColumn get lastActiveModule =>
      textEnum<AppModule>().withDefault(Constant(AppModule.training.name))();
  IntColumn get currentFrequencyStreak =>
      integer().withDefault(const Constant(0))();
  IntColumn get bestFrequencyStreak =>
      integer().withDefault(const Constant(0))();
  IntColumn get trainingStreaksSchema =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
