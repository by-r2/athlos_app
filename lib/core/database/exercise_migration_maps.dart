/// Declarative exercise identity rules for schema v30 (imports + migrations).
///
/// - [kExerciseRenamePreV30ToCanonical]: `UPDATE exercises SET name` in `AppDatabase`.
/// - [kExerciseMergeLosersIntoKeeper]: loser rows collapsed in `applyExerciseCanonicalMerges`.
///
/// This library is **Drift-free** so backup logic and tests can depend on aliases
/// without `package:drift`. Future schema bumps: add new maps and extend
/// [resolveImportedExerciseCatalogName] in chronological order.
library;

/// JSON backups at this schema version number or lower use legacy exercise `name`
/// keys (pre–migration v30). [resolveImportedExerciseCatalogName] rewrites those
/// labels during import.
const int kLastBackupSchemaWithLegacyExerciseNaming = 29;

/// Merges applied in migration v30 after renames. Each **loser → keeper** targets
/// equipment-only variants (same movement); other variants stay distinct.
const Map<String, String> kExerciseMergeLosersIntoKeeper = {
  'dumbbellPreacherCurl': 'preacherCurl',
  'ezBarCurl': 'bicepsCurl',
  'machinePreacherCurl': 'preacherCurl',
  'ropeTricepsPushdown': 'tricepsPushdown',
};

/// Old canonical `exercises.name` (pre–schema v30) → current names.
///
/// Keep aligned with migration v30 `UPDATE exercises SET name` in `AppDatabase`.
const Map<String, String> kExerciseRenamePreV30ToCanonical = <String, String>{
  'flatBarbellBenchPress': 'benchPress',
  'inclineBarbellBenchPress': 'inclineBenchPress',
  'declineBarbellBenchPress': 'declineBenchPress',
  'dumbbellFly': 'chestFly',
  'machineChestPress': 'chestPress',
  'barbellRow': 'bentOverRow',
  'dumbbellRow': 'singleArmRow',
  'seatedCableRow': 'seatedRow',
  'underhandBarbellRow': 'underhandRow',
  'dumbbellShrug': 'shrug',
  'barbellCurl': 'bicepsCurl',
  'dumbbellCurl': 'alternatingCurl',
  'inclineDumbbellCurl': 'inclineCurl',
  'barbellSquat': 'backSquat',
  'cableKickback': 'gluteKickback',
  'adductorMachine': 'hipAdduction',
  'abductorMachine': 'hipAbduction',
};

/// Maps a backup label to the current canonical `exercises.name`.
///
/// **Extensibility:** for v31+ renames, apply maps in chronological upgrade order
/// (oldest transformations first). If merges ever depend on renamed losers, insert
/// a merge keyed on the **pre-merge** canonical string that appears in backups.
String resolveImportedExerciseCatalogName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return name;
  var n = kExerciseRenamePreV30ToCanonical[trimmed] ?? trimmed;
  n = kExerciseMergeLosersIntoKeeper[n] ?? n;
  return n;
}
