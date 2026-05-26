import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/result.dart';
import '../datasources/daos/workout_dao.dart';

class WorkoutSyncRepairService {
  const WorkoutSyncRepairService(this._dao);

  final WorkoutDao _dao;

  Future<Result<int>> purgeCorruptedRows({required String userId}) async {
    try {
      final deleted = await _dao.purgeCorruptedRowsForUser(userId);
      return Success(deleted);
    } on Exception catch (e) {
      return Failure(DatabaseException('Failed to repair workout rows: $e'));
    }
  }
}

