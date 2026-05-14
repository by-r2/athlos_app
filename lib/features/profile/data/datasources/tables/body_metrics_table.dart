import 'package:drift/drift.dart';

/// Body weight / composition timeline entries.
class BodyMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weight => real()();
  RealColumn get bodyFatPercent => real().nullable()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}
