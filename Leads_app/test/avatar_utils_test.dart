import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack/shared/utils/avatar_utils.dart';

void main() {
  group('Dynamic Initials Avatar System Tests', () {
    test('1. Single Name "Jasmine" -> "J"', () {
      expect(getInitials('Jasmine'), equals('J'));
    });

    test('2. Single Name "Jela" -> "J"', () {
      expect(getInitials('Jela'), equals('J'));
    });

    test('3. Single Name "Arun" -> "A"', () {
      expect(getInitials('Arun'), equals('A'));
    });

    test('4. Single Name "Sherlin" -> "S"', () {
      expect(getInitials('Sherlin'), equals('S'));
    });

    test('5. Two Names "John David" -> "JD"', () {
      expect(getInitials('John David'), equals('JD'));
    });

    test('6. Two Names "Jasmine Kelly" -> "JK"', () {
      expect(getInitials('Jasmine Kelly'), equals('JK'));
    });

    test('7. Two Names "Arun Kumar" -> "AK"', () {
      expect(getInitials('Arun Kumar'), equals('AK'));
    });

    test('8. Two Names "Mary Joseph" -> "MJ"', () {
      expect(getInitials('Mary Joseph'), equals('MJ'));
    });

    test('9. Three Names "John Michael David" -> "JD"', () {
      expect(getInitials('John Michael David'), equals('JD'));
    });

    test('10. Three Names "Jasmine Rose Kelly" -> "JK"', () {
      expect(getInitials('Jasmine Rose Kelly'), equals('JK'));
    });

    test('11. Three Names "Mary Anne Joseph" -> "MJ"', () {
      expect(getInitials('Mary Anne Joseph'), equals('MJ'));
    });

    test('12. Leading/Trailing & Internal Spaces "  John   David  " -> "JD"', () {
      expect(getInitials('  John   David  '), equals('JD'));
    });

    test('13. Lowercase Input "jasmine kelly" -> "JK"', () {
      expect(getInitials('jasmine kelly'), equals('JK'));
    });

    test('14. Uppercase Input "SHERLIN" -> "S"', () {
      expect(getInitials('SHERLIN'), equals('S'));
    });

    test('15. Missing/Null Name -> "U"', () {
      expect(getInitials(null), equals('U'));
    });

    test('16. Empty String Name -> "U"', () {
      expect(getInitials(''), equals('U'));
      expect(getInitials('   '), equals('U'));
    });
  });
}
