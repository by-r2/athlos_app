import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../training_dao_providers.dart';
import 'workout_sync_repair_service.dart';

final workoutSyncRepairServiceProvider =
    Provider<WorkoutSyncRepairService>((ref) {
  return WorkoutSyncRepairService(ref.watch(workoutDaoProvider));
});

