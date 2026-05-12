import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout_execution_screen no longer renders per-set notes field', () async {
    final source = await File(
      'lib/features/training/presentation/screens/workout_execution_screen.dart',
    ).readAsString();

    expect(source.contains('setNotesHint'), isFalse);
    expect(source.contains('_showNotesField'), isFalse);
    expect(source.contains('_setNotes'), isFalse);
  });
}
