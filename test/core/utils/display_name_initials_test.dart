import 'package:athlos_app/core/utils/display_name_initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('displayNameInitials', () {
    test('returns null for null, empty, or whitespace', () {
      expect(displayNameInitials(null), isNull);
      expect(displayNameInitials(''), isNull);
      expect(displayNameInitials('   '), isNull);
    });

    test('single word returns first letter', () {
      expect(displayNameInitials('Rafael'), 'R');
      expect(displayNameInitials('  ana  '), 'A');
    });

    test('multiple words return first and last initial', () {
      expect(displayNameInitials('Rafael Silva'), 'RS');
      expect(displayNameInitials('João da Silva'), 'JS');
      expect(displayNameInitials('Mary Jane Watson'), 'MW');
    });
  });
}
