import 'package:drift/drift.dart';

import '../../../domain/enums/body_aesthetic.dart';
import '../../../domain/enums/experience_level.dart';
import '../../../domain/enums/gender.dart';
import '../../../domain/enums/selected_module.dart';
import '../../../domain/enums/training_goal.dart';
import '../../../domain/enums/training_style.dart';

class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Display name chosen by the user.
  TextColumn get name => text().nullable()();

  /// Weight in kg.
  RealColumn get weight => real().nullable()();

  /// Height in cm.
  RealColumn get height => real().nullable()();

  IntColumn get age => integer().nullable()();
  TextColumn get goal => textEnum<TrainingGoal>().nullable()();
  TextColumn get bodyAesthetic => textEnum<BodyAesthetic>().nullable()();
  TextColumn get trainingStyle => textEnum<TrainingStyle>().nullable()();
  TextColumn get experienceLevel =>
      textEnum<ExperienceLevel>().nullable()();

  /// Gender for personalized recommendations.
  TextColumn get gender => textEnum<Gender>().nullable()();

  /// Preferred training days per week (1-7).
  IntColumn get trainingFrequency => integer().nullable()();

  /// Whether the user trains at a gym.
  BoolColumn get trainsAtGym =>
      boolean().nullable().withDefault(const Constant(null))();

  /// Free-text injuries or physical limitations.
  TextColumn get injuries => text().nullable()();

  /// Free-text background/history, enriched by Chiron.
  TextColumn get bio => text().nullable()();

  /// Last module the user was in.
  TextColumn get lastActiveModule =>
      textEnum<AppModule>().withDefault(Constant(AppModule.training.name))();
}
