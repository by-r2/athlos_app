import '../enums/body_aesthetic.dart';
import '../enums/experience_level.dart';
import '../enums/gender.dart';
import '../enums/selected_module.dart';
import '../enums/training_goal.dart';
import '../enums/training_style.dart';

/// User profile with personal data and preferences.
class UserProfile {
  final String id;

  /// Display name chosen by the user.
  final String? name;

  /// Height in cm.
  final double? height;

  final int? age;
  final TrainingGoal? goal;
  final BodyAesthetic? bodyAesthetic;
  final TrainingStyle? trainingStyle;
  final ExperienceLevel? experienceLevel;

  /// Gender for personalized workout and aesthetic recommendations.
  final Gender? gender;

  /// Preferred training days per week (1-7).
  final int? trainingFrequency;

  /// Available time per workout in minutes (e.g. 45, 60). Null = not set.
  final int? availableWorkoutMinutes;

  /// Whether the user trains at a gym (has access to full equipment).
  final bool? trainsAtGym;

  /// Free-text injuries or physical limitations.
  final String? injuries;

  /// Free-text background/history, enriched by Chiron over time.
  final String? bio;

  /// Optional free-text names of equipment the user owns.
  final List<String> ownedEquipmentNames;

  /// Last module the user was in. Defaults to training.
  final AppModule lastActiveModule;

  /// Consecutive weeks hitting the weekly session target.
  final int currentFrequencyStreak;

  /// Best weekly frequency streak ever recorded.
  final int bestFrequencyStreak;

  /// Version of streak algorithm; 0 means history should be materialized once.
  final int trainingStreaksSchema;

  const UserProfile({
    required this.id,
    this.name,
    this.height,
    this.age,
    this.goal,
    this.bodyAesthetic,
    this.trainingStyle,
    this.experienceLevel,
    this.gender,
    this.trainingFrequency,
    this.availableWorkoutMinutes,
    this.trainsAtGym,
    this.injuries,
    this.bio,
    this.ownedEquipmentNames = const [],
    this.lastActiveModule = AppModule.training,
    this.currentFrequencyStreak = 0,
    this.bestFrequencyStreak = 0,
    this.trainingStreaksSchema = 0,
  });

  UserProfile copyWith({
    String? id,
    String? Function()? name,
    double? Function()? height,
    int? Function()? age,
    TrainingGoal? Function()? goal,
    BodyAesthetic? Function()? bodyAesthetic,
    TrainingStyle? Function()? trainingStyle,
    ExperienceLevel? Function()? experienceLevel,
    Gender? Function()? gender,
    int? Function()? trainingFrequency,
    int? Function()? availableWorkoutMinutes,
    bool? Function()? trainsAtGym,
    String? Function()? injuries,
    String? Function()? bio,
    List<String>? ownedEquipmentNames,
    AppModule? lastActiveModule,
    int? currentFrequencyStreak,
    int? bestFrequencyStreak,
    int? trainingStreaksSchema,
  }) => UserProfile(
    id: id ?? this.id,
    name: name != null ? name() : this.name,
    height: height != null ? height() : this.height,
    age: age != null ? age() : this.age,
    goal: goal != null ? goal() : this.goal,
    bodyAesthetic: bodyAesthetic != null ? bodyAesthetic() : this.bodyAesthetic,
    trainingStyle: trainingStyle != null ? trainingStyle() : this.trainingStyle,
    experienceLevel: experienceLevel != null
        ? experienceLevel()
        : this.experienceLevel,
    gender: gender != null ? gender() : this.gender,
    trainingFrequency: trainingFrequency != null
        ? trainingFrequency()
        : this.trainingFrequency,
    availableWorkoutMinutes: availableWorkoutMinutes != null
        ? availableWorkoutMinutes()
        : this.availableWorkoutMinutes,
    trainsAtGym: trainsAtGym != null ? trainsAtGym() : this.trainsAtGym,
    injuries: injuries != null ? injuries() : this.injuries,
    bio: bio != null ? bio() : this.bio,
    ownedEquipmentNames: ownedEquipmentNames ?? this.ownedEquipmentNames,
    lastActiveModule: lastActiveModule ?? this.lastActiveModule,
    currentFrequencyStreak:
        currentFrequencyStreak ?? this.currentFrequencyStreak,
    bestFrequencyStreak: bestFrequencyStreak ?? this.bestFrequencyStreak,
    trainingStreaksSchema: trainingStreaksSchema ?? this.trainingStreaksSchema,
  );
}
