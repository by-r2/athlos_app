import 'package:drift/drift.dart';

class Programs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get focus => text()();
  TextColumn get durationMode => text()();
  IntColumn get durationValue => integer()();
  IntColumn get defaultRestSeconds => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  BoolColumn get isInDeload => boolean().withDefault(const Constant(false))();
  IntColumn get deloadFrequency => integer().nullable()();
  TextColumn get deloadStrategy => text().nullable()();
  RealColumn get deloadVolumeMultiplier => real().nullable()();
  RealColumn get deloadIntensityMultiplier => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isDirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
