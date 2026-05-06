/// Shared normalization for comparing exercise identifiers and localized labels.
///
/// Aligns semantics with [ExerciseNameMatch] / [ExerciseDao] fuzzy matching:
/// trim, lowercase, strip diacríticos.
abstract final class ExerciseLabelNormalizer {
  ExerciseLabelNormalizer._();

  /// Normalizes [raw] for identity / fuzzy equality (accent-insensitive).
  static String normalize(String raw) {
    var s = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return stripDiacritics(s);
  }

  /// `barbellSquat` → `barbell squat` for substring / token heuristics.
  static String camelCaseToSpacedWords(String asciiIdentifier) {
    if (asciiIdentifier.isEmpty) return asciiIdentifier;
    return asciiIdentifier.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
  }

  static String stripDiacritics(String s) {
    const withDiacritics =
        'àáâãäåèéêëìíîïòóôõöùúûüýñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ';
    const withoutDiacritics =
        'aaaaaaeeeeiiiiooooouuuuyncAAAAAAEEEEIIIIOOOOOUUUUYNC';
    var result = s;
    for (var i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  /// Lowercase single spaces between tokens, accents stripped — for backup/UI
  /// substring flows that should behave like catalog identity normalization.
  static String normalizeComparable(String value) =>
      normalize(value.replaceAll('_', ' '));
}
