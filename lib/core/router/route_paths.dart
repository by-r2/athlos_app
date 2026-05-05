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
  static const profileConflicts = '/profile/conflicts';

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
  static const trainingEquipment = '/training/equipment';
  static const trainingWorkoutCatalog = '/training/workout-catalog';
  static const trainingWorkoutNew = '/training/workouts/new';
  static const trainingPrograms = '/training/programs';
  static const trainingProgramNew = '/training/programs/new';
  static String trainingProgramDetail(int programId) =>
      '$trainingPrograms/$programId';
  static String trainingProgramEdit(int programId) =>
      '$trainingPrograms/$programId/edit';
  static String trainingEquipmentDetail(int equipmentId) =>
      '$trainingEquipment/$equipmentId';
  // :executionId used via string interpolation
  // e.g. '${trainingHistory}/$id'
  // :workoutId used via string interpolation
  // e.g. '${trainingWorkouts}/$id' and '${trainingWorkouts}/$id/edit'

  // Progress visualization
  static String trainingExerciseLoadChart(int exerciseId) =>
      '$trainingExercises/$exerciseId/load-chart';
  static const trainingPRHistory = '/training/pr-history';
  static const trainingVolumeTrend = '/training/volume-trend';

  // Diet module (future)
  static const diet = '/diet';
}
