import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/enums/equipment_category.dart';

/// Seeds the database with verified equipment on first creation.
///
/// Each item has [isVerified] = true and an English key as [name].
/// The UI maps these keys to localized display names via ARB.
Future<void> seedEquipments(AppDatabase db) async {
  await db.batch((batch) {
    for (final item in _seedItems) {
      batch.insert(
        db.equipments,
        EquipmentsCompanion.insert(
          name: item.name,
          category: item.category,
          isVerified: const Value(true),
        ),
      );
    }
  });
}

/// Seeds only the equipment added in schema version 2 (elliptical, jumpRope).
/// Called from migration onUpgrade when upgrading from v1.
Future<void> seedEquipmentsV2(AppDatabase db) async {
  await db.batch((batch) {
    for (final item in _v2Items) {
      batch.insert(
        db.equipments,
        EquipmentsCompanion.insert(
          name: item.name,
          category: item.category,
          isVerified: const Value(true),
        ),
      );
    }
  });
}

/// Seeds only the equipment added in schema version 3
/// (adductorMachine, abductorMachine).
Future<void> seedEquipmentsV3(AppDatabase db) async {
  await db.batch((batch) {
    for (final item in _v3Items) {
      batch.insert(
        db.equipments,
        EquipmentsCompanion.insert(
          name: item.name,
          category: item.category,
          isVerified: const Value(true),
        ),
      );
    }
  });
}

const _v2Items = [
  _SeedItem('elliptical', EquipmentCategory.cardio),
  _SeedItem('jumpRope', EquipmentCategory.cardio),
];

const _v3Items = [
  _SeedItem('adductorMachine', EquipmentCategory.machines),
  _SeedItem('abductorMachine', EquipmentCategory.machines),
];

class _SeedItem {
  final String name;
  final EquipmentCategory category;

  const _SeedItem(this.name, this.category);
}

const _seedItems = [
  // Free Weights
  _SeedItem('barbell', EquipmentCategory.freeWeights),
  _SeedItem('dumbbell', EquipmentCategory.freeWeights),
  _SeedItem('kettlebell', EquipmentCategory.freeWeights),
  _SeedItem('ezBar', EquipmentCategory.freeWeights),
  _SeedItem('weightPlates', EquipmentCategory.freeWeights),

  // Machines
  _SeedItem('cableMachine', EquipmentCategory.machines),
  _SeedItem('smithMachine', EquipmentCategory.machines),
  _SeedItem('legPressMachine', EquipmentCategory.machines),
  _SeedItem('latPulldownMachine', EquipmentCategory.machines),
  _SeedItem('chestPressMachine', EquipmentCategory.machines),
  _SeedItem('pecDeckMachine', EquipmentCategory.machines),
  _SeedItem('legExtensionMachine', EquipmentCategory.machines),
  _SeedItem('legCurlMachine', EquipmentCategory.machines),
  _SeedItem('hackSquatMachine', EquipmentCategory.machines),
  _SeedItem('adductorMachine', EquipmentCategory.machines),
  _SeedItem('abductorMachine', EquipmentCategory.machines),

  // Structures
  _SeedItem('pullUpBar', EquipmentCategory.structures),
  _SeedItem('dipStation', EquipmentCategory.structures),
  _SeedItem('gymnasticRings', EquipmentCategory.structures),
  _SeedItem('suspensionTrainer', EquipmentCategory.structures),

  // Accessories
  _SeedItem('flatBench', EquipmentCategory.accessories),
  _SeedItem('adjustableBench', EquipmentCategory.accessories),
  _SeedItem('squatRack', EquipmentCategory.accessories),
  _SeedItem('resistanceBands', EquipmentCategory.accessories),
  _SeedItem('abWheel', EquipmentCategory.accessories),
  _SeedItem('medicineBall', EquipmentCategory.accessories),
  _SeedItem('battleRope', EquipmentCategory.accessories),
  _SeedItem('foamRoller', EquipmentCategory.accessories),

  // Cardio
  _SeedItem('treadmill', EquipmentCategory.cardio),
  _SeedItem('stationaryBike', EquipmentCategory.cardio),
  _SeedItem('rowingMachine', EquipmentCategory.cardio),
  _SeedItem('elliptical', EquipmentCategory.cardio),
  _SeedItem('jumpRope', EquipmentCategory.cardio),
];
