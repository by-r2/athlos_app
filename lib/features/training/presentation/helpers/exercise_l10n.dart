import '../../../../core/localization/domain_label_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/movement_pattern.dart';
import '../../domain/enums/muscle_group.dart';
import '../../domain/enums/muscle_region.dart';
import '../../domain/enums/muscle_role.dart';
import '../../domain/enums/target_muscle.dart';

/// Maps a verified exercise's English key [name] to its localized display name.
/// Falls back to [name] directly for custom (user-created) items.
String localizedExerciseName(
  String name, {
  required bool isVerified,
  required AppLocalizations l10n,
}) {
  final resolver = DomainLabelResolver(l10n);
  return resolver.toDisplayName(
    kind: DomainLabelKind.exercise,
    canonicalName: name,
    isVerified: isVerified,
  );
}

/// Substring match on exercise search: **case-insensitive** on both the
/// localized label and the canonical key (e.g. camelCase in the database).
///
/// Returns true when [rawQuery] is empty or only whitespace (caller may skip
/// filtering in that case).
bool exerciseCatalogSearchMatches({
  required String localizedDisplay,
  required String canonicalKey,
  required String rawQuery,
}) {
  final q = rawQuery.trim();
  if (q.isEmpty) return true;
  final needle = q.toLowerCase();
  return localizedDisplay.toLowerCase().contains(needle) ||
      canonicalKey.toLowerCase().contains(needle);
}

/// Returns the localized display name for a [MuscleGroup].
String localizedMuscleGroupName(MuscleGroup group, AppLocalizations l10n) =>
    DomainLabelResolver(l10n).toDisplayName(
      kind: DomainLabelKind.muscleGroup,
      canonicalName: group.name,
      isVerified: true,
    );

/// Returns the localized display name for a [TargetMuscle].
String localizedTargetMuscle(TargetMuscle muscle, AppLocalizations l10n) =>
    DomainLabelResolver(l10n).toDisplayName(
      kind: DomainLabelKind.targetMuscle,
      canonicalName: muscle.name,
      isVerified: true,
    );

/// Returns the localized display name for a [MuscleRegion].
String localizedMuscleRegion(MuscleRegion region, AppLocalizations l10n) =>
    DomainLabelResolver(l10n).toDisplayName(
      kind: DomainLabelKind.muscleRegion,
      canonicalName: region.name,
      isVerified: true,
    );

/// Returns the localized display name for a [MovementPattern].
String localizedMovementPattern(MovementPattern p, AppLocalizations l10n) =>
    DomainLabelResolver(l10n).toDisplayName(
      kind: DomainLabelKind.movementPattern,
      canonicalName: p.name,
      isVerified: true,
    );

/// Returns the localized display name for a [MuscleRole].
String localizedMuscleRole(MuscleRole role, AppLocalizations l10n) =>
    DomainLabelResolver(l10n).toDisplayName(
      kind: DomainLabelKind.muscleRole,
      canonicalName: role.name,
      isVerified: true,
    );
