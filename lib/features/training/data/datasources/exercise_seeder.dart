import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/enums/exercise_type.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';

typedef _MF = ({TargetMuscle muscle, MuscleRegion? region, MuscleRole role});

_MF _p(TargetMuscle m, [MuscleRegion? r]) =>
    (muscle: m, region: r, role: MuscleRole.primary);

_MF _s(TargetMuscle m, [MuscleRegion? r]) =>
    (muscle: m, region: r, role: MuscleRole.secondary);

/// Seeds the database with verified exercises on first creation.
///
/// Each exercise uses an English key as [name] (localized via ARB in the UI).
/// Variation edges are applied after all exercises are inserted.
Future<void> seedExercises(AppDatabase db) async {
  final exerciseIds = <String, int>{};

  for (final item in _seedItems) {
    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            movementPattern: Value(item.movementPattern),
            isVerified: const Value(true),
            isBodyweight: Value(item.isBodyweight),
            isIsometric: Value(item.isIsometric),
            description: const Value.absent(),
          ),
        );
    exerciseIds[item.name] = id;

    for (final focus in item.muscles) {
      await db.into(db.exerciseTargetMuscles).insert(
            ExerciseTargetMusclesCompanion(
              exerciseId: Value(id),
              targetMuscle: Value(focus.muscle),
              muscleRegion: Value(focus.region),
              role: Value(focus.role),
            ),
          );
    }

  }

  for (final link in _variations) {
    final fromId = exerciseIds[link.from];
    final toId = exerciseIds[link.to];
    if (fromId != null && toId != null) {
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(fromId),
              variationId: Value(toId),
            ),
          );
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(toId),
              variationId: Value(fromId),
            ),
          );
    }
  }
}

class _SeedExercise {
  final String name;
  final MuscleGroup muscleGroup;
  final ExerciseType type;
  final MovementPattern? movementPattern;
  final List<_MF> muscles;
  final bool isBodyweight;
  final bool isIsometric;

  const _SeedExercise(
    this.name,
    this.muscleGroup, {
    this.type = ExerciseType.strength,
    this.movementPattern,
    this.muscles = const [],
    this.isBodyweight = false,
    this.isIsometric = false,
  });
}

class _Variation {
  final String from;
  final String to;
  const _Variation(this.from, this.to);
}

final _seedItems = [
  // ── Chest ──
  _SeedExercise('benchPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('inclineBenchPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.upper),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('chestFly', MuscleGroup.chest,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
      ]),
  _SeedExercise('pushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('cableCrossover', MuscleGroup.chest,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
      ]),
  _SeedExercise('chestPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('inclineDumbbellPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.upper),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('declinePushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.upper),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('inclinePushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.lower),
      ]),
  _SeedExercise('kneePushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),

  // ── Back ──
  _SeedExercise('pullUp', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.rhomboids),
      ]),
  _SeedExercise('bentOverRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _p(TargetMuscle.rhomboids),
        _s(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('latPulldown', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('seatedRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.rhomboids),
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('singleArmRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _p(TargetMuscle.rhomboids),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('chinUp', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.rhomboids),
      ]),
  _SeedExercise('invertedRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.rhomboids),
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('shrug', MuscleGroup.back,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.trapezius),
      ]),

  // ── Shoulders ──
  _SeedExercise('overheadPress', MuscleGroup.shoulders,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.anteriorDeltoid),
        _p(TargetMuscle.lateralDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('lateralRaise', MuscleGroup.shoulders,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.lateralDeltoid),
      ]),
  _SeedExercise('facePull', MuscleGroup.shoulders,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.rhomboids),
      ]),
  _SeedExercise('arnoldPress', MuscleGroup.shoulders,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.anteriorDeltoid),
        _p(TargetMuscle.lateralDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('rearDeltFly', MuscleGroup.shoulders,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rearDeltoid),
      ]),
  _SeedExercise('pikePushUp', MuscleGroup.shoulders,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.anteriorDeltoid),
        _p(TargetMuscle.lateralDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),

  // ── Biceps ──
  _SeedExercise('bicepsCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('alternatingCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('inclineCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('concentrationCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('waiterCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('dragCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ]),
  _SeedExercise('spiderCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('cableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ]),
  _SeedExercise('behindBackCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('bayesianCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('hammerCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachialis),
        _p(TargetMuscle.brachioradialis),
      ]),
  _SeedExercise('preacherCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
      ]),
  _SeedExercise('preacherHammerCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachialis),
        _p(TargetMuscle.brachioradialis),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('reverseZottmanCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachioradialis),
        _p(TargetMuscle.brachialis),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.wristExtensors),
      ]),

  // ── Triceps ──
  _SeedExercise('tricepsPushdown', MuscleGroup.triceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.tricepsBrachii, MuscleRegion.lateralHead),
      ]),
  _SeedExercise('skullCrusher', MuscleGroup.triceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.tricepsBrachii, MuscleRegion.longHead),
      ]),
  _SeedExercise('overheadTricepsExtension', MuscleGroup.triceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.tricepsBrachii, MuscleRegion.longHead),
      ]),
  _SeedExercise('diamondPushUp', MuscleGroup.triceps,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.tricepsBrachii),
        _s(TargetMuscle.pectoralisMajor),
      ]),
  _SeedExercise('dip', MuscleGroup.triceps,
      movementPattern: MovementPattern.push,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.tricepsBrachii),
        _s(TargetMuscle.pectoralisMajor),
        _s(TargetMuscle.anteriorDeltoid),
      ]),

  // ── Quadriceps ──
  _SeedExercise('backSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ]),
  _SeedExercise('frontSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ]),
  _SeedExercise('gobletSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ]),
  _SeedExercise('legPress', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ]),
  _SeedExercise('lunge', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.lunge,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ]),
  _SeedExercise('bulgarianSplitSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.lunge,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ]),
  _SeedExercise('legExtension', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
      ]),
  _SeedExercise('hackSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ]),

  // ── Hamstrings ──
  _SeedExercise('romanianDeadlift', MuscleGroup.hamstrings,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.semitendinosus),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.erectorSpinae),
      ]),
  _SeedExercise('nordicCurl', MuscleGroup.hamstrings,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.semitendinosus),
      ]),
  _SeedExercise('legCurl', MuscleGroup.hamstrings,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.semitendinosus),
      ]),
  _SeedExercise('seatedLegCurl', MuscleGroup.hamstrings,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.semitendinosus),
      ]),

  // ── Glutes ──
  _SeedExercise('hipThrust', MuscleGroup.glutes,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ]),
  _SeedExercise('gluteBridge', MuscleGroup.glutes, isBodyweight: true,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.gluteusMaximus),
      ]),
  _SeedExercise('gluteKickback', MuscleGroup.glutes,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.gluteusMedius),
      ]),

  // ── Adductors ──
  _SeedExercise('hipAdduction', MuscleGroup.adductors,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.adductorMagnus),
        _p(TargetMuscle.adductorLongus),
        _p(TargetMuscle.adductorBrevis),
      ]),
  _SeedExercise('hipAbduction', MuscleGroup.glutes,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gluteusMedius),
        _p(TargetMuscle.gluteusMinimus),
        _p(TargetMuscle.tensorFasciaeLatae),
      ]),

  // ── Calves ──
  _SeedExercise('standingCalfRaise', MuscleGroup.calves,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gastrocnemius),
      ]),
  _SeedExercise('seatedCalfRaise', MuscleGroup.calves,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.soleus),
      ]),

  // ── Abs ──
  _SeedExercise('crunch', MuscleGroup.abs, isBodyweight: true,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rectusAbdominis, MuscleRegion.upper),
      ]),
  _SeedExercise('plank', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusAbdominis),
    _p(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.obliques),
  ]),
  _SeedExercise('sidePlank', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.obliques),
    _s(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.gluteusMedius),
  ]),
  _SeedExercise('hollowHold', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusAbdominis),
    _p(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.hipFlexors),
  ]),
  _SeedExercise('lSit', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusAbdominis),
    _p(TargetMuscle.hipFlexors),
    _s(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.tricepsBrachii),
  ]),
  _SeedExercise('wallSit', MuscleGroup.quadriceps,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusFemoris),
    _p(TargetMuscle.vastusLateralis),
    _p(TargetMuscle.vastusMedialis),
    _s(TargetMuscle.gluteusMaximus),
  ]),
  _SeedExercise('deadHang', MuscleGroup.back,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.latissimusDorsi),
    _p(TargetMuscle.wristFlexors),
    _s(TargetMuscle.trapezius),
    _s(TargetMuscle.rhomboids),
  ]),
  _SeedExercise('hangingLegRaise', MuscleGroup.abs, isBodyweight: true,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rectusAbdominis, MuscleRegion.lower),
        _s(TargetMuscle.hipFlexors),
      ]),
  _SeedExercise('abWheelRollout', MuscleGroup.abs,
      muscles: [
        _p(TargetMuscle.rectusAbdominis),
        _s(TargetMuscle.obliques),
      ]),

  // ── Forearms ──
  _SeedExercise('wristCurl', MuscleGroup.forearms,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.wristFlexors),
      ]),
  _SeedExercise('reverseWristCurl', MuscleGroup.forearms,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.wristExtensors),
      ]),

  // ── Full Body ──
  _SeedExercise('deadlift', MuscleGroup.fullBody,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.gluteusMaximus),
        _p(TargetMuscle.erectorSpinae),
        _s(TargetMuscle.trapezius),
        _s(TargetMuscle.rectusFemoris),
      ]),
  _SeedExercise('burpee', MuscleGroup.fullBody, muscles: [
    _p(TargetMuscle.rectusFemoris),
    _s(TargetMuscle.pectoralisMajor),
    _s(TargetMuscle.anteriorDeltoid),
  ]),

  // ── Cardio ──
  _SeedExercise('treadmillRun', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('stationaryBike', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('rowingMachine', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('elliptical', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('jumpRope', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('jumpingJacks', MuscleGroup.cardio,
      type: ExerciseType.cardio),

  // ── V6 additions ──
  ..._v6SeedItems,
];

/// Seeds only the cardio exercises added in schema version 2.
/// Called from migration onUpgrade when upgrading from v1.
Future<void> seedExercisesV2(AppDatabase db) async {
  for (final item in _cardioSeedItems) {
    await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            isVerified: const Value(true),
            description: const Value.absent(),
          ),
        );
  }
}

const _cardioSeedItems = [
  _SeedExercise('treadmillRun', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('stationaryBike', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('rowingMachine', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('elliptical', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('jumpRope', MuscleGroup.cardio,
      type: ExerciseType.cardio),
  _SeedExercise('jumpingJacks', MuscleGroup.cardio,
      type: ExerciseType.cardio),
];

/// Seeds adductor/abductor exercises added in schema version 3.
/// Also updates movement_pattern for existing exercises.
Future<void> seedExercisesV3(AppDatabase db) async {
  for (final item in _v3SeedItems) {
    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            movementPattern: Value(item.movementPattern),
            isVerified: const Value(true),
            description: const Value.absent(),
          ),
        );

    for (final focus in item.muscles) {
      await db.into(db.exerciseTargetMuscles).insert(
            ExerciseTargetMusclesCompanion(
              exerciseId: Value(id),
              targetMuscle: Value(focus.muscle),
              muscleRegion: Value(focus.region),
              role: Value(focus.role),
            ),
          );
    }
  }

  // Back-fill movement_pattern for all pre-existing exercises
  for (final entry in _movementPatternBackfill.entries) {
    await db.customStatement(
      "UPDATE exercises SET movement_pattern = '${entry.value.name}' "
      "WHERE name = '${entry.key}' AND movement_pattern IS NULL",
    );
  }

  // Back-fill secondary roles for pre-existing exercises
  for (final entry in _secondaryRoleBackfill.entries) {
    for (final muscle in entry.value) {
      await db.customStatement(
        "UPDATE exercise_target_muscles SET role = 'secondary' "
        "WHERE exercise_id = (SELECT id FROM exercises WHERE name = '${entry.key}') "
        "AND target_muscle = '${muscle.name}'",
      );
    }
  }
}

/// Seeds the biceps exercises added in schema version 8.
/// Called from migration onUpgrade when upgrading from v7.
Future<void> seedExercisesV4(AppDatabase db) async {
  final exerciseIds = <String, int>{};

  // Resolve existing exercise IDs for variation linking
  final existingRows = await db.select(db.exercises).get();
  for (final row in existingRows) {
    exerciseIds[row.name] = row.id;
  }

  for (final item in _v4SeedItems) {
    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            movementPattern: Value(item.movementPattern),
            isVerified: const Value(true),
            description: const Value.absent(),
          ),
        );
    exerciseIds[item.name] = id;

    for (final focus in item.muscles) {
      await db.into(db.exerciseTargetMuscles).insert(
            ExerciseTargetMusclesCompanion(
              exerciseId: Value(id),
              targetMuscle: Value(focus.muscle),
              muscleRegion: Value(focus.region),
              role: Value(focus.role),
            ),
          );
    }
  }

  // Add new variations (insertOrIgnore to skip links that already exist)
  for (final link in _v4Variations) {
    final fromId = exerciseIds[link.from];
    final toId = exerciseIds[link.to];
    if (fromId != null && toId != null) {
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(fromId),
              variationId: Value(toId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(toId),
              variationId: Value(fromId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

/// Seeds the hamstrings variation added in schema version 11.
Future<void> seedExercisesV5(AppDatabase db) async {
  final exerciseId = await db.into(db.exercises).insert(
        ExercisesCompanion.insert(
          name: 'seatedLegCurl',
          muscleGroup: MuscleGroup.hamstrings,
          type: const Value(ExerciseType.strength),
          movementPattern: const Value(MovementPattern.isolation),
          isVerified: const Value(true),
          description: const Value.absent(),
        ),
      );

  await db.into(db.exerciseTargetMuscles).insert(
        ExerciseTargetMusclesCompanion(
          exerciseId: Value(exerciseId),
          targetMuscle: const Value(TargetMuscle.bicepsFemoris),
          muscleRegion: const Value(null),
          role: const Value(MuscleRole.primary),
        ),
      );
  await db.into(db.exerciseTargetMuscles).insert(
        ExerciseTargetMusclesCompanion(
          exerciseId: Value(exerciseId),
          targetMuscle: const Value(TargetMuscle.semitendinosus),
          muscleRegion: const Value(null),
          role: const Value(MuscleRole.primary),
        ),
      );
}

final _v4SeedItems = [
  _SeedExercise('inclineCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('concentrationCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('waiterCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('dragCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ]),
  _SeedExercise('spiderCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('cableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ]),
  _SeedExercise('behindBackCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('bayesianCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ]),
  _SeedExercise('preacherHammerCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachialis),
        _p(TargetMuscle.brachioradialis),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('reverseZottmanCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachioradialis),
        _p(TargetMuscle.brachialis),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.wristExtensors),
      ]),
];

const _v4Variations = [
  // ── Biceps — general curls (EZ bar folded into barbell curl) ──
  _Variation('bicepsCurl', 'dragCurl'),
  _Variation('bicepsCurl', 'cableCurl'),
  _Variation('bicepsCurl', 'waiterCurl'),
  _Variation('bicepsCurl', 'alternatingCurl'),
  _Variation('alternatingCurl', 'dragCurl'),
  _Variation('alternatingCurl', 'cableCurl'),
  _Variation('alternatingCurl', 'waiterCurl'),
  _Variation('dragCurl', 'cableCurl'),
  _Variation('dragCurl', 'waiterCurl'),
  _Variation('cableCurl', 'waiterCurl'),
  // ── Biceps — short head ──
  _Variation('preacherCurl', 'concentrationCurl'),
  _Variation('preacherCurl', 'spiderCurl'),
  _Variation('concentrationCurl', 'spiderCurl'),
  // ── Biceps — long head (complete network) ──
  _Variation('inclineCurl', 'behindBackCableCurl'),
  _Variation('inclineCurl', 'bayesianCableCurl'),
  _Variation('behindBackCableCurl', 'bayesianCableCurl'),
  // ── Biceps — hammer / brachialis (complete network) ──
  _Variation('hammerCurl', 'preacherHammerCurl'),
  _Variation('hammerCurl', 'reverseZottmanCurl'),
  _Variation('preacherHammerCurl', 'reverseZottmanCurl'),
  // ── Biceps — cross-cluster bridges ──
  _Variation('alternatingCurl', 'preacherCurl'),
  _Variation('alternatingCurl', 'concentrationCurl'),
  _Variation('alternatingCurl', 'spiderCurl'),
  _Variation('alternatingCurl', 'inclineCurl'),
  _Variation('bicepsCurl', 'inclineCurl'),
  _Variation('bicepsCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'inclineCurl'),
  _Variation('waiterCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'behindBackCableCurl'),
  _Variation('cableCurl', 'behindBackCableCurl'),
  _Variation('cableCurl', 'bayesianCableCurl'),
  // ── Glutes — old↔old missing links ──
  _Variation('hipThrust', 'gluteKickback'),
  _Variation('gluteBridge', 'gluteKickback'),
  // ── Abs — old↔old missing links ──
  _Variation('crunch', 'abWheelRollout'),
  _Variation('hangingLegRaise', 'abWheelRollout'),
  _Variation('plank', 'abWheelRollout'),
];

final _v3SeedItems = [
  _SeedExercise('hipAdduction', MuscleGroup.adductors,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.adductorMagnus),
        _p(TargetMuscle.adductorLongus),
        _p(TargetMuscle.adductorBrevis),
      ]),
  _SeedExercise('hipAbduction', MuscleGroup.glutes,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gluteusMedius),
        _p(TargetMuscle.gluteusMinimus),
        _p(TargetMuscle.tensorFasciaeLatae),
      ]),
];

const _movementPatternBackfill = {
  'benchPress': MovementPattern.push,
  'inclineBenchPress': MovementPattern.push,
  'chestFly': MovementPattern.isolation,
  'pushUp': MovementPattern.push,
  'cableCrossover': MovementPattern.isolation,
  'chestPress': MovementPattern.push,
  'inclineDumbbellPress': MovementPattern.push,
  'declinePushUp': MovementPattern.push,
  'inclinePushUp': MovementPattern.push,
  'kneePushUp': MovementPattern.push,
  'pullUp': MovementPattern.pull,
  'bentOverRow': MovementPattern.pull,
  'latPulldown': MovementPattern.pull,
  'seatedRow': MovementPattern.pull,
  'singleArmRow': MovementPattern.pull,
  'chinUp': MovementPattern.pull,
  'invertedRow': MovementPattern.pull,
  'shrug': MovementPattern.isolation,
  'overheadPress': MovementPattern.push,
  'lateralRaise': MovementPattern.isolation,
  'facePull': MovementPattern.pull,
  'arnoldPress': MovementPattern.push,
  'rearDeltFly': MovementPattern.isolation,
  'pikePushUp': MovementPattern.push,
  'bicepsCurl': MovementPattern.isolation,
  'alternatingCurl': MovementPattern.isolation,
  'hammerCurl': MovementPattern.isolation,
  'preacherCurl': MovementPattern.isolation,
  'tricepsPushdown': MovementPattern.isolation,
  'skullCrusher': MovementPattern.isolation,
  'overheadTricepsExtension': MovementPattern.isolation,
  'diamondPushUp': MovementPattern.push,
  'dip': MovementPattern.push,
  'backSquat': MovementPattern.squat,
  'frontSquat': MovementPattern.squat,
  'gobletSquat': MovementPattern.squat,
  'legPress': MovementPattern.squat,
  'lunge': MovementPattern.lunge,
  'bulgarianSplitSquat': MovementPattern.lunge,
  'legExtension': MovementPattern.isolation,
  'hackSquat': MovementPattern.squat,
  'romanianDeadlift': MovementPattern.hinge,
  'nordicCurl': MovementPattern.isolation,
  'legCurl': MovementPattern.isolation,
  'hipThrust': MovementPattern.hinge,
  'gluteBridge': MovementPattern.hinge,
  'gluteKickback': MovementPattern.isolation,
  'standingCalfRaise': MovementPattern.isolation,
  'seatedCalfRaise': MovementPattern.isolation,
  'crunch': MovementPattern.isolation,
  'hangingLegRaise': MovementPattern.isolation,
  'wristCurl': MovementPattern.isolation,
  'reverseWristCurl': MovementPattern.isolation,
  'deadlift': MovementPattern.hinge,
};

const _secondaryRoleBackfill = {
  'benchPress': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'inclineBenchPress': [TargetMuscle.anteriorDeltoid],
  'pushUp': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'chestPress': [TargetMuscle.tricepsBrachii],
  'inclineDumbbellPress': [TargetMuscle.anteriorDeltoid],
  'declinePushUp': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'kneePushUp': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'pullUp': [TargetMuscle.bicepsBrachii, TargetMuscle.rhomboids],
  'bentOverRow': [TargetMuscle.rearDeltoid, TargetMuscle.bicepsBrachii],
  'latPulldown': [TargetMuscle.bicepsBrachii],
  'seatedRow': [TargetMuscle.rearDeltoid, TargetMuscle.bicepsBrachii],
  'singleArmRow': [TargetMuscle.bicepsBrachii],
  'chinUp': [TargetMuscle.bicepsBrachii, TargetMuscle.rhomboids],
  'invertedRow': [TargetMuscle.rearDeltoid, TargetMuscle.bicepsBrachii],
  'overheadPress': [TargetMuscle.tricepsBrachii],
  'facePull': [TargetMuscle.rhomboids],
  'arnoldPress': [TargetMuscle.tricepsBrachii],
  'pikePushUp': [TargetMuscle.tricepsBrachii],
  'bicepsCurl': [TargetMuscle.brachialis],
  'diamondPushUp': [TargetMuscle.pectoralisMajor],
  'dip': [TargetMuscle.pectoralisMajor, TargetMuscle.anteriorDeltoid],
  'backSquat': [TargetMuscle.gluteusMaximus, TargetMuscle.bicepsFemoris],
  'frontSquat': [TargetMuscle.gluteusMaximus, TargetMuscle.bicepsFemoris],
  'gobletSquat': [TargetMuscle.gluteusMaximus, TargetMuscle.bicepsFemoris],
  'legPress': [TargetMuscle.gluteusMaximus],
  'lunge': [TargetMuscle.gluteusMaximus],
  'bulgarianSplitSquat': [TargetMuscle.gluteusMaximus],
  'hackSquat': [TargetMuscle.gluteusMaximus],
  'romanianDeadlift': [TargetMuscle.gluteusMaximus, TargetMuscle.erectorSpinae],
  'hipThrust': [TargetMuscle.bicepsFemoris],
  'gluteKickback': [TargetMuscle.gluteusMedius],
  'hangingLegRaise': [TargetMuscle.hipFlexors],
  'abWheelRollout': [TargetMuscle.obliques],
  'deadlift': [TargetMuscle.trapezius, TargetMuscle.rectusFemoris],
  'burpee': [TargetMuscle.pectoralisMajor, TargetMuscle.anteriorDeltoid],
  'plank': [TargetMuscle.obliques],
};

/// Seeds the exercises added in schema version 26.
Future<void> seedExercisesV6(AppDatabase db) async {
  final exerciseIds = <String, int>{};

  final existingRows = await db.select(db.exercises).get();
  for (final row in existingRows) {
    exerciseIds[row.name] = row.id;
  }

  for (final item in _v6SeedItems) {
    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            movementPattern: Value(item.movementPattern),
            isVerified: const Value(true),
            isBodyweight: Value(item.isBodyweight),
            description: const Value.absent(),
          ),
        );
    exerciseIds[item.name] = id;

    for (final focus in item.muscles) {
      await db.into(db.exerciseTargetMuscles).insert(
            ExerciseTargetMusclesCompanion(
              exerciseId: Value(id),
              targetMuscle: Value(focus.muscle),
              muscleRegion: Value(focus.region),
              role: Value(focus.role),
            ),
          );
    }
  }

  for (final link in _v6Variations) {
    final fromId = exerciseIds[link.from];
    final toId = exerciseIds[link.to];
    if (fromId != null && toId != null) {
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(fromId),
              variationId: Value(toId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(toId),
              variationId: Value(fromId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

final _v6SeedItems = [
  // ── Back — vertical pull (distinct grip variants, same station type) ──
  _SeedExercise('neutralGripPullUp', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      isBodyweight: true,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
        _s(TargetMuscle.rhomboids),
      ]),
  _SeedExercise('closeGripPulldown', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.rhomboids),
      ]),
  _SeedExercise('neutralGripPulldown', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ]),
  // ── Back — horizontal pull (underhand row) ──
  _SeedExercise('underhandRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.rhomboids),
        _s(TargetMuscle.rearDeltoid),
      ]),
  _SeedExercise('wideGripSeatedRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.rhomboids),
        _p(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  // ── Chest — decline barbell bench press ──
  _SeedExercise('declineBenchPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.lower),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
];

const _v6Variations = [
  // ── Vertical pulls — fixed bar (grip variants kept as distinct exercises) ──
  _Variation('pullUp', 'neutralGripPullUp'),
  _Variation('chinUp', 'neutralGripPullUp'),
  // ── Vertical pulls — pulley (distinct grip variants) ──
  _Variation('latPulldown', 'closeGripPulldown'),
  _Variation('latPulldown', 'neutralGripPulldown'),
  _Variation('closeGripPulldown', 'neutralGripPulldown'),
  _Variation('chinUp', 'closeGripPulldown'),
  _Variation('neutralGripPullUp', 'neutralGripPulldown'),
  _Variation('pullUp', 'closeGripPulldown'),
  _Variation('pullUp', 'neutralGripPulldown'),
  _Variation('chinUp', 'neutralGripPulldown'),
  _Variation('neutralGripPullUp', 'latPulldown'),
  _Variation('neutralGripPullUp', 'closeGripPulldown'),
  // ── Horizontal pulls — rows ──
  _Variation('bentOverRow', 'underhandRow'),
  _Variation('underhandRow', 'singleArmRow'),
  _Variation('underhandRow', 'seatedRow'),
  _Variation('underhandRow', 'invertedRow'),
  _Variation('seatedRow', 'wideGripSeatedRow'),
  _Variation('bentOverRow', 'wideGripSeatedRow'),
  _Variation('wideGripSeatedRow', 'invertedRow'),
  _Variation('wideGripSeatedRow', 'singleArmRow'),
  // ── Chest — decline bench press ──
  _Variation('declineBenchPress', 'benchPress'),
  _Variation('declineBenchPress', 'inclineBenchPress'),
  _Variation('declineBenchPress', 'chestPress'),
];

const _variations = [
  // ── Chest — mid pressing (pec major mid) ──
  _Variation('benchPress', 'chestPress'),
  _Variation('benchPress', 'pushUp'),
  _Variation('benchPress', 'kneePushUp'),
  _Variation('chestPress', 'pushUp'),
  _Variation('chestPress', 'kneePushUp'),
  _Variation('pushUp', 'kneePushUp'),
  // ── Chest — upper pressing (pec major upper) ──
  _Variation('inclineBenchPress', 'inclineDumbbellPress'),
  _Variation('inclineBenchPress', 'declinePushUp'),
  _Variation('inclineDumbbellPress', 'declinePushUp'),
  // ── Chest — fly / isolation (pec major mid) ──
  _Variation('chestFly', 'cableCrossover'),
  // ── Back — vertical pull (lats + biceps) ──
  _Variation('pullUp', 'latPulldown'),
  _Variation('pullUp', 'chinUp'),
  _Variation('chinUp', 'latPulldown'),
  // ── Back — horizontal pull / rows (lats + rhomboids) ──
  _Variation('bentOverRow', 'singleArmRow'),
  _Variation('bentOverRow', 'seatedRow'),
  _Variation('bentOverRow', 'invertedRow'),
  _Variation('singleArmRow', 'seatedRow'),
  _Variation('singleArmRow', 'invertedRow'),
  _Variation('seatedRow', 'invertedRow'),
  // ── Shoulders — vertical push (anterior + lateral deltoid) ──
  _Variation('overheadPress', 'arnoldPress'),
  _Variation('overheadPress', 'pikePushUp'),
  _Variation('arnoldPress', 'pikePushUp'),
  // ── Shoulders — rear delt ──
  _Variation('facePull', 'rearDeltFly'),
  // ── Biceps — general curls (EZ bar folded into barbell curl) ──
  _Variation('bicepsCurl', 'alternatingCurl'),
  _Variation('bicepsCurl', 'dragCurl'),
  _Variation('bicepsCurl', 'cableCurl'),
  _Variation('bicepsCurl', 'waiterCurl'),
  _Variation('alternatingCurl', 'dragCurl'),
  _Variation('alternatingCurl', 'cableCurl'),
  _Variation('alternatingCurl', 'waiterCurl'),
  _Variation('dragCurl', 'cableCurl'),
  _Variation('dragCurl', 'waiterCurl'),
  _Variation('cableCurl', 'waiterCurl'),
  // ── Biceps — short head emphasis ──
  _Variation('preacherCurl', 'concentrationCurl'),
  _Variation('preacherCurl', 'spiderCurl'),
  _Variation('concentrationCurl', 'spiderCurl'),
  // ── Biceps — long head emphasis (complete network) ──
  _Variation('inclineCurl', 'behindBackCableCurl'),
  _Variation('inclineCurl', 'bayesianCableCurl'),
  _Variation('behindBackCableCurl', 'bayesianCableCurl'),
  // ── Biceps — hammer / brachialis (complete network) ──
  _Variation('hammerCurl', 'preacherHammerCurl'),
  _Variation('hammerCurl', 'reverseZottmanCurl'),
  _Variation('preacherHammerCurl', 'reverseZottmanCurl'),
  // ── Biceps — cross-cluster bridges ──
  _Variation('alternatingCurl', 'preacherCurl'),
  _Variation('alternatingCurl', 'concentrationCurl'),
  _Variation('alternatingCurl', 'spiderCurl'),
  _Variation('alternatingCurl', 'inclineCurl'),
  _Variation('bicepsCurl', 'inclineCurl'),
  _Variation('bicepsCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'inclineCurl'),
  _Variation('waiterCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'behindBackCableCurl'),
  _Variation('cableCurl', 'behindBackCableCurl'),
  _Variation('cableCurl', 'bayesianCableCurl'),
  // ── Triceps — compound push (triceps + pec) ──
  _Variation('diamondPushUp', 'dip'),
  _Variation('diamondPushUp', 'tricepsPushdown'),
  _Variation('dip', 'tricepsPushdown'),
  // ── Triceps — long head isolation ──
  _Variation('skullCrusher', 'overheadTricepsExtension'),
  // ── Quadriceps — squat pattern ──
  _Variation('backSquat', 'legPress'),
  _Variation('backSquat', 'hackSquat'),
  _Variation('backSquat', 'frontSquat'),
  _Variation('backSquat', 'gobletSquat'),
  _Variation('frontSquat', 'gobletSquat'),
  _Variation('frontSquat', 'legPress'),
  _Variation('frontSquat', 'hackSquat'),
  _Variation('gobletSquat', 'legPress'),
  _Variation('gobletSquat', 'hackSquat'),
  _Variation('legPress', 'hackSquat'),
  // ── Quadriceps — lunge pattern ──
  _Variation('lunge', 'bulgarianSplitSquat'),
  // ── Hamstrings (biceps femoris + semitendinosus) ──
  _Variation('romanianDeadlift', 'nordicCurl'),
  _Variation('romanianDeadlift', 'legCurl'),
  _Variation('nordicCurl', 'legCurl'),
  // ── Glutes (gluteus maximus) ──
  _Variation('hipThrust', 'gluteBridge'),
  _Variation('hipThrust', 'gluteKickback'),
  _Variation('gluteBridge', 'gluteKickback'),
  // ── Abs (rectus abdominis) ──
  _Variation('crunch', 'hangingLegRaise'),
  _Variation('crunch', 'abWheelRollout'),
  _Variation('hangingLegRaise', 'abWheelRollout'),
  _Variation('plank', 'abWheelRollout'),
  // ── Abs — isometric (core holds) ──
  _Variation('plank', 'sidePlank'),
  _Variation('plank', 'hollowHold'),
  _Variation('sidePlank', 'hollowHold'),
  _Variation('hollowHold', 'lSit'),
  // ── Back — isometric (dead hang) ──
  _Variation('deadHang', 'pullUp'),
  _Variation('deadHang', 'chinUp'),

  // ── V6 additions ──
  ..._v6Variations,
];

/// Seeds the isometric exercises added in schema version 28.
/// Called from migration onUpgrade when upgrading from < 28.
Future<void> seedExercisesV7(AppDatabase db) async {
  final exerciseIds = <String, int>{};

  final existingRows = await db.select(db.exercises).get();
  for (final row in existingRows) {
    exerciseIds[row.name] = row.id;
  }

  for (final item in _v7SeedItems) {
    if (exerciseIds.containsKey(item.name)) continue;

    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            movementPattern: Value(item.movementPattern),
            isVerified: const Value(true),
            isBodyweight: Value(item.isBodyweight),
            isIsometric: Value(item.isIsometric),
            description: const Value.absent(),
          ),
        );
    exerciseIds[item.name] = id;

    for (final focus in item.muscles) {
      await db.into(db.exerciseTargetMuscles).insert(
            ExerciseTargetMusclesCompanion(
              exerciseId: Value(id),
              targetMuscle: Value(focus.muscle),
              muscleRegion: Value(focus.region),
              role: Value(focus.role),
            ),
          );
    }
  }

  for (final link in _v7Variations) {
    final fromId = exerciseIds[link.from];
    final toId = exerciseIds[link.to];
    if (fromId != null && toId != null) {
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(fromId),
              variationId: Value(toId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(toId),
              variationId: Value(fromId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

final _v7SeedItems = [
  _SeedExercise('sidePlank', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.obliques),
    _s(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.gluteusMedius),
  ]),
  _SeedExercise('hollowHold', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusAbdominis),
    _p(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.hipFlexors),
  ]),
  _SeedExercise('lSit', MuscleGroup.abs,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusAbdominis),
    _p(TargetMuscle.hipFlexors),
    _s(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.tricepsBrachii),
  ]),
  _SeedExercise('wallSit', MuscleGroup.quadriceps,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.rectusFemoris),
    _p(TargetMuscle.vastusLateralis),
    _p(TargetMuscle.vastusMedialis),
    _s(TargetMuscle.gluteusMaximus),
  ]),
  _SeedExercise('deadHang', MuscleGroup.back,
      isBodyweight: true, isIsometric: true, muscles: [
    _p(TargetMuscle.latissimusDorsi),
    _p(TargetMuscle.wristFlexors),
    _s(TargetMuscle.trapezius),
    _s(TargetMuscle.rhomboids),
  ]),
];

const _v7Variations = [
  _Variation('plank', 'sidePlank'),
  _Variation('plank', 'hollowHold'),
  _Variation('sidePlank', 'hollowHold'),
  _Variation('hollowHold', 'lSit'),
  _Variation('deadHang', 'pullUp'),
  _Variation('deadHang', 'chinUp'),
];

/// Seeds [frontSquat] and [gobletSquat] (schema version 31).
Future<void> seedExercisesV8(AppDatabase db) async {
  final exerciseIds = <String, int>{};

  final existingRows = await db.select(db.exercises).get();
  for (final row in existingRows) {
    exerciseIds[row.name] = row.id;
  }

  for (final item in _v8SeedItems) {
    if (exerciseIds.containsKey(item.name)) continue;

    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            movementPattern: Value(item.movementPattern),
            isVerified: const Value(true),
            isBodyweight: Value(item.isBodyweight),
            isIsometric: Value(item.isIsometric),
            description: const Value.absent(),
          ),
        );
    exerciseIds[item.name] = id;

    for (final focus in item.muscles) {
      await db.into(db.exerciseTargetMuscles).insert(
            ExerciseTargetMusclesCompanion(
              exerciseId: Value(id),
              targetMuscle: Value(focus.muscle),
              muscleRegion: Value(focus.region),
              role: Value(focus.role),
            ),
          );
    }
  }

  for (final link in _v8Variations) {
    final fromId = exerciseIds[link.from];
    final toId = exerciseIds[link.to];
    if (fromId != null && toId != null) {
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(fromId),
              variationId: Value(toId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db.into(db.exerciseVariations).insert(
            ExerciseVariationsCompanion(
              exerciseId: Value(toId),
              variationId: Value(fromId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}

final _v8SeedItems = [
  _SeedExercise('frontSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ]),
  _SeedExercise('gobletSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ]),
];

const _v8Variations = [
  _Variation('backSquat', 'frontSquat'),
  _Variation('backSquat', 'gobletSquat'),
  _Variation('frontSquat', 'gobletSquat'),
  _Variation('frontSquat', 'legPress'),
  _Variation('frontSquat', 'hackSquat'),
  _Variation('gobletSquat', 'legPress'),
  _Variation('gobletSquat', 'hackSquat'),
];
