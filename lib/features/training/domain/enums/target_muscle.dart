import 'muscle_group.dart';
import 'muscle_region.dart';

/// Complete catalog of trainable muscles in the human body.
///
/// Each value maps to a [MuscleGroup] via [muscleGroup] and declares
/// which [MuscleRegion]s are anatomically valid via [validRegions].
enum TargetMuscle {
  // Chest
  pectoralisMajor,
  pectoralisMinor,

  // Back
  latissimusDorsi,
  rhomboids,
  trapezius,
  erectorSpinae,
  teresMajor,

  // Shoulders
  anteriorDeltoid,
  lateralDeltoid,
  rearDeltoid,

  // Biceps
  bicepsBrachii,
  brachialis,
  brachioradialis,

  // Triceps
  tricepsBrachii,

  // Forearms
  wristFlexors,
  wristExtensors,

  // Abs
  rectusAbdominis,
  transverseAbdominis,
  obliques,

  // Quadriceps
  rectusFemoris,
  vastusLateralis,
  vastusMedialis,
  vastusIntermedius,

  // Hamstrings
  bicepsFemoris,
  semitendinosus,
  semimembranosus,

  // Glutes
  gluteusMaximus,
  gluteusMedius,
  gluteusMinimus,
  tensorFasciaeLatae,

  // Adductors
  adductorMagnus,
  adductorLongus,
  adductorBrevis,

  // Calves
  gastrocnemius,
  soleus,

  // Full Body / auxiliary
  hipFlexors,
  serratus,
}

extension TargetMuscleX on TargetMuscle {
  MuscleGroup get muscleGroup => switch (this) {
        TargetMuscle.pectoralisMajor ||
        TargetMuscle.pectoralisMinor =>
          MuscleGroup.chest,
        TargetMuscle.latissimusDorsi ||
        TargetMuscle.rhomboids ||
        TargetMuscle.trapezius ||
        TargetMuscle.erectorSpinae ||
        TargetMuscle.teresMajor =>
          MuscleGroup.back,
        TargetMuscle.anteriorDeltoid ||
        TargetMuscle.lateralDeltoid ||
        TargetMuscle.rearDeltoid =>
          MuscleGroup.shoulders,
        TargetMuscle.bicepsBrachii ||
        TargetMuscle.brachialis ||
        TargetMuscle.brachioradialis =>
          MuscleGroup.biceps,
        TargetMuscle.tricepsBrachii => MuscleGroup.triceps,
        TargetMuscle.wristFlexors ||
        TargetMuscle.wristExtensors =>
          MuscleGroup.forearms,
        TargetMuscle.rectusAbdominis ||
        TargetMuscle.transverseAbdominis ||
        TargetMuscle.obliques =>
          MuscleGroup.abs,
        TargetMuscle.rectusFemoris ||
        TargetMuscle.vastusLateralis ||
        TargetMuscle.vastusMedialis ||
        TargetMuscle.vastusIntermedius =>
          MuscleGroup.quadriceps,
        TargetMuscle.bicepsFemoris ||
        TargetMuscle.semitendinosus ||
        TargetMuscle.semimembranosus =>
          MuscleGroup.hamstrings,
        TargetMuscle.gluteusMaximus ||
        TargetMuscle.gluteusMedius ||
        TargetMuscle.gluteusMinimus ||
        TargetMuscle.tensorFasciaeLatae =>
          MuscleGroup.glutes,
        TargetMuscle.adductorMagnus ||
        TargetMuscle.adductorLongus ||
        TargetMuscle.adductorBrevis =>
          MuscleGroup.adductors,
        TargetMuscle.gastrocnemius ||
        TargetMuscle.soleus =>
          MuscleGroup.calves,
        TargetMuscle.hipFlexors ||
        TargetMuscle.serratus =>
          MuscleGroup.fullBody,
      };

  List<MuscleRegion> get validRegions => switch (this) {
        TargetMuscle.pectoralisMajor => [
            MuscleRegion.upper,
            MuscleRegion.mid,
            MuscleRegion.lower,
          ],
        TargetMuscle.trapezius => [
            MuscleRegion.upper,
            MuscleRegion.mid,
            MuscleRegion.lower,
          ],
        TargetMuscle.rectusAbdominis => [
            MuscleRegion.upper,
            MuscleRegion.lower,
          ],
        TargetMuscle.bicepsBrachii => [
            MuscleRegion.longHead,
            MuscleRegion.shortHead,
          ],
        TargetMuscle.tricepsBrachii => [
            MuscleRegion.longHead,
            MuscleRegion.lateralHead,
            MuscleRegion.medialHead,
          ],
        TargetMuscle.gastrocnemius => [
            MuscleRegion.medialHead,
            MuscleRegion.lateralHead,
          ],
        _ => [],
      };
}
