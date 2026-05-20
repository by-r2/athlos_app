import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../domain/repositories/local_backup_repository.dart';
import '../../domain/usecases/resolve_runtime_duplicate_use_case.dart';
import '../../domain/usecases/scan_runtime_local_duplicates_use_case.dart';
import 'local_backup_repository_impl.dart';

final localBackupRepositoryProvider = Provider<LocalBackupRepository>(
  (ref) => LocalBackupRepositoryImpl(ref.watch(appDatabaseProvider)),
);

final scanRuntimeLocalDuplicatesUseCaseProvider =
    Provider<ScanRuntimeLocalDuplicatesUseCase>(
      (ref) => ScanRuntimeLocalDuplicatesUseCase(
        ref.watch(localBackupRepositoryProvider),
      ),
    );

final resolveRuntimeDuplicateUseCaseProvider =
    Provider<ResolveRuntimeDuplicateUseCase>(
      (ref) => ResolveRuntimeDuplicateUseCase(
        ref.watch(localBackupRepositoryProvider),
      ),
    );
