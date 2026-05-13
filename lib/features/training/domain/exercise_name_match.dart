import '../../../core/localization/exercise_catalog_label_index.dart';
import '../../../core/localization/exercise_label_normalization.dart';
import 'entities/exercise.dart';

/// Normalizes an exercise name for duplicate checks ([ExerciseLabelNormalizer]).
///
/// Aligned with [ExerciseDao] fuzzy matching pass 1–2 semantics (not containment).
class ExerciseNameMatch {
  ExerciseNameMatch._();

  static String normalize(String raw) => ExerciseLabelNormalizer.normalize(raw);

  static bool namesCollide(String a, String b) => normalize(a) == normalize(b);

  /// Whether [candidate] collides with names / synonyms of a catalog row,
  /// without building a full [Exercise] entity (e.g. Drift DAO).
  static bool collidesWithCanonicalRow(
    String candidate, {
    required String canonicalName,
    required bool isVerified,
  }) {
    if (namesCollide(candidate, canonicalName)) return true;
    if (!isVerified ||
        !exerciseCatalogLabelIndex.isKnownCanonicalKey(canonicalName)) {
      return false;
    }
    for (final surface in exerciseCatalogLabelIndex.surfaceForms(
      canonicalName,
    )) {
      if (namesCollide(candidate, surface)) return true;
    }
    return false;
  }

  /// Whether [candidate] collides with names / synonyms of catalog [exercise].
  static bool collidesWithCatalogExercise(String candidate, Exercise exercise) {
    return collidesWithCanonicalRow(
      candidate,
      canonicalName: exercise.name,
      isVerified: exercise.isVerified,
    );
  }

  /// Returns the first catalog exercise whose canonical name or verified synonym
  /// collides with [candidate].
  static Exercise? findConflict(String candidate, Iterable<Exercise> catalog) {
    for (final e in catalog) {
      if (collidesWithCatalogExercise(candidate, e)) return e;
    }
    return null;
  }

  /// Returns likely duplicates / near-matches, excluding exact matches.
  ///
  /// Verified rows score against canonical key, camelCase-expanded words,
  /// and **every loaded locale label** ([exerciseCatalogLabelIndex]).
  /// Custom exercises use [displayLabel] only.
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
      if (collidesWithCatalogExercise(candidate, e)) {
        continue;
      }

      final surfaces = _surfacesForScoring(e, displayLabel);

      final score = surfaces
          .map((s) {
            final rowNorm = normalize(s);
            if (rowNorm.isEmpty) return 0;
            return _similarityScore(input, inputTokens, rowNorm);
          })
          .fold<int>(0, (best, next) => next > best ? next : best);

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

  static Iterable<String> _surfacesForScoring(
    Exercise e,
    String Function(Exercise exercise) displayLabel,
  ) {
    if (!e.isVerified ||
        !exerciseCatalogLabelIndex.isKnownCanonicalKey(e.name)) {
      return [displayLabel(e)];
    }
    final fromIndex = exerciseCatalogLabelIndex.surfaceForms(e.name).toList();
    if (fromIndex.isEmpty) {
      return [e.name];
    }
    return fromIndex;
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
}
