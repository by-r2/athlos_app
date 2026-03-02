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
/// Equipment and variation relations are resolved by name against seeded data.
Future<void> seedExercises(AppDatabase db) async {
  final equipmentIds = await _resolveEquipmentIds(db);

  final exerciseIds = <String, int>{};

  for (final item in _seedItems) {
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

    for (final eqName in item.equipmentKeys) {
      final eqId = equipmentIds[eqName];
      if (eqId != null) {
        await db.into(db.exerciseEquipments).insert(
              ExerciseEquipmentsCompanion(
                exerciseId: Value(id),
                equipmentId: Value(eqId),
              ),
            );
      }
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

Future<Map<String, int>> _resolveEquipmentIds(AppDatabase db) async {
  final rows = await db.select(db.equipments).get();
  return {for (final r in rows) r.name: r.id};
}

class _SeedExercise {
  final String name;
  final MuscleGroup muscleGroup;
  final ExerciseType type;
  final MovementPattern? movementPattern;
  final List<_MF> muscles;
  final List<String> equipmentKeys;

  const _SeedExercise(
    this.name,
    this.muscleGroup, {
    this.type = ExerciseType.strength,
    this.movementPattern,
    this.muscles = const [],
    this.equipmentKeys = const [],
  });
}

class _Variation {
  final String from;
  final String to;
  const _Variation(this.from, this.to);
}

final _seedItems = [
  // ── Chest ──
  _SeedExercise('flatBarbellBenchPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ],
      equipmentKeys: ['barbell', 'flatBench']),
  _SeedExercise('inclineBarbellBenchPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.upper),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ],
      equipmentKeys: ['barbell', 'adjustableBench']),
  _SeedExercise('dumbbellFly', MuscleGroup.chest,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
      ],
      equipmentKeys: ['dumbbell', 'flatBench']),
  _SeedExercise('pushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('cableCrossover', MuscleGroup.chest,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('machineChestPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.tricepsBrachii),
      ],
      equipmentKeys: ['chestPressMachine']),
  _SeedExercise('inclineDumbbellPress', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.upper),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ],
      equipmentKeys: ['dumbbell', 'adjustableBench']),
  _SeedExercise('declinePushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.upper),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),
  _SeedExercise('inclinePushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.lower),
      ]),
  _SeedExercise('kneePushUp', MuscleGroup.chest,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.pectoralisMajor, MuscleRegion.mid),
        _s(TargetMuscle.anteriorDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),

  // ── Back ──
  _SeedExercise('pullUp', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.rhomboids),
      ],
      equipmentKeys: ['pullUpBar']),
  _SeedExercise('barbellRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _p(TargetMuscle.rhomboids),
        _s(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('latPulldown', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['latPulldownMachine']),
  _SeedExercise('seatedCableRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.rhomboids),
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('dumbbellRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _p(TargetMuscle.rhomboids),
        _s(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['dumbbell', 'flatBench']),
  _SeedExercise('chinUp', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.rhomboids),
      ],
      equipmentKeys: ['pullUpBar']),
  _SeedExercise('invertedRow', MuscleGroup.back,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.rhomboids),
        _p(TargetMuscle.latissimusDorsi),
        _s(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.bicepsBrachii),
      ]),
  _SeedExercise('dumbbellShrug', MuscleGroup.back,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.trapezius),
      ],
      equipmentKeys: ['dumbbell']),

  // ── Shoulders ──
  _SeedExercise('overheadPress', MuscleGroup.shoulders,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.anteriorDeltoid),
        _p(TargetMuscle.lateralDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('lateralRaise', MuscleGroup.shoulders,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.lateralDeltoid),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('facePull', MuscleGroup.shoulders,
      movementPattern: MovementPattern.pull,
      muscles: [
        _p(TargetMuscle.rearDeltoid),
        _s(TargetMuscle.rhomboids),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('arnoldPress', MuscleGroup.shoulders,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.anteriorDeltoid),
        _p(TargetMuscle.lateralDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('rearDeltFly', MuscleGroup.shoulders,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rearDeltoid),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('pikePushUp', MuscleGroup.shoulders,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.anteriorDeltoid),
        _p(TargetMuscle.lateralDeltoid),
        _s(TargetMuscle.tricepsBrachii),
      ]),

  // ── Biceps ──
  _SeedExercise('barbellCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('ezBarCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['ezBar']),
  _SeedExercise('dumbbellCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('dumbbellPreacherCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell', 'preacherBench']),
  _SeedExercise('inclineDumbbellCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell', 'adjustableBench']),
  _SeedExercise('concentrationCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('machinePreacherCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['bicepsCurlMachine']),
  _SeedExercise('waiterCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['weightPlates']),
  _SeedExercise('dragCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('spiderCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell', 'adjustableBench']),
  _SeedExercise('cableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('behindBackCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('bayesianCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('hammerCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachialis),
        _p(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('preacherCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
      ],
      equipmentKeys: ['ezBar', 'preacherBench']),
  _SeedExercise('preacherHammerCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachialis),
        _p(TargetMuscle.brachioradialis),
        _s(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['dumbbell', 'preacherBench']),
  _SeedExercise('reverseZottmanCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachioradialis),
        _p(TargetMuscle.brachialis),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.wristExtensors),
      ],
      equipmentKeys: ['dumbbell']),

  // ── Triceps ──
  _SeedExercise('tricepsPushdown', MuscleGroup.triceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.tricepsBrachii, MuscleRegion.lateralHead),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('skullCrusher', MuscleGroup.triceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.tricepsBrachii, MuscleRegion.longHead),
      ],
      equipmentKeys: ['ezBar', 'flatBench']),
  _SeedExercise('overheadTricepsExtension', MuscleGroup.triceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.tricepsBrachii, MuscleRegion.longHead),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('diamondPushUp', MuscleGroup.triceps,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.tricepsBrachii),
        _s(TargetMuscle.pectoralisMajor),
      ]),
  _SeedExercise('dip', MuscleGroup.triceps,
      movementPattern: MovementPattern.push,
      muscles: [
        _p(TargetMuscle.tricepsBrachii),
        _s(TargetMuscle.pectoralisMajor),
        _s(TargetMuscle.anteriorDeltoid),
      ],
      equipmentKeys: ['dipStation']),

  // ── Quadriceps ──
  _SeedExercise('barbellSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ],
      equipmentKeys: ['barbell', 'squatRack']),
  _SeedExercise('legPress', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ],
      equipmentKeys: ['legPressMachine']),
  _SeedExercise('lunge', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.lunge,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('bulgarianSplitSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.lunge,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ],
      equipmentKeys: ['dumbbell', 'flatBench']),
  _SeedExercise('legExtension', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _p(TargetMuscle.vastusMedialis),
      ],
      equipmentKeys: ['legExtensionMachine']),
  _SeedExercise('hackSquat', MuscleGroup.quadriceps,
      movementPattern: MovementPattern.squat,
      muscles: [
        _p(TargetMuscle.rectusFemoris),
        _p(TargetMuscle.vastusLateralis),
        _s(TargetMuscle.gluteusMaximus),
      ],
      equipmentKeys: ['hackSquatMachine']),

  // ── Hamstrings ──
  _SeedExercise('romanianDeadlift', MuscleGroup.hamstrings,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.semitendinosus),
        _s(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.erectorSpinae),
      ],
      equipmentKeys: ['barbell']),
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
      ],
      equipmentKeys: ['legCurlMachine']),

  // ── Glutes ──
  _SeedExercise('hipThrust', MuscleGroup.glutes,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.bicepsFemoris),
      ],
      equipmentKeys: ['barbell', 'flatBench']),
  _SeedExercise('gluteBridge', MuscleGroup.glutes,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.gluteusMaximus),
      ]),
  _SeedExercise('cableKickback', MuscleGroup.glutes,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gluteusMaximus),
        _s(TargetMuscle.gluteusMedius),
      ],
      equipmentKeys: ['cableMachine']),

  // ── Adductors ──
  _SeedExercise('adductorMachine', MuscleGroup.adductors,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.adductorMagnus),
        _p(TargetMuscle.adductorLongus),
        _p(TargetMuscle.adductorBrevis),
      ],
      equipmentKeys: ['adductorMachine']),
  _SeedExercise('abductorMachine', MuscleGroup.glutes,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gluteusMedius),
        _p(TargetMuscle.gluteusMinimus),
        _p(TargetMuscle.tensorFasciaeLatae),
      ],
      equipmentKeys: ['abductorMachine']),

  // ── Calves ──
  _SeedExercise('standingCalfRaise', MuscleGroup.calves,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gastrocnemius),
      ],
      equipmentKeys: ['smithMachine']),
  _SeedExercise('seatedCalfRaise', MuscleGroup.calves,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.soleus),
      ]),

  // ── Abs ──
  _SeedExercise('crunch', MuscleGroup.abs,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rectusAbdominis, MuscleRegion.upper),
      ]),
  _SeedExercise('plank', MuscleGroup.abs, muscles: [
    _p(TargetMuscle.rectusAbdominis),
    _p(TargetMuscle.transverseAbdominis),
    _s(TargetMuscle.obliques),
  ]),
  _SeedExercise('hangingLegRaise', MuscleGroup.abs,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.rectusAbdominis, MuscleRegion.lower),
        _s(TargetMuscle.hipFlexors),
      ],
      equipmentKeys: ['pullUpBar']),
  _SeedExercise('abWheelRollout', MuscleGroup.abs,
      muscles: [
        _p(TargetMuscle.rectusAbdominis),
        _s(TargetMuscle.obliques),
      ],
      equipmentKeys: ['abWheel']),

  // ── Forearms ──
  _SeedExercise('wristCurl', MuscleGroup.forearms,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.wristFlexors),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('reverseWristCurl', MuscleGroup.forearms,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.wristExtensors),
      ],
      equipmentKeys: ['barbell']),

  // ── Full Body ──
  _SeedExercise('deadlift', MuscleGroup.fullBody,
      movementPattern: MovementPattern.hinge,
      muscles: [
        _p(TargetMuscle.bicepsFemoris),
        _p(TargetMuscle.gluteusMaximus),
        _p(TargetMuscle.erectorSpinae),
        _s(TargetMuscle.trapezius),
        _s(TargetMuscle.rectusFemoris),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('burpee', MuscleGroup.fullBody, muscles: [
    _p(TargetMuscle.rectusFemoris),
    _s(TargetMuscle.pectoralisMajor),
    _s(TargetMuscle.anteriorDeltoid),
  ]),

  // ── Cardio ──
  _SeedExercise('treadmillRun', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['treadmill']),
  _SeedExercise('stationaryBike', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['stationaryBike']),
  _SeedExercise('rowingMachine', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['rowingMachine']),
  _SeedExercise('elliptical', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['elliptical']),
  _SeedExercise('jumpRope', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['jumpRope']),
  _SeedExercise('jumpingJacks', MuscleGroup.cardio,
      type: ExerciseType.cardio),
];

/// Seeds only the cardio exercises added in schema version 2.
/// Called from migration onUpgrade when upgrading from v1.
Future<void> seedExercisesV2(AppDatabase db) async {
  final equipmentIds = await _resolveEquipmentIds(db);

  for (final item in _cardioSeedItems) {
    final id = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: item.name,
            muscleGroup: item.muscleGroup,
            type: Value(item.type),
            isVerified: const Value(true),
            description: const Value.absent(),
          ),
        );

    for (final eqName in item.equipmentKeys) {
      final eqId = equipmentIds[eqName];
      if (eqId != null) {
        await db.into(db.exerciseEquipments).insert(
              ExerciseEquipmentsCompanion(
                exerciseId: Value(id),
                equipmentId: Value(eqId),
              ),
            );
      }
    }
  }
}

const _cardioSeedItems = [
  _SeedExercise('treadmillRun', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['treadmill']),
  _SeedExercise('stationaryBike', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['stationaryBike']),
  _SeedExercise('rowingMachine', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['rowingMachine']),
  _SeedExercise('elliptical', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['elliptical']),
  _SeedExercise('jumpRope', MuscleGroup.cardio,
      type: ExerciseType.cardio, equipmentKeys: ['jumpRope']),
  _SeedExercise('jumpingJacks', MuscleGroup.cardio,
      type: ExerciseType.cardio),
];

/// Seeds adductor/abductor exercises added in schema version 3.
/// Also updates movement_pattern for existing exercises.
Future<void> seedExercisesV3(AppDatabase db) async {
  final equipmentIds = await _resolveEquipmentIds(db);

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

    for (final eqName in item.equipmentKeys) {
      final eqId = equipmentIds[eqName];
      if (eqId != null) {
        await db.into(db.exerciseEquipments).insert(
              ExerciseEquipmentsCompanion(
                exerciseId: Value(id),
                equipmentId: Value(eqId),
              ),
            );
      }
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
  final equipmentIds = await _resolveEquipmentIds(db);
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

    for (final eqName in item.equipmentKeys) {
      final eqId = equipmentIds[eqName];
      if (eqId != null) {
        await db.into(db.exerciseEquipments).insert(
              ExerciseEquipmentsCompanion(
                exerciseId: Value(id),
                equipmentId: Value(eqId),
              ),
            );
      }
    }
  }

  // Update preacherCurl to also link to preacherBench
  final preacherBenchId = equipmentIds['preacherBench'];
  final preacherCurlId = exerciseIds['preacherCurl'];
  if (preacherBenchId != null && preacherCurlId != null) {
    await db.into(db.exerciseEquipments).insertOnConflictUpdate(
          ExerciseEquipmentsCompanion(
            exerciseId: Value(preacherCurlId),
            equipmentId: Value(preacherBenchId),
          ),
        );
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

final _v4SeedItems = [
  _SeedExercise('ezBarCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['ezBar']),
  _SeedExercise('dumbbellPreacherCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell', 'preacherBench']),
  _SeedExercise('inclineDumbbellCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell', 'adjustableBench']),
  _SeedExercise('concentrationCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell']),
  _SeedExercise('machinePreacherCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['bicepsCurlMachine']),
  _SeedExercise('waiterCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['weightPlates']),
  _SeedExercise('dragCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['barbell']),
  _SeedExercise('spiderCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.shortHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['dumbbell', 'adjustableBench']),
  _SeedExercise('cableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.brachialis),
        _s(TargetMuscle.brachioradialis),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('behindBackCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('bayesianCableCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.bicepsBrachii, MuscleRegion.longHead),
        _s(TargetMuscle.brachialis),
      ],
      equipmentKeys: ['cableMachine']),
  _SeedExercise('preacherHammerCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachialis),
        _p(TargetMuscle.brachioradialis),
        _s(TargetMuscle.bicepsBrachii),
      ],
      equipmentKeys: ['dumbbell', 'preacherBench']),
  _SeedExercise('reverseZottmanCurl', MuscleGroup.biceps,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.brachioradialis),
        _p(TargetMuscle.brachialis),
        _s(TargetMuscle.bicepsBrachii),
        _s(TargetMuscle.wristExtensors),
      ],
      equipmentKeys: ['dumbbell']),
];

const _v4Variations = [
  // ── Biceps — general curls (new intra-cluster links) ──
  _Variation('barbellCurl', 'ezBarCurl'),
  _Variation('barbellCurl', 'dragCurl'),
  _Variation('barbellCurl', 'cableCurl'),
  _Variation('barbellCurl', 'waiterCurl'),
  _Variation('ezBarCurl', 'dumbbellCurl'),
  _Variation('ezBarCurl', 'dragCurl'),
  _Variation('ezBarCurl', 'cableCurl'),
  _Variation('ezBarCurl', 'waiterCurl'),
  _Variation('dumbbellCurl', 'dragCurl'),
  _Variation('dumbbellCurl', 'cableCurl'),
  _Variation('dumbbellCurl', 'waiterCurl'),
  _Variation('dragCurl', 'cableCurl'),
  _Variation('dragCurl', 'waiterCurl'),
  _Variation('cableCurl', 'waiterCurl'),
  // ── Biceps — short head (complete network) ──
  _Variation('preacherCurl', 'dumbbellPreacherCurl'),
  _Variation('preacherCurl', 'machinePreacherCurl'),
  _Variation('preacherCurl', 'concentrationCurl'),
  _Variation('preacherCurl', 'spiderCurl'),
  _Variation('dumbbellPreacherCurl', 'machinePreacherCurl'),
  _Variation('dumbbellPreacherCurl', 'concentrationCurl'),
  _Variation('dumbbellPreacherCurl', 'spiderCurl'),
  _Variation('machinePreacherCurl', 'concentrationCurl'),
  _Variation('machinePreacherCurl', 'spiderCurl'),
  _Variation('concentrationCurl', 'spiderCurl'),
  // ── Biceps — long head (complete network) ──
  _Variation('inclineDumbbellCurl', 'behindBackCableCurl'),
  _Variation('inclineDumbbellCurl', 'bayesianCableCurl'),
  _Variation('behindBackCableCurl', 'bayesianCableCurl'),
  // ── Biceps — hammer / brachialis (complete network) ──
  _Variation('hammerCurl', 'preacherHammerCurl'),
  _Variation('hammerCurl', 'reverseZottmanCurl'),
  _Variation('preacherHammerCurl', 'reverseZottmanCurl'),
  // ── Biceps — cross-cluster bridges ──
  _Variation('dumbbellCurl', 'preacherCurl'),
  _Variation('dumbbellCurl', 'concentrationCurl'),
  _Variation('dumbbellCurl', 'spiderCurl'),
  _Variation('dumbbellCurl', 'inclineDumbbellCurl'),
  _Variation('barbellCurl', 'inclineDumbbellCurl'),
  _Variation('barbellCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'inclineDumbbellCurl'),
  _Variation('waiterCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'behindBackCableCurl'),
  _Variation('cableCurl', 'behindBackCableCurl'),
  _Variation('cableCurl', 'bayesianCableCurl'),
  // ── Glutes — old↔old missing links ──
  _Variation('hipThrust', 'cableKickback'),
  _Variation('gluteBridge', 'cableKickback'),
  // ── Abs — old↔old missing links ──
  _Variation('crunch', 'abWheelRollout'),
  _Variation('hangingLegRaise', 'abWheelRollout'),
  _Variation('plank', 'abWheelRollout'),
];

final _v3SeedItems = [
  _SeedExercise('adductorMachine', MuscleGroup.adductors,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.adductorMagnus),
        _p(TargetMuscle.adductorLongus),
        _p(TargetMuscle.adductorBrevis),
      ],
      equipmentKeys: ['adductorMachine']),
  _SeedExercise('abductorMachine', MuscleGroup.glutes,
      movementPattern: MovementPattern.isolation,
      muscles: [
        _p(TargetMuscle.gluteusMedius),
        _p(TargetMuscle.gluteusMinimus),
        _p(TargetMuscle.tensorFasciaeLatae),
      ],
      equipmentKeys: ['abductorMachine']),
];

const _movementPatternBackfill = {
  'flatBarbellBenchPress': MovementPattern.push,
  'inclineBarbellBenchPress': MovementPattern.push,
  'dumbbellFly': MovementPattern.isolation,
  'pushUp': MovementPattern.push,
  'cableCrossover': MovementPattern.isolation,
  'machineChestPress': MovementPattern.push,
  'inclineDumbbellPress': MovementPattern.push,
  'declinePushUp': MovementPattern.push,
  'inclinePushUp': MovementPattern.push,
  'kneePushUp': MovementPattern.push,
  'pullUp': MovementPattern.pull,
  'barbellRow': MovementPattern.pull,
  'latPulldown': MovementPattern.pull,
  'seatedCableRow': MovementPattern.pull,
  'dumbbellRow': MovementPattern.pull,
  'chinUp': MovementPattern.pull,
  'invertedRow': MovementPattern.pull,
  'dumbbellShrug': MovementPattern.isolation,
  'overheadPress': MovementPattern.push,
  'lateralRaise': MovementPattern.isolation,
  'facePull': MovementPattern.pull,
  'arnoldPress': MovementPattern.push,
  'rearDeltFly': MovementPattern.isolation,
  'pikePushUp': MovementPattern.push,
  'barbellCurl': MovementPattern.isolation,
  'dumbbellCurl': MovementPattern.isolation,
  'hammerCurl': MovementPattern.isolation,
  'preacherCurl': MovementPattern.isolation,
  'tricepsPushdown': MovementPattern.isolation,
  'skullCrusher': MovementPattern.isolation,
  'overheadTricepsExtension': MovementPattern.isolation,
  'diamondPushUp': MovementPattern.push,
  'dip': MovementPattern.push,
  'barbellSquat': MovementPattern.squat,
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
  'cableKickback': MovementPattern.isolation,
  'standingCalfRaise': MovementPattern.isolation,
  'seatedCalfRaise': MovementPattern.isolation,
  'crunch': MovementPattern.isolation,
  'hangingLegRaise': MovementPattern.isolation,
  'wristCurl': MovementPattern.isolation,
  'reverseWristCurl': MovementPattern.isolation,
  'deadlift': MovementPattern.hinge,
};

const _secondaryRoleBackfill = {
  'flatBarbellBenchPress': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'inclineBarbellBenchPress': [TargetMuscle.anteriorDeltoid],
  'pushUp': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'machineChestPress': [TargetMuscle.tricepsBrachii],
  'inclineDumbbellPress': [TargetMuscle.anteriorDeltoid],
  'declinePushUp': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'kneePushUp': [TargetMuscle.anteriorDeltoid, TargetMuscle.tricepsBrachii],
  'pullUp': [TargetMuscle.bicepsBrachii, TargetMuscle.rhomboids],
  'barbellRow': [TargetMuscle.rearDeltoid, TargetMuscle.bicepsBrachii],
  'latPulldown': [TargetMuscle.bicepsBrachii],
  'seatedCableRow': [TargetMuscle.rearDeltoid, TargetMuscle.bicepsBrachii],
  'dumbbellRow': [TargetMuscle.bicepsBrachii],
  'chinUp': [TargetMuscle.bicepsBrachii, TargetMuscle.rhomboids],
  'invertedRow': [TargetMuscle.rearDeltoid, TargetMuscle.bicepsBrachii],
  'overheadPress': [TargetMuscle.tricepsBrachii],
  'facePull': [TargetMuscle.rhomboids],
  'arnoldPress': [TargetMuscle.tricepsBrachii],
  'pikePushUp': [TargetMuscle.tricepsBrachii],
  'barbellCurl': [TargetMuscle.brachialis],
  'diamondPushUp': [TargetMuscle.pectoralisMajor],
  'dip': [TargetMuscle.pectoralisMajor, TargetMuscle.anteriorDeltoid],
  'barbellSquat': [TargetMuscle.gluteusMaximus, TargetMuscle.bicepsFemoris],
  'legPress': [TargetMuscle.gluteusMaximus],
  'lunge': [TargetMuscle.gluteusMaximus],
  'bulgarianSplitSquat': [TargetMuscle.gluteusMaximus],
  'hackSquat': [TargetMuscle.gluteusMaximus],
  'romanianDeadlift': [TargetMuscle.gluteusMaximus, TargetMuscle.erectorSpinae],
  'hipThrust': [TargetMuscle.bicepsFemoris],
  'cableKickback': [TargetMuscle.gluteusMedius],
  'hangingLegRaise': [TargetMuscle.hipFlexors],
  'abWheelRollout': [TargetMuscle.obliques],
  'deadlift': [TargetMuscle.trapezius, TargetMuscle.rectusFemoris],
  'burpee': [TargetMuscle.pectoralisMajor, TargetMuscle.anteriorDeltoid],
  'plank': [TargetMuscle.obliques],
};

const _variations = [
  // ── Chest — mid pressing (pec major mid) ──
  _Variation('flatBarbellBenchPress', 'machineChestPress'),
  _Variation('flatBarbellBenchPress', 'pushUp'),
  _Variation('flatBarbellBenchPress', 'kneePushUp'),
  _Variation('machineChestPress', 'pushUp'),
  _Variation('machineChestPress', 'kneePushUp'),
  _Variation('pushUp', 'kneePushUp'),
  // ── Chest — upper pressing (pec major upper) ──
  _Variation('inclineBarbellBenchPress', 'inclineDumbbellPress'),
  _Variation('inclineBarbellBenchPress', 'declinePushUp'),
  _Variation('inclineDumbbellPress', 'declinePushUp'),
  // ── Chest — fly / isolation (pec major mid) ──
  _Variation('dumbbellFly', 'cableCrossover'),
  // ── Back — vertical pull (lats + biceps) ──
  _Variation('pullUp', 'latPulldown'),
  _Variation('pullUp', 'chinUp'),
  _Variation('chinUp', 'latPulldown'),
  // ── Back — horizontal pull / rows (lats + rhomboids) ──
  _Variation('barbellRow', 'dumbbellRow'),
  _Variation('barbellRow', 'seatedCableRow'),
  _Variation('barbellRow', 'invertedRow'),
  _Variation('dumbbellRow', 'seatedCableRow'),
  _Variation('dumbbellRow', 'invertedRow'),
  _Variation('seatedCableRow', 'invertedRow'),
  // ── Shoulders — vertical push (anterior + lateral deltoid) ──
  _Variation('overheadPress', 'arnoldPress'),
  _Variation('overheadPress', 'pikePushUp'),
  _Variation('arnoldPress', 'pikePushUp'),
  // ── Shoulders — rear delt ──
  _Variation('facePull', 'rearDeltFly'),
  // ── Biceps — general curls (bicepsBrachii, full activation) ──
  _Variation('barbellCurl', 'ezBarCurl'),
  _Variation('barbellCurl', 'dumbbellCurl'),
  _Variation('barbellCurl', 'dragCurl'),
  _Variation('barbellCurl', 'cableCurl'),
  _Variation('barbellCurl', 'waiterCurl'),
  _Variation('ezBarCurl', 'dumbbellCurl'),
  _Variation('ezBarCurl', 'dragCurl'),
  _Variation('ezBarCurl', 'cableCurl'),
  _Variation('ezBarCurl', 'waiterCurl'),
  _Variation('dumbbellCurl', 'dragCurl'),
  _Variation('dumbbellCurl', 'cableCurl'),
  _Variation('dumbbellCurl', 'waiterCurl'),
  _Variation('dragCurl', 'cableCurl'),
  _Variation('dragCurl', 'waiterCurl'),
  _Variation('cableCurl', 'waiterCurl'),
  // ── Biceps — short head emphasis (complete network) ──
  _Variation('preacherCurl', 'dumbbellPreacherCurl'),
  _Variation('preacherCurl', 'machinePreacherCurl'),
  _Variation('preacherCurl', 'concentrationCurl'),
  _Variation('preacherCurl', 'spiderCurl'),
  _Variation('dumbbellPreacherCurl', 'machinePreacherCurl'),
  _Variation('dumbbellPreacherCurl', 'concentrationCurl'),
  _Variation('dumbbellPreacherCurl', 'spiderCurl'),
  _Variation('machinePreacherCurl', 'concentrationCurl'),
  _Variation('machinePreacherCurl', 'spiderCurl'),
  _Variation('concentrationCurl', 'spiderCurl'),
  // ── Biceps — long head emphasis (complete network) ──
  _Variation('inclineDumbbellCurl', 'behindBackCableCurl'),
  _Variation('inclineDumbbellCurl', 'bayesianCableCurl'),
  _Variation('behindBackCableCurl', 'bayesianCableCurl'),
  // ── Biceps — hammer / brachialis (complete network) ──
  _Variation('hammerCurl', 'preacherHammerCurl'),
  _Variation('hammerCurl', 'reverseZottmanCurl'),
  _Variation('preacherHammerCurl', 'reverseZottmanCurl'),
  // ── Biceps — cross-cluster bridges ──
  _Variation('dumbbellCurl', 'preacherCurl'),
  _Variation('dumbbellCurl', 'concentrationCurl'),
  _Variation('dumbbellCurl', 'spiderCurl'),
  _Variation('dumbbellCurl', 'inclineDumbbellCurl'),
  _Variation('barbellCurl', 'inclineDumbbellCurl'),
  _Variation('barbellCurl', 'bayesianCableCurl'),
  _Variation('waiterCurl', 'inclineDumbbellCurl'),
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
  _Variation('barbellSquat', 'legPress'),
  _Variation('barbellSquat', 'hackSquat'),
  _Variation('legPress', 'hackSquat'),
  // ── Quadriceps — lunge pattern ──
  _Variation('lunge', 'bulgarianSplitSquat'),
  // ── Hamstrings (biceps femoris + semitendinosus) ──
  _Variation('romanianDeadlift', 'nordicCurl'),
  _Variation('romanianDeadlift', 'legCurl'),
  _Variation('nordicCurl', 'legCurl'),
  // ── Glutes (gluteus maximus) ──
  _Variation('hipThrust', 'gluteBridge'),
  _Variation('hipThrust', 'cableKickback'),
  _Variation('gluteBridge', 'cableKickback'),
  // ── Abs (rectus abdominis) ──
  _Variation('crunch', 'hangingLegRaise'),
  _Variation('crunch', 'abWheelRollout'),
  _Variation('hangingLegRaise', 'abWheelRollout'),
  _Variation('plank', 'abWheelRollout'),
];
