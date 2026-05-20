import 'package:drift/drift.dart';

/// Local mapping between Drift rows and remote UUIDs.
class SyncRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTableName =>
      text().named('table_name').withLength(min: 1, max: 80)();
  IntColumn get localId => integer()();
  TextColumn get syncId => text().withLength(min: 1, max: 80)();
  TextColumn get remoteId => text().nullable()();
  TextColumn get remoteUserId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastPushedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {entityTableName, localId},
    {syncId},
  ];
}
