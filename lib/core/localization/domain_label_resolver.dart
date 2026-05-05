import '../../l10n/app_localizations.dart';

enum DomainLabelKind {
  equipment,
  exercise,
  muscleGroup,
  targetMuscle,
  muscleRegion,
  movementPattern,
  muscleRole,
  trainingGoal,
  trainingGoalDescription,
  trainingGoalImpact,
  bodyAesthetic,
  bodyAestheticDescription,
  bodyAestheticImpact,
  trainingStyle,
  trainingStyleDescription,
  trainingStyleImpact,
  experienceLevel,
  experienceLevelDescription,
  experienceLevelImpact,
  gender,
}

/// Resolves domain canonical keys to localized display names and back.
///
/// Canonical keys are stable identifiers persisted in data/domain layers
/// (e.g. "barbell", "benchPress").
class DomainLabelResolver {
  const DomainLabelResolver(this._l10n);

  final AppLocalizations _l10n;

  String toDisplayName({
    required DomainLabelKind kind,
    required String canonicalName,
    required bool isVerified,
  }) {
    if (!isVerified) return canonicalName;
    return _mapFor(kind)[canonicalName] ?? canonicalName;
  }

  String toCanonicalName({
    required DomainLabelKind kind,
    required String candidate,
  }) {
    final normalized = _normalize(candidate);
    if (normalized.isEmpty) return candidate.trim();

    final map = _mapFor(kind);
    for (final entry in map.entries) {
      if (_normalize(entry.key) == normalized) return entry.key;
      if (_normalize(entry.value) == normalized) return entry.key;
    }

    return candidate.trim();
  }

  Map<String, String> _mapFor(DomainLabelKind kind) => switch (kind) {
    DomainLabelKind.equipment => _equipmentNameMap(_l10n),
    DomainLabelKind.exercise => _exerciseNameMap(_l10n),
    DomainLabelKind.muscleGroup => _muscleGroupMap(_l10n),
    DomainLabelKind.targetMuscle => _targetMuscleMap(_l10n),
    DomainLabelKind.muscleRegion => _muscleRegionMap(_l10n),
    DomainLabelKind.movementPattern => _movementPatternMap(_l10n),
    DomainLabelKind.muscleRole => _muscleRoleMap(_l10n),
    DomainLabelKind.trainingGoal => _trainingGoalMap(_l10n),
    DomainLabelKind.trainingGoalDescription => _trainingGoalDescriptionMap(
      _l10n,
    ),
    DomainLabelKind.trainingGoalImpact => _trainingGoalImpactMap(_l10n),
    DomainLabelKind.bodyAesthetic => _bodyAestheticMap(_l10n),
    DomainLabelKind.bodyAestheticDescription => _bodyAestheticDescriptionMap(
      _l10n,
    ),
    DomainLabelKind.bodyAestheticImpact => _bodyAestheticImpactMap(_l10n),
    DomainLabelKind.trainingStyle => _trainingStyleMap(_l10n),
    DomainLabelKind.trainingStyleDescription => _trainingStyleDescriptionMap(
      _l10n,
    ),
    DomainLabelKind.trainingStyleImpact => _trainingStyleImpactMap(_l10n),
    DomainLabelKind.experienceLevel => _experienceLevelMap(_l10n),
    DomainLabelKind.experienceLevelDescription =>
      _experienceLevelDescriptionMap(_l10n),
    DomainLabelKind.experienceLevelImpact => _experienceLevelImpactMap(_l10n),
    DomainLabelKind.gender => _genderMap(_l10n),
  };

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

Map<String, String> _equipmentNameMap(AppLocalizations l10n) => {
  'barbell': l10n.equipmentBarbell,
  'dumbbell': l10n.equipmentDumbbell,
  'kettlebell': l10n.equipmentKettlebell,
  'ezBar': l10n.equipmentEzBar,
  'weightPlates': l10n.equipmentWeightPlates,
  'cableMachine': l10n.equipmentCableMachine,
  'smithMachine': l10n.equipmentSmithMachine,
  'legPressMachine': l10n.equipmentLegPressMachine,
  'latPulldownMachine': l10n.equipmentLatPulldownMachine,
  'chestPressMachine': l10n.equipmentChestPressMachine,
  'pecDeckMachine': l10n.equipmentPecDeckMachine,
  'pullUpBar': l10n.equipmentPullUpBar,
  'dipStation': l10n.equipmentDipStation,
  'gymnasticRings': l10n.equipmentGymnasticRings,
  'suspensionTrainer': l10n.equipmentSuspensionTrainer,
  'flatBench': l10n.equipmentFlatBench,
  'adjustableBench': l10n.equipmentAdjustableBench,
  'squatRack': l10n.equipmentSquatRack,
  'resistanceBands': l10n.equipmentResistanceBands,
  'abWheel': l10n.equipmentAbWheel,
  'medicineBall': l10n.equipmentMedicineBall,
  'battleRope': l10n.equipmentBattleRope,
  'foamRoller': l10n.equipmentFoamRoller,
  'treadmill': l10n.equipmentTreadmill,
  'stationaryBike': l10n.equipmentStationaryBike,
  'rowingMachine': l10n.equipmentRowingMachine,
  'elliptical': l10n.equipmentElliptical,
  'jumpRope': l10n.equipmentJumpRope,
  'legExtensionMachine': l10n.equipmentLegExtensionMachine,
  'legCurlMachine': l10n.equipmentLegCurlMachine,
  'seatedLegCurlMachine': l10n.equipmentSeatedLegCurlMachine,
  'hackSquatMachine': l10n.equipmentHackSquatMachine,
  'adductorMachine': l10n.equipmentAdductorMachine,
  'abductorMachine': l10n.equipmentAbductorMachine,
  'bicepsCurlMachine': l10n.equipmentBicepsCurlMachine,
  'preacherBench': l10n.equipmentPreacherBench,
};

Map<String, String> _exerciseNameMap(AppLocalizations l10n) => {
  'benchPress': l10n.exerciseFlatBarbellBenchPress,
  'inclineBenchPress': l10n.exerciseInclineBarbellBenchPress,
  'declineBenchPress': l10n.exerciseDeclineBarbellBenchPress,
  'chestFly': l10n.exerciseDumbbellFly,
  'pushUp': l10n.exercisePushUp,
  'cableCrossover': l10n.exerciseCableCrossover,
  'chestPress': l10n.exerciseMachineChestPress,
  'inclineDumbbellPress': l10n.exerciseInclineDumbbellPress,
  'declinePushUp': l10n.exerciseDeclinePushUp,
  'inclinePushUp': l10n.exerciseInclinePushUp,
  'kneePushUp': l10n.exerciseKneePushUp,
  'pullUp': l10n.exercisePullUp,
  'bentOverRow': l10n.exerciseBarbellRow,
  'latPulldown': l10n.exerciseLatPulldown,
  'seatedRow': l10n.exerciseSeatedCableRow,
  'singleArmRow': l10n.exerciseDumbbellRow,
  'chinUp': l10n.exerciseChinUp,
  'invertedRow': l10n.exerciseInvertedRow,
  'shrug': l10n.exerciseDumbbellShrug,
  'overheadPress': l10n.exerciseOverheadPress,
  'lateralRaise': l10n.exerciseLateralRaise,
  'facePull': l10n.exerciseFacePull,
  'arnoldPress': l10n.exerciseArnoldPress,
  'rearDeltFly': l10n.exerciseRearDeltFly,
  'pikePushUp': l10n.exercisePikePushUp,
  'bicepsCurl': l10n.exerciseBarbellCurl,
  'alternatingCurl': l10n.exerciseDumbbellCurl,
  'hammerCurl': l10n.exerciseHammerCurl,
  'preacherCurl': l10n.exercisePreacherCurl,
  'tricepsPushdown': l10n.exerciseTricepsPushdown,
  'skullCrusher': l10n.exerciseSkullCrusher,
  'overheadTricepsExtension': l10n.exerciseOverheadTricepsExtension,
  'diamondPushUp': l10n.exerciseDiamondPushUp,
  'dip': l10n.exerciseDip,
  'backSquat': l10n.exerciseBarbellSquat,
  'legPress': l10n.exerciseLegPress,
  'lunge': l10n.exerciseLunge,
  'legExtension': l10n.exerciseLegExtension,
  'hackSquat': l10n.exerciseHackSquat,
  'bulgarianSplitSquat': l10n.exerciseBulgarianSplitSquat,
  'romanianDeadlift': l10n.exerciseRomanianDeadlift,
  'nordicCurl': l10n.exerciseNordicCurl,
  'legCurl': l10n.exerciseLegCurl,
  'seatedLegCurl': l10n.exerciseSeatedLegCurl,
  'hipThrust': l10n.exerciseHipThrust,
  'gluteBridge': l10n.exerciseGluteBridge,
  'gluteKickback': l10n.exerciseCableKickback,
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
  'hipAdduction': l10n.exerciseAdductorMachine,
  'hipAbduction': l10n.exerciseAbductorMachine,
  // Legacy keys (merged into keepers in migration v30); same label as keeper for imports.
  'ezBarCurl': l10n.exerciseBarbellCurl,
  'dumbbellPreacherCurl': l10n.exercisePreacherCurl,
  'inclineCurl': l10n.exerciseInclineDumbbellCurl,
  'concentrationCurl': l10n.exerciseConcentrationCurl,
  'machinePreacherCurl': l10n.exercisePreacherCurl,
  'waiterCurl': l10n.exerciseWaiterCurl,
  'dragCurl': l10n.exerciseDragCurl,
  'spiderCurl': l10n.exerciseSpiderCurl,
  'cableCurl': l10n.exerciseCableCurl,
  'behindBackCableCurl': l10n.exerciseBehindBackCableCurl,
  'bayesianCableCurl': l10n.exerciseBayesianCableCurl,
  'preacherHammerCurl': l10n.exercisePreacherHammerCurl,
  'reverseZottmanCurl': l10n.exerciseReverseZottmanCurl,
  'neutralGripPullUp': l10n.exerciseNeutralGripPullUp,
  'closeGripPulldown': l10n.exerciseCloseGripPulldown,
  'neutralGripPulldown': l10n.exerciseNeutralGripPulldown,
  'underhandRow': l10n.exerciseUnderhandBarbellRow,
  'wideGripSeatedRow': l10n.exerciseWideGripSeatedRow,
  // Rope attachment merged into standard cable pushdown (migration v30).
  'ropeTricepsPushdown': l10n.exerciseTricepsPushdown,
  'sidePlank': l10n.exerciseSidePlank,
  'hollowHold': l10n.exerciseHollowHold,
  'lSit': l10n.exerciseLSit,
  'wallSit': l10n.exerciseWallSit,
  'deadHang': l10n.exerciseDeadHang,
};

Map<String, String> _muscleGroupMap(AppLocalizations l10n) => {
  'chest': l10n.muscleGroupChest,
  'back': l10n.muscleGroupBack,
  'shoulders': l10n.muscleGroupShoulders,
  'biceps': l10n.muscleGroupBiceps,
  'triceps': l10n.muscleGroupTriceps,
  'forearms': l10n.muscleGroupForearms,
  'abs': l10n.muscleGroupAbs,
  'quadriceps': l10n.muscleGroupQuadriceps,
  'hamstrings': l10n.muscleGroupHamstrings,
  'glutes': l10n.muscleGroupGlutes,
  'adductors': l10n.muscleGroupAdductors,
  'calves': l10n.muscleGroupCalves,
  'fullBody': l10n.muscleGroupFullBody,
  'cardio': l10n.muscleGroupCardio,
};

Map<String, String> _targetMuscleMap(AppLocalizations l10n) => {
  'pectoralisMajor': l10n.musclePectoralisMajor,
  'pectoralisMinor': l10n.musclePectoralisMinor,
  'latissimusDorsi': l10n.muscleLatissimusDorsi,
  'rhomboids': l10n.muscleRhomboids,
  'trapezius': l10n.muscleTrapezius,
  'erectorSpinae': l10n.muscleErectorSpinae,
  'teresMajor': l10n.muscleTeresMajor,
  'anteriorDeltoid': l10n.muscleAnteriorDeltoid,
  'lateralDeltoid': l10n.muscleLateralDeltoid,
  'rearDeltoid': l10n.muscleRearDeltoid,
  'bicepsBrachii': l10n.muscleBicepsBrachii,
  'brachialis': l10n.muscleBrachialis,
  'brachioradialis': l10n.muscleBrachioradialis,
  'tricepsBrachii': l10n.muscleTricepsBrachii,
  'wristFlexors': l10n.muscleWristFlexors,
  'wristExtensors': l10n.muscleWristExtensors,
  'rectusAbdominis': l10n.muscleRectusAbdominis,
  'transverseAbdominis': l10n.muscleTransverseAbdominis,
  'obliques': l10n.muscleObliques,
  'rectusFemoris': l10n.muscleRectusFemoris,
  'vastusLateralis': l10n.muscleVastusLateralis,
  'vastusMedialis': l10n.muscleVastusMedialis,
  'vastusIntermedius': l10n.muscleVastusIntermedius,
  'bicepsFemoris': l10n.muscleBicepsFemoris,
  'semitendinosus': l10n.muscleSemitendinosus,
  'semimembranosus': l10n.muscleSemimembranosus,
  'gluteusMaximus': l10n.muscleGluteusMaximus,
  'gluteusMedius': l10n.muscleGluteusMedius,
  'gluteusMinimus': l10n.muscleGluteusMinimus,
  'tensorFasciaeLatae': l10n.muscleTensorFasciaeLatae,
  'adductorMagnus': l10n.muscleAdductorMagnus,
  'adductorLongus': l10n.muscleAdductorLongus,
  'adductorBrevis': l10n.muscleAdductorBrevis,
  'gastrocnemius': l10n.muscleGastrocnemius,
  'soleus': l10n.muscleSoleus,
  'hipFlexors': l10n.muscleHipFlexors,
  'serratus': l10n.muscleSerratus,
};

Map<String, String> _muscleRegionMap(AppLocalizations l10n) => {
  'upper': l10n.regionUpper,
  'mid': l10n.regionMid,
  'lower': l10n.regionLower,
  'longHead': l10n.regionLongHead,
  'shortHead': l10n.regionShortHead,
  'medialHead': l10n.regionMedialHead,
  'lateralHead': l10n.regionLateralHead,
};

Map<String, String> _movementPatternMap(AppLocalizations l10n) => {
  'push': l10n.movementPush,
  'pull': l10n.movementPull,
  'hinge': l10n.movementHinge,
  'squat': l10n.movementSquat,
  'lunge': l10n.movementLunge,
  'carry': l10n.movementCarry,
  'rotation': l10n.movementRotation,
  'isolation': l10n.movementIsolation,
};

Map<String, String> _muscleRoleMap(AppLocalizations l10n) => {
  'primary': l10n.musclePrimary,
  'secondary': l10n.muscleSecondary,
};

Map<String, String> _trainingGoalMap(AppLocalizations l10n) => {
  'hypertrophy': l10n.goalHypertrophy,
  'weightLoss': l10n.goalWeightLoss,
  'endurance': l10n.goalEndurance,
  'strength': l10n.goalStrength,
  'generalFitness': l10n.goalGeneralFitness,
};

Map<String, String> _trainingGoalDescriptionMap(AppLocalizations l10n) => {
  'hypertrophy': l10n.goalHypertrophyDesc,
  'weightLoss': l10n.goalWeightLossDesc,
  'endurance': l10n.goalEnduranceDesc,
  'strength': l10n.goalStrengthDesc,
  'generalFitness': l10n.goalGeneralFitnessDesc,
};

Map<String, String> _trainingGoalImpactMap(AppLocalizations l10n) => {
  'hypertrophy': l10n.goalHypertrophyImpact,
  'weightLoss': l10n.goalWeightLossImpact,
  'endurance': l10n.goalEnduranceImpact,
  'strength': l10n.goalStrengthImpact,
  'generalFitness': l10n.goalGeneralFitnessImpact,
};

Map<String, String> _bodyAestheticMap(AppLocalizations l10n) => {
  'athletic': l10n.aestheticAthletic,
  'bulky': l10n.aestheticBulky,
  'robust': l10n.aestheticRobust,
};

Map<String, String> _bodyAestheticDescriptionMap(AppLocalizations l10n) => {
  'athletic': l10n.aestheticAthleticDesc,
  'bulky': l10n.aestheticBulkyDesc,
  'robust': l10n.aestheticRobustDesc,
};

Map<String, String> _bodyAestheticImpactMap(AppLocalizations l10n) => {
  'athletic': l10n.aestheticAthleticImpact,
  'bulky': l10n.aestheticBulkyImpact,
  'robust': l10n.aestheticRobustImpact,
};

Map<String, String> _trainingStyleMap(AppLocalizations l10n) => {
  'traditional': l10n.styleTraditional,
  'calisthenics': l10n.styleCalisthenics,
  'functional': l10n.styleFunctional,
  'hybrid': l10n.styleHybrid,
};

Map<String, String> _trainingStyleDescriptionMap(AppLocalizations l10n) => {
  'traditional': l10n.styleTraditionalDesc,
  'calisthenics': l10n.styleCalisthenicsDesc,
  'functional': l10n.styleFunctionalDesc,
  'hybrid': l10n.styleHybridDesc,
};

Map<String, String> _trainingStyleImpactMap(AppLocalizations l10n) => {
  'traditional': l10n.styleTraditionalImpact,
  'calisthenics': l10n.styleCalisthenicsImpact,
  'functional': l10n.styleFunctionalImpact,
  'hybrid': l10n.styleHybridImpact,
};

Map<String, String> _experienceLevelMap(AppLocalizations l10n) => {
  'beginner': l10n.experienceBeginner,
  'intermediate': l10n.experienceIntermediate,
  'advanced': l10n.experienceAdvanced,
};

Map<String, String> _experienceLevelDescriptionMap(AppLocalizations l10n) => {
  'beginner': l10n.experienceBeginnerDesc,
  'intermediate': l10n.experienceIntermediateDesc,
  'advanced': l10n.experienceAdvancedDesc,
};

Map<String, String> _experienceLevelImpactMap(AppLocalizations l10n) => {
  'beginner': l10n.experienceBeginnerImpact,
  'intermediate': l10n.experienceIntermediateImpact,
  'advanced': l10n.experienceAdvancedImpact,
};

Map<String, String> _genderMap(AppLocalizations l10n) => {
  'male': l10n.genderMale,
  'female': l10n.genderFemale,
};
