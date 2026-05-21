import 'package:drift/drift.dart';

class BodyMetrics extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  RealColumn get weight => real()();
  RealColumn get bodyFatPercent => real().nullable()();
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
