import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack/shared/utils/app_validators.dart';

void main() {
  group('Email Validation Tests', () {
    final validEmails = [
      'john@gmail.com',
      'john.doe@gmail.com',
      'employee@company.com',
      'hr.admin@company.in',
      'user123@company.co.in',
    ];

    final invalidEmails = [
      'john',
      'john@',
      '@gmail.com',
      'john@gmail',
      'john@gmail.',
      'john@.com',
      'john..doe@gmail.com',
      'john@gmail..com',
      'john gmail.com',
      'john@ gmail.com',
      'john@com',
      'john@@gmail.com',
      'john#gmail.com',
      'john@gmail,com',
    ];

    for (final email in validEmails) {
      test('Valid email: $email', () {
        expect(AppValidators.validatePersonalEmail(email), isNull);
        expect(AppValidators.validateBusinessEmail(email), isNull);
        expect(AppValidators.validateCompanyEmail(email), isNull);
      });
    }

    for (final email in invalidEmails) {
      test('Invalid email: $email', () {
        expect(AppValidators.validatePersonalEmail(email), isNotNull);
        expect(AppValidators.validateBusinessEmail(email), isNotNull);
        expect(AppValidators.validateCompanyEmail(email), isNotNull);
      });
    }
  });

  group('Mobile Number Validation Tests', () {
    test('Valid 10-digit mobile number', () {
      expect(AppValidators.validateMobileNumber('9876543210'), isNull);
    });

    final invalidMobiles = [
      '1234',
      '98765',
      '987654321',
      '98765432101',
      '98765abc10',
      'abcdefghij',
    ];

    for (final mobile in invalidMobiles) {
      test('Invalid mobile number: $mobile', () {
        expect(AppValidators.validateMobileNumber(mobile), isNotNull);
      });
    }
  });

  group('Aadhaar & PAN Validation Tests', () {
    test('Valid 12-digit Aadhaar', () {
      expect(AppValidators.validateAadhaar('123456789012'), isNull);
    });

    test('Invalid Aadhaar - short / long / non-numeric', () {
      expect(AppValidators.validateAadhaar('12345'), equals('Aadhaar number must contain exactly 12 digits.'));
      expect(AppValidators.validateAadhaar('1234567890123'), equals('Aadhaar number must contain exactly 12 digits.'));
      expect(AppValidators.validateAadhaar('12345678901a'), equals('Aadhaar number must contain only digits.'));
    });

    test('Valid PAN format', () {
      expect(AppValidators.validatePan('ABCDE1234F'), isNull);
      expect(AppValidators.validatePan('abcde1234f'), isNull);
    });

    test('Invalid PAN format', () {
      expect(AppValidators.validatePan('12345ABCDE'), equals('Enter a valid PAN number (e.g., ABCDE1234F).'));
      expect(AppValidators.validatePan('ABCDE1234'), equals('Enter a valid PAN number (e.g., ABCDE1234F).'));
      expect(AppValidators.validatePan('ABCDE12345F'), equals('Enter a valid PAN number (e.g., ABCDE1234F).'));
    });
  });

  group('Identity Masking Tests', () {
    test('Aadhaar Masking', () {
      expect(AppValidators.maskAadhaar('123456789012'), equals('XXXX XXXX 9012'));
    });

    test('PAN Masking', () {
      expect(AppValidators.maskPan('ABCDE1234F'), equals('ABCDE****F'));
    });
  });
}
