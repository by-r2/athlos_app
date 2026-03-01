import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/gemini_config.dart';
import '../../../profile/data/repositories/profile_providers.dart';
import '../../../training/data/repositories/training_providers.dart';
import '../../domain/repositories/chiron_repository.dart';
import '../helpers/prompt_builder.dart';
import 'chiron_repository_impl.dart';

part 'chiron_providers.g.dart';

@riverpod
PromptBuilder promptBuilder(Ref ref) => PromptBuilder(
      profileRepo: ref.watch(userProfileRepositoryProvider),
      equipmentRepo: ref.watch(equipmentRepositoryProvider),
      workoutRepo: ref.watch(workoutRepositoryProvider),
      executionRepo: ref.watch(workoutExecutionRepositoryProvider),
      exerciseRepo: ref.watch(exerciseRepositoryProvider),
    );

@riverpod
ChironRepository chironRepository(Ref ref) => ChironRepositoryImpl(
      apiKey: geminiApiKey,
      profileRepo: ref.watch(userProfileRepositoryProvider),
      equipmentRepo: ref.watch(equipmentRepositoryProvider),
      workoutRepo: ref.watch(workoutRepositoryProvider),
      exerciseRepo: ref.watch(exerciseRepositoryProvider),
    );
