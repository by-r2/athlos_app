/// Centralized route path constants.
///
/// All route paths live here so that navigation is consistent and
/// refactoring a path requires changing only one place.
abstract final class RoutePaths {
  // Splash
  static const splash = '/splash';

  // Hub
  static const hub = '/';

  // Auth / account rollout
  static const authPrompt = '/auth';
  static const authSignIn = '/auth/sign-in';
  static const authSignUp = '/auth/sign-up';

  // Profile
  static const profile = '/profile';
  static const profileSetup = '/profile/setup';
  static const profileConflicts = '/profile/conflicts';
  static const profileSyncIssues = '/profile/sync-issues';

  // Training module
  static const training = '/training';
  static const trainingHome = '/training/home';
  static const trainingWorkouts = '/training/workouts';

  /// When present as `openProgramCyclePicker=1`, the Treinos tab opens the
  /// picker to link workouts into the active program cycle.
  static const queryOpenProgramCyclePicker = 'openProgramCyclePicker';

  static String trainingWorkoutsOpenCyclePickerQuery() =>
      '$trainingWorkouts?$queryOpenProgramCyclePicker=1';
  static const trainingExercises = '/training/exercises';
  static const trainingHistory = '/training/history';

  /// Full-screen summary after completing a workout (shareable card).
  static String trainingExecutionShareSummary(String executionId) =>
      '$trainingHistory/$executionId/share';
  static const trainingWorkoutCatalog = '/training/workout-catalog';
  static const trainingWorkoutNew = '/training/workouts/new';
  static const trainingPrograms = '/training/programs';
  static const trainingProgramNew = '/training/programs/new';
  static String trainingProgramDetail(String programId) =>
      '$trainingPrograms/$programId';
  static String trainingProgramEdit(String programId) =>
      '$trainingPrograms/$programId/edit';
  // :executionId used via string interpolation
  // e.g. '${trainingHistory}/$id'
  // :workoutId used via string interpolation
  // e.g. '${trainingWorkouts}/$id' and '${trainingWorkouts}/$id/edit'

  // Progress visualization
  static String trainingExerciseLoadChart(String exerciseId) =>
      '$trainingExercises/$exerciseId/load-chart';
  static const trainingPRHistory = '/training/pr-history';
  static const trainingVolumeTrend = '/training/volume-trend';

  // Diet module (future)
  static const diet = '/diet';
}
