import 'package:athlos_app/core/localization/exercise_catalog_label_index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final index = ExerciseCatalogLabelIndex.build(
    kExerciseCatalogLocalizationLocales,
  );

  group('ExerciseCatalogLabelIndex', () {
    test('tryResolveCanonicalStrict maps PT ARB label to canonical key', () {
      expect(
        index.tryResolveCanonicalStrict('Supino Reto com Barra'),
        'benchPress',
      );
    });

    test('tryResolveCanonicalStrict is accent-insensitive', () {
      expect(
        index.tryResolveCanonicalStrict('Supíno Reto com Barra'),
        'benchPress',
      );
    });

    test('matchesContainsQuery matches substring across synonyms', () {
      expect(index.matchesContainsQuery('supino', 'benchPress'), true);
      expect(index.matchesContainsQuery('bench', 'benchPress'), true);
    });

    test('matchesContainsQuery rejects unrelated query', () {
      expect(index.matchesContainsQuery('corrida', 'benchPress'), false);
    });

    test('maxFuzzySimilarity boosts match against localized title', () {
      expect(
        index.maxFuzzySimilarity('Supino Reto Barra', 'benchPress'),
        greaterThan(0.8),
      );
    });

    test('isKnownCanonicalKey distinguishes catalog vs unknown', () {
      expect(index.isKnownCanonicalKey('benchPress'), true);
      expect(index.isKnownCanonicalKey('meuExercicioCustom'), false);
    });
  });
}
