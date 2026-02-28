import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';

/// Maps a verified exercise's English key [name] to its localized display name.
/// Falls back to [name] directly for custom (user-created) items.
String localizedExerciseName(
  String name, {
  required bool isVerified,
  required AppLocalizations l10n,
}) {
  if (!isVerified) return name;
  return _exerciseNameMap(l10n)[name] ?? name;
}

/// Returns the localized display name for a [MuscleGroup].
String localizedMuscleGroupName(MuscleGroup group, AppLocalizations l10n) =>
    switch (group) {
      MuscleGroup.chest => l10n.muscleGroupChest,
      MuscleGroup.back => l10n.muscleGroupBack,
      MuscleGroup.shoulders => l10n.muscleGroupShoulders,
      MuscleGroup.biceps => l10n.muscleGroupBiceps,
      MuscleGroup.triceps => l10n.muscleGroupTriceps,
      MuscleGroup.forearms => l10n.muscleGroupForearms,
      MuscleGroup.abs => l10n.muscleGroupAbs,
      MuscleGroup.quadriceps => l10n.muscleGroupQuadriceps,
      MuscleGroup.hamstrings => l10n.muscleGroupHamstrings,
      MuscleGroup.glutes => l10n.muscleGroupGlutes,
      MuscleGroup.adductors => l10n.muscleGroupAdductors,
      MuscleGroup.calves => l10n.muscleGroupCalves,
      MuscleGroup.fullBody => l10n.muscleGroupFullBody,
      MuscleGroup.cardio => l10n.muscleGroupCardio,
    };

/// Returns the localized display name for a [TargetMuscle].
String localizedTargetMuscle(TargetMuscle muscle, AppLocalizations l10n) =>
    switch (muscle) {
      TargetMuscle.pectoralisMajor => l10n.musclePectoralisMajor,
      TargetMuscle.pectoralisMinor => l10n.musclePectoralisMinor,
      TargetMuscle.latissimusDorsi => l10n.muscleLatissimusDorsi,
      TargetMuscle.rhomboids => l10n.muscleRhomboids,
      TargetMuscle.trapezius => l10n.muscleTrapezius,
      TargetMuscle.erectorSpinae => l10n.muscleErectorSpinae,
      TargetMuscle.teresMajor => l10n.muscleTeresMajor,
      TargetMuscle.anteriorDeltoid => l10n.muscleAnteriorDeltoid,
      TargetMuscle.lateralDeltoid => l10n.muscleLateralDeltoid,
      TargetMuscle.rearDeltoid => l10n.muscleRearDeltoid,
      TargetMuscle.bicepsBrachii => l10n.muscleBicepsBrachii,
      TargetMuscle.brachialis => l10n.muscleBrachialis,
      TargetMuscle.brachioradialis => l10n.muscleBrachioradialis,
      TargetMuscle.tricepsBrachii => l10n.muscleTricepsBrachii,
      TargetMuscle.wristFlexors => l10n.muscleWristFlexors,
      TargetMuscle.wristExtensors => l10n.muscleWristExtensors,
      TargetMuscle.rectusAbdominis => l10n.muscleRectusAbdominis,
      TargetMuscle.transverseAbdominis => l10n.muscleTransverseAbdominis,
      TargetMuscle.obliques => l10n.muscleObliques,
      TargetMuscle.rectusFemoris => l10n.muscleRectusFemoris,
      TargetMuscle.vastusLateralis => l10n.muscleVastusLateralis,
      TargetMuscle.vastusMedialis => l10n.muscleVastusMedialis,
      TargetMuscle.vastusIntermedius => l10n.muscleVastusIntermedius,
      TargetMuscle.bicepsFemoris => l10n.muscleBicepsFemoris,
      TargetMuscle.semitendinosus => l10n.muscleSemitendinosus,
      TargetMuscle.semimembranosus => l10n.muscleSemimembranosus,
      TargetMuscle.gluteusMaximus => l10n.muscleGluteusMaximus,
      TargetMuscle.gluteusMedius => l10n.muscleGluteusMedius,
      TargetMuscle.gluteusMinimus => l10n.muscleGluteusMinimus,
      TargetMuscle.tensorFasciaeLatae => l10n.muscleTensorFasciaeLatae,
      TargetMuscle.adductorMagnus => l10n.muscleAdductorMagnus,
      TargetMuscle.adductorLongus => l10n.muscleAdductorLongus,
      TargetMuscle.adductorBrevis => l10n.muscleAdductorBrevis,
      TargetMuscle.gastrocnemius => l10n.muscleGastrocnemius,
      TargetMuscle.soleus => l10n.muscleSoleus,
      TargetMuscle.hipFlexors => l10n.muscleHipFlexors,
      TargetMuscle.serratus => l10n.muscleSerratus,
    };

/// Returns the localized display name for a [MuscleRegion].
String localizedMuscleRegion(MuscleRegion region, AppLocalizations l10n) =>
    switch (region) {
      MuscleRegion.upper => l10n.regionUpper,
      MuscleRegion.mid => l10n.regionMid,
      MuscleRegion.lower => l10n.regionLower,
      MuscleRegion.longHead => l10n.regionLongHead,
      MuscleRegion.shortHead => l10n.regionShortHead,
      MuscleRegion.medialHead => l10n.regionMedialHead,
      MuscleRegion.lateralHead => l10n.regionLateralHead,
    };

/// Returns the localized display name for a [MovementPattern].
String localizedMovementPattern(MovementPattern p, AppLocalizations l10n) =>
    switch (p) {
      MovementPattern.push => l10n.movementPush,
      MovementPattern.pull => l10n.movementPull,
      MovementPattern.hinge => l10n.movementHinge,
      MovementPattern.squat => l10n.movementSquat,
      MovementPattern.lunge => l10n.movementLunge,
      MovementPattern.carry => l10n.movementCarry,
      MovementPattern.rotation => l10n.movementRotation,
      MovementPattern.isolation => l10n.movementIsolation,
    };

/// Returns the localized display name for a [MuscleRole].
String localizedMuscleRole(MuscleRole role, AppLocalizations l10n) =>
    switch (role) {
      MuscleRole.primary => l10n.musclePrimary,
      MuscleRole.secondary => l10n.muscleSecondary,
    };

Map<String, String> _exerciseNameMap(AppLocalizations l10n) => {
      'flatBarbellBenchPress': l10n.exerciseFlatBarbellBenchPress,
      'inclineBarbellBenchPress': l10n.exerciseInclineBarbellBenchPress,
      'dumbbellFly': l10n.exerciseDumbbellFly,
      'pushUp': l10n.exercisePushUp,
      'cableCrossover': l10n.exerciseCableCrossover,
      'machineChestPress': l10n.exerciseMachineChestPress,
      'inclineDumbbellPress': l10n.exerciseInclineDumbbellPress,
      'declinePushUp': l10n.exerciseDeclinePushUp,
      'inclinePushUp': l10n.exerciseInclinePushUp,
      'kneePushUp': l10n.exerciseKneePushUp,
      'pullUp': l10n.exercisePullUp,
      'barbellRow': l10n.exerciseBarbellRow,
      'latPulldown': l10n.exerciseLatPulldown,
      'seatedCableRow': l10n.exerciseSeatedCableRow,
      'dumbbellRow': l10n.exerciseDumbbellRow,
      'chinUp': l10n.exerciseChinUp,
      'invertedRow': l10n.exerciseInvertedRow,
      'dumbbellShrug': l10n.exerciseDumbbellShrug,
      'overheadPress': l10n.exerciseOverheadPress,
      'lateralRaise': l10n.exerciseLateralRaise,
      'facePull': l10n.exerciseFacePull,
      'arnoldPress': l10n.exerciseArnoldPress,
      'rearDeltFly': l10n.exerciseRearDeltFly,
      'pikePushUp': l10n.exercisePikePushUp,
      'barbellCurl': l10n.exerciseBarbellCurl,
      'dumbbellCurl': l10n.exerciseDumbbellCurl,
      'hammerCurl': l10n.exerciseHammerCurl,
      'preacherCurl': l10n.exercisePreacherCurl,
      'tricepsPushdown': l10n.exerciseTricepsPushdown,
      'skullCrusher': l10n.exerciseSkullCrusher,
      'overheadTricepsExtension': l10n.exerciseOverheadTricepsExtension,
      'diamondPushUp': l10n.exerciseDiamondPushUp,
      'dip': l10n.exerciseDip,
      'barbellSquat': l10n.exerciseBarbellSquat,
      'legPress': l10n.exerciseLegPress,
      'lunge': l10n.exerciseLunge,
      'legExtension': l10n.exerciseLegExtension,
      'hackSquat': l10n.exerciseHackSquat,
      'bulgarianSplitSquat': l10n.exerciseBulgarianSplitSquat,
      'romanianDeadlift': l10n.exerciseRomanianDeadlift,
      'nordicCurl': l10n.exerciseNordicCurl,
      'legCurl': l10n.exerciseLegCurl,
      'hipThrust': l10n.exerciseHipThrust,
      'gluteBridge': l10n.exerciseGluteBridge,
      'cableKickback': l10n.exerciseCableKickback,
      'standingCalfRaise': l10n.exerciseStandingCalfRaise,
      'seatedCalfRaise': l10n.exerciseSeatedCalfRaise,
      'crunch': l10n.exerciseCrunch,
      'plank': l10n.exercisePlank,
      'hangingLegRaise': l10n.exerciseHangingLegRaise,
      'abWheelRollout': l10n.exerciseAbWheelRollout,
      'wristCurl': l10n.exerciseWristCurl,
      'reverseWristCurl': l10n.exerciseReverseWristCurl,
      'deadlift': l10n.exerciseDeadlift,
      'burpee': l10n.exerciseBurpee,
      'treadmillRun': l10n.exerciseTreadmillRun,
      'stationaryBike': l10n.exerciseStationaryBike,
      'rowingMachine': l10n.exerciseRowingMachine,
      'elliptical': l10n.exerciseElliptical,
      'jumpRope': l10n.exerciseJumpRope,
      'jumpingJacks': l10n.exerciseJumpingJacks,
      'adductorMachine': l10n.exerciseAdductorMachine,
      'abductorMachine': l10n.exerciseAbductorMachine,
    };
