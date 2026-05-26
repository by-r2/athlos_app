import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import 'ghost_exercise_remap_service.dart';

part 'ghost_exercise_remap_providers.g.dart';

@Riverpod(keepAlive: true)
GhostExerciseRemapService ghostExerciseRemapService(Ref ref) =>
    GhostExerciseRemapService(ref.watch(appDatabaseProvider));
