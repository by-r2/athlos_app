import 'package:athlos_app/core/errors/app_exception.dart';
import 'package:athlos_app/core/errors/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResultX', () {
    test('isSuccess e getOrThrow em Success', () {
      const result = Success<int>(10);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.getOrThrow(), 10);
    });

    test('isFailure e getOrThrow em Failure', () {
      const result = Failure<int>(DatabaseException('db error'));

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(() => result.getOrThrow(), throwsA(isA<DatabaseException>()));
    });
  });
}
