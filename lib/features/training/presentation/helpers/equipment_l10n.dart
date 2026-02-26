import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/equipment_category.dart';

/// Maps a verified equipment's English key [name] to its localized display name.
/// Falls back to [name] directly for unverified (user-created) items.
String localizedEquipmentName(
  String name, {
  required bool isVerified,
  required AppLocalizations l10n,
}) {
  if (!isVerified) return name;

  return _equipmentNameMap(l10n)[name] ?? name;
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
      'hackSquatMachine': l10n.equipmentHackSquatMachine,
      'adductorMachine': l10n.equipmentAdductorMachine,
      'abductorMachine': l10n.equipmentAbductorMachine,
    };

/// Returns the localized display name for an [EquipmentCategory].
String localizedCategoryName(
  EquipmentCategory category,
  AppLocalizations l10n,
) =>
    switch (category) {
      EquipmentCategory.freeWeights => l10n.categoryFreeWeights,
      EquipmentCategory.machines => l10n.categoryMachines,
      EquipmentCategory.structures => l10n.categoryStructures,
      EquipmentCategory.accessories => l10n.categoryAccessories,
      EquipmentCategory.cardio => l10n.categoryCardio,
    };
