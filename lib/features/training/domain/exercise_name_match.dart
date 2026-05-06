import 'entities/exercise.dart';

/// Normalizes an exercise name for duplicate checks (trim, lower case,
/// diacritics removed).
///
/// Aligned with [ExerciseDao] fuzzy matching pass 1–2 semantics (not containment).
class ExerciseNameMatch {
  ExerciseNameMatch._();

  static String normalize(String raw) {
    final lower = raw.trim().toLowerCase();
    return _removeDiacritics(lower);
  }

  static bool namesCollide(String a, String b) => normalize(a) == normalize(b);

  /// Returns the first catalog exercise whose name collides with [candidate].
  static Exercise? findConflict(String candidate, Iterable<Exercise> catalog) {
    for (final e in catalog) {
      if (namesCollide(candidate, e.name)) return e;
    }
    return null;
  }

  /// Returns likely duplicates / near-matches, excluding exact matches.
  ///
  /// Compares [candidate] against each exercise’s **canonical key** ([Exercise.name]),
  /// its **[displayLabel]** (e.g. localized PT-BR title), and words split from camelCase.
  /// Without [displayLabel], Portuguese queries like “Agachamento” would never match
  /// seeded keys like `bulgarianSplitSquat`.
  static List<Exercise> findSimilar(
    String candidate,
    Iterable<Exercise> catalog, {
    required String Function(Exercise exercise) displayLabel,
    int limit = 8,
  }) {
    final input = normalize(candidate);
    if (input.isEmpty) return const [];

    final inputTokens = _tokens(input);
    final ranked = <({Exercise exercise, int score})>[];
    for (final e in catalog) {
      final labelRaw = displayLabel(e);
      if (namesCollide(candidate, e.name) ||
          namesCollide(candidate, labelRaw)) {
        continue;
      }

      final rowCanonical = normalize(e.name);
      final rowDisplay = normalize(labelRaw);
      final rowFromCamel = normalize(_camelCaseToSpacedWords(e.name));

      final scoreCanon = rowCanonical.isEmpty
          ? 0
          : _similarityScore(input, inputTokens, rowCanonical);
      final scoreDisplay = rowDisplay.isEmpty
          ? 0
          : _similarityScore(input, inputTokens, rowDisplay);
      final scoreCamel = rowFromCamel.isEmpty || rowFromCamel == rowCanonical
          ? 0
          : _similarityScore(input, inputTokens, rowFromCamel);

      final score = [
        scoreCanon,
        scoreDisplay,
        scoreCamel,
      ].reduce((a, b) => a > b ? a : b);
      if (score <= 0) continue;
      ranked.add((exercise: e, score: score));
    }

    ranked.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.exercise.name.compareTo(b.exercise.name);
    });

    return ranked.take(limit).map((r) => r.exercise).toList(growable: false);
  }

  /// `barbellSquat` → `barbell squat` for token / substring matching.
  static String _camelCaseToSpacedWords(String asciiIdentifier) {
    if (asciiIdentifier.isEmpty) return asciiIdentifier;
    final withGaps = asciiIdentifier.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return withGaps;
  }

  static int _similarityScore(
    String input,
    Set<String> inputTokens,
    String rowNorm,
  ) {
    if (rowNorm.contains(input) || input.contains(rowNorm)) {
      return 200 - (rowNorm.length - input.length).abs();
    }

    final rowTokens = _tokens(rowNorm);
    if (rowTokens.isEmpty || inputTokens.isEmpty) return 0;
    final overlap = inputTokens.intersection(rowTokens).length;
    if (overlap == 0) return 0;
    return overlap * 20 - (rowNorm.length - input.length).abs();
  }

  static Set<String> _tokens(String value) {
    final pieces = value.split(RegExp(r'[^a-z0-9]+'));
    return pieces.where((p) => p.length >= 3).toSet();
  }

  static String _removeDiacritics(String s) {
    const withDiacritics =
        'àáâãäåèéêëìíîïòóôõöùúûüýñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝÑÇ';
    const withoutDiacritics =
        'aaaaaaeeeeiiiioooooouuuuyncAAAAAAEEEEIIIIOOOOOUUUUYNC';
    var result = s;
    for (var i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }
}
