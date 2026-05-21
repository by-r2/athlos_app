import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/utils/uuid.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/body_aesthetic.dart';
import '../../domain/enums/experience_level.dart';
import '../../domain/enums/gender.dart';
import '../../domain/enums/training_goal.dart';
import '../../domain/enums/training_style.dart';
import '../../data/repositories/profile_providers.dart';

part 'profile_notifier.g.dart';

/// Manages the user profile state across the app.
///
/// Loads the profile from the database on init. Exposes methods
/// to create, update, and check if a profile exists.
@Riverpod(keepAlive: true)
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<UserProfile?> build() async {
    final repo = ref.watch(userProfileRepositoryProvider);
    final result = await repo.get();
    return result.getOrThrow();
  }

  /// Creates a new user profile and updates the state.
  Future<void> create({
    String? name,
    double? height,
    int? age,
    TrainingGoal? goal,
    BodyAesthetic? bodyAesthetic,
    TrainingStyle? trainingStyle,
    ExperienceLevel? experienceLevel,
    Gender? gender,
    int? trainingFrequency,
    bool? trainsAtGym,
    String? injuries,
    String? bio,
  }) async {
    final repo = ref.read(userProfileRepositoryProvider);
    final profile = UserProfile(
      id: generateUuidV4(),
      name: name,
      height: height,
      age: age,
      goal: goal,
      bodyAesthetic: bodyAesthetic,
      trainingStyle: trainingStyle,
      experienceLevel: experienceLevel,
      gender: gender,
      trainingFrequency: trainingFrequency,
      trainsAtGym: trainsAtGym,
      injuries: injuries,
      bio: bio,
    );
    final result = await repo.create(profile);
    result.getOrThrow();
    final created = (await repo.get()).getOrThrow();
    state = AsyncData(created ?? profile);
  }

  /// Updates an existing user profile and refreshes the state.
  Future<void> updateProfile(UserProfile profile) async {
    final repo = ref.read(userProfileRepositoryProvider);
    final result = await repo.update(profile);
    result.getOrThrow();
    final refreshed = (await repo.get()).getOrThrow();
    state = AsyncData(refreshed ?? profile);
  }
}

/// Simple provider to check if a profile exists.
/// Used by the redirect guard in the router.
@Riverpod(keepAlive: true)
class HasProfile extends _$HasProfile {
  @override
  Future<bool> build() async {
    final repo = ref.watch(userProfileRepositoryProvider);
    final result = await repo.hasProfile();
    return result.getOrThrow();
  }

  /// Force refresh after profile creation.
  void markAsCreated() {
    state = const AsyncData(true);
  }

  /// Creates an empty profile (used when skipping setup) and marks as created.
  Future<void> createEmpty() async {
    final repo = ref.read(userProfileRepositoryProvider);
    final emptyProfile = UserProfile(id: generateUuidV4());
    final result = await repo.create(emptyProfile);
    result.getOrThrow();
    state = const AsyncData(true);
  }
}
