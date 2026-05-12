import 'package:drift/drift.dart';

class CatalogGovernanceEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventUuid => text().unique()();
  TextColumn get eventType => text()();
  TextColumn get entityType => text()();
  IntColumn get localEntityId => integer().nullable()();
  TextColumn get catalogRemoteId => text().nullable()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
