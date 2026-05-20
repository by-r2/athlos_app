import 'package:drift/drift.dart';

/// Training programs (mesocycles).
class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();
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

  TextColumn get remoteId => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  DateTimeColumn get localUpdatedAt => dateTime().nullable()();
}
