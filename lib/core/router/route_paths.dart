/// Centralized route path constants.
///
/// All route paths live here so that navigation is consistent and
/// refactoring a path requires changing only one place.
abstract final class RoutePaths {
  // Splash
  static const splash = '/splash';

  // Hub
  static const hub = '/';

  // Profile
  static const profile = '/profile';
  static const profileSetup = '/profile/setup';

  // Training module
  static const training = '/training';
  static const trainingHome = '/training/home';
  static const trainingWorkouts = '/training/workouts';
  static const trainingExercises = '/training/exercises';
  static const trainingHistory = '/training/history';
  static const trainingEquipment = '/training/equipment';
  static const trainingWorkoutNew = '/training/workouts/new';
  // :executionId used via string interpolation
  // e.g. '${trainingHistory}/$id'
  // :workoutId used via string interpolation
  // e.g. '${trainingWorkouts}/$id' and '${trainingWorkouts}/$id/edit'

  // Chiron AI assistant
  static const chiron = '/chiron';

  // Diet module (future)
  static const diet = '/diet';
}
