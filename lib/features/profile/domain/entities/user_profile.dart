import '../enums/body_aesthetic.dart';
import '../enums/experience_level.dart';
import '../enums/gender.dart';
import '../enums/selected_module.dart';
import '../enums/training_goal.dart';
import '../enums/training_style.dart';

/// User profile with personal data and preferences.
class UserProfile {
  final int id;

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

  /// Consecutive sessions following expected cycle order (may span programs).
  final int currentCycleStreak;

  /// Best cycle streak ever recorded.
  final int bestCycleStreak;

  /// Consecutive weeks hitting the weekly session target.
  final int currentFrequencyStreak;

  /// Best weekly frequency streak ever recorded.
  final int bestFrequencyStreak;

  /// Version of streak algorithm; 0 means history should be materialized once.
  final int trainingStreaksSchema;

  /// Supabase Auth user id linked to this local profile cache.
  final String? remoteUserId;

  /// Last time the local profile was successfully written to the cloud.
  final DateTime? lastSyncedAt;

  /// Last local mutation timestamp used for dirty sync detection.
  final DateTime? localUpdatedAt;

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
    this.currentCycleStreak = 0,
    this.bestCycleStreak = 0,
    this.currentFrequencyStreak = 0,
    this.bestFrequencyStreak = 0,
    this.trainingStreaksSchema = 0,
    this.remoteUserId,
    this.lastSyncedAt,
    this.localUpdatedAt,
  });

  UserProfile copyWith({
    int? id,
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
    int? currentCycleStreak,
    int? bestCycleStreak,
    int? currentFrequencyStreak,
    int? bestFrequencyStreak,
    int? trainingStreaksSchema,
    String? Function()? remoteUserId,
    DateTime? Function()? lastSyncedAt,
    DateTime? Function()? localUpdatedAt,
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
    currentCycleStreak: currentCycleStreak ?? this.currentCycleStreak,
    bestCycleStreak: bestCycleStreak ?? this.bestCycleStreak,
    currentFrequencyStreak:
        currentFrequencyStreak ?? this.currentFrequencyStreak,
    bestFrequencyStreak: bestFrequencyStreak ?? this.bestFrequencyStreak,
    trainingStreaksSchema: trainingStreaksSchema ?? this.trainingStreaksSchema,
    remoteUserId: remoteUserId != null ? remoteUserId() : this.remoteUserId,
    lastSyncedAt: lastSyncedAt != null ? lastSyncedAt() : this.lastSyncedAt,
    localUpdatedAt:
        localUpdatedAt != null ? localUpdatedAt() : this.localUpdatedAt,
  );
}
