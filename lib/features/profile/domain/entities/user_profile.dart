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

  /// Weight in kg.
  final double? weight;

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

  /// Whether the user trains at a gym (has access to full equipment).
  final bool? trainsAtGym;

  /// Free-text injuries or physical limitations.
  final String? injuries;

  /// Free-text background/history, enriched by Chiron over time.
  final String? bio;

  /// Last module the user was in. Defaults to training.
  final AppModule lastActiveModule;

  const UserProfile({
    required this.id,
    this.name,
    this.weight,
    this.height,
    this.age,
    this.goal,
    this.bodyAesthetic,
    this.trainingStyle,
    this.experienceLevel,
    this.gender,
    this.trainingFrequency,
    this.trainsAtGym,
    this.injuries,
    this.bio,
    this.lastActiveModule = AppModule.training,
  });

  UserProfile copyWith({
    int? id,
    String? Function()? name,
    double? Function()? weight,
    double? Function()? height,
    int? Function()? age,
    TrainingGoal? Function()? goal,
    BodyAesthetic? Function()? bodyAesthetic,
    TrainingStyle? Function()? trainingStyle,
    ExperienceLevel? Function()? experienceLevel,
    Gender? Function()? gender,
    int? Function()? trainingFrequency,
    bool? Function()? trainsAtGym,
    String? Function()? injuries,
    String? Function()? bio,
    AppModule? lastActiveModule,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name != null ? name() : this.name,
        weight: weight != null ? weight() : this.weight,
        height: height != null ? height() : this.height,
        age: age != null ? age() : this.age,
        goal: goal != null ? goal() : this.goal,
        bodyAesthetic:
            bodyAesthetic != null ? bodyAesthetic() : this.bodyAesthetic,
        trainingStyle:
            trainingStyle != null ? trainingStyle() : this.trainingStyle,
        experienceLevel:
            experienceLevel != null ? experienceLevel() : this.experienceLevel,
        gender: gender != null ? gender() : this.gender,
        trainingFrequency: trainingFrequency != null
            ? trainingFrequency()
            : this.trainingFrequency,
        trainsAtGym: trainsAtGym != null ? trainsAtGym() : this.trainsAtGym,
        injuries: injuries != null ? injuries() : this.injuries,
        bio: bio != null ? bio() : this.bio,
        lastActiveModule: lastActiveModule ?? this.lastActiveModule,
      );
}
