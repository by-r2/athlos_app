import 'package:athlos_app/core/database/exercise_migration_maps.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveImportedExerciseCatalogName', () {
    test('applies v30 renames', () {
      expect(
        resolveImportedExerciseCatalogName('flatBarbellBenchPress'),
        'benchPress',
      );
      expect(
        resolveImportedExerciseCatalogName('seatedCableRow'),
        'seatedRow',
      );
      expect(
        resolveImportedExerciseCatalogName('barbellCurl'),
        'bicepsCurl',
      );
    });

    test('applies equipment-only merges after rename pass', () {
      expect(
        resolveImportedExerciseCatalogName('ezBarCurl'),
        'bicepsCurl',
      );
      expect(
        resolveImportedExerciseCatalogName('ropeTricepsPushdown'),
        'tricepsPushdown',
      );
      expect(
        resolveImportedExerciseCatalogName('dumbbellPreacherCurl'),
        'preacherCurl',
      );
    });

    test('maps PT-BR display title to seeded canonical (frontRaise)', () {
      expect(
        resolveImportedExerciseCatalogName('Elevação frontal'),
        'frontRaise',
      );
      expect(
        resolveImportedExerciseCatalogName('Elevação Frontal'),
        'frontRaise',
      );
    });

    test('maps escada PT label alias to stairClimbing', () {
      expect(resolveImportedExerciseCatalogName('Escada'), 'stairClimbing');
    });
  });
}
