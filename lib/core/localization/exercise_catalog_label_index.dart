import 'dart:math' as math;
import 'dart:ui' show Locale;

import '../../l10n/app_localizations.dart';
import 'exercise_canonical_display_map.dart';
import 'exercise_label_normalization.dart';

/// Locales available in [lookupAppLocalizations] for exercise catalog labels.
///
/// Expand when adding new `app_xx.arb` files and delegate `case`s.
const List<Locale> kExerciseCatalogLocalizationLocales = [Locale('pt')];

ExerciseCatalogLabelIndex? _exerciseCatalogLabelIndex;

/// Singleton index of verified exercise synonyms (canonical name + camelCase hint
/// + every loaded locale string).
ExerciseCatalogLabelIndex get exerciseCatalogLabelIndex =>
    _exerciseCatalogLabelIndex ??= ExerciseCatalogLabelIndex.build(
      kExerciseCatalogLocalizationLocales,
    );

/// Pre-computed synonyms and reverse lookup for verified catalog exercises.
class ExerciseCatalogLabelIndex {
  ExerciseCatalogLabelIndex._({
    required Map<String, List<String>> surfaceFormsByCanonical,
    required Map<String, String> canonicalByNormalizedIdentity,
  }) : _surfaceFormsByCanonical = surfaceFormsByCanonical,
       _canonicalByNormalizedIdentity = canonicalByNormalizedIdentity;

  factory ExerciseCatalogLabelIndex.build(List<Locale> locales) {
    final maps = <Map<String, String>>[
      for (final locale in locales)
        exerciseCanonicalToDisplayMap(lookupAppLocalizations(locale)),
    ];
    final keys = <String>{};
    for (final m in maps) {
      keys.addAll(m.keys);
    }
    final sorted = keys.toList()..sort();
    final surfaces = <String, List<String>>{};
    final inverse = <String, String>{};

    for (final canonical in sorted) {
      final seen = <String>{};
      final list = <String>[];

      void addRaw(String raw) {
        final t = raw.trim();
        if (t.isEmpty) return;
        if (seen.add(t)) list.add(t);
      }

      addRaw(canonical);
      addRaw(ExerciseLabelNormalizer.camelCaseToSpacedWords(canonical));
      for (final m in maps) {
        final v = m[canonical];
        if (v != null) addRaw(v);
      }

      surfaces[canonical] = list;

      for (final s in list) {
        final norm = ExerciseLabelNormalizer.normalize(s);
        if (norm.isEmpty) continue;
        inverse.putIfAbsent(norm, () => canonical);
      }
    }

    return ExerciseCatalogLabelIndex._(
      surfaceFormsByCanonical: surfaces,
      canonicalByNormalizedIdentity: inverse,
    );
  }

  final Map<String, List<String>> _surfaceFormsByCanonical;
  final Map<String, String> _canonicalByNormalizedIdentity;

  Iterable<String> surfaceForms(String canonicalKey) sync* {
    final list = _surfaceFormsByCanonical[canonicalKey];
    if (list == null) return;
    yield* list;
  }

  bool isKnownCanonicalKey(String canonicalKey) =>
      _surfaceFormsByCanonical.containsKey(canonicalKey);

  /// Match when [normalizedCandidate] equals a normalized synonym (accent-insensitive).
  String? canonicalForNormalizedIdentity(String normalizedCandidate) {
    if (normalizedCandidate.isEmpty) return null;
    return _canonicalByNormalizedIdentity[normalizedCandidate];
  }

  /// Resolves a user-visible or backup label to a catalog canonical key when
  /// identity-normalized equality hits a known synonym; otherwise returns null.
  String? tryResolveCanonicalStrict(String candidate) {
    final n = ExerciseLabelNormalizer.normalize(candidate);
    if (n.isEmpty) return null;
    return _canonicalByNormalizedIdentity[n];
  }

  bool matchesContainsQuery(String rawQuery, String canonicalKey) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return true;
    final nq = ExerciseLabelNormalizer.normalize(trimmed);
    if (nq.isEmpty) return true;

    for (final s in surfaceForms(canonicalKey)) {
      final ns = ExerciseLabelNormalizer.normalize(s);
      if (ns.contains(nq) || nq.contains(ns)) return true;
    }
    return false;
  }

  /// Ratio in \([0,1]\): max Levenshtein similarity between normalized [rawInput]
  /// and any normalized synonym of [canonicalKey] (aligned with backup fuzzy UX).
  double maxFuzzySimilarity(String rawInput, String canonicalKey) {
    final a = ExerciseLabelNormalizer.normalize(rawInput);
    if (a.isEmpty) return 0;
    var best = 0.0;
    for (final s in surfaceForms(canonicalKey)) {
      final b = ExerciseLabelNormalizer.normalize(s);
      if (b.isEmpty) continue;
      best = math.max(best, _levenshteinSimilarity(a, b));
    }
    return best;
  }
}

double _levenshteinSimilarity(String a, String b) {
  if (a == b) return 1;
  final distance = _levenshtein(a, b);
  final maxLen = math.max(a.length, b.length);
  return 1 - (distance / maxLen);
}

int _levenshtein(String a, String b) {
  final m = a.length;
  final n = b.length;
  final matrix = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) {
    matrix[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    matrix[0][j] = j;
  }
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      matrix[i][j] = math.min(
        math.min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
        matrix[i - 1][j - 1] + cost,
      );
    }
  }
  return matrix[m][n];
}
