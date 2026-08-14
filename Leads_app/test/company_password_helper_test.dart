import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack/shared/utils/company_password_helper.dart';

void main() {
  group('CompanyPasswordHelper - Password Generation Tests', () {
    test('Generates company default password for JAZZ CREATIVES', () {
      final pass = CompanyPasswordHelper.generateDefaultPassword('JAZZ CREATIVES', companyCode: 'JC');
      expect(pass, equals('Jazz@123'));
    });

    test('Generates company default password for ABC TECHNOLOGIES', () {
      final pass = CompanyPasswordHelper.generateDefaultPassword('ABC TECHNOLOGIES', companyCode: 'ABC');
      expect(pass, equals('Abc@123'));
    });

    test('Generates company default password for single word name', () {
      final pass = CompanyPasswordHelper.generateDefaultPassword('Global');
      expect(pass, equals('Global@123'));
    });

    test('Handles empty company name with company code fallback', () {
      final pass = CompanyPasswordHelper.generateDefaultPassword('', companyCode: 'wt');
      expect(pass, equals('Wt@123'));
    });

    test('Handles empty company name without company code', () {
      final pass = CompanyPasswordHelper.generateDefaultPassword('');
      expect(pass, equals('Work@123'));
    });

    test('Derived password passes validation', () {
      final pass = CompanyPasswordHelper.generateDefaultPassword('JAZZ CREATIVES');
      final err = CompanyPasswordHelper.validateDefaultPassword(pass);
      expect(err, isNull);
    });
  });

  group('CompanyPasswordHelper - Password Validation Tests', () {
    test('Rejects empty or null passwords', () {
      expect(CompanyPasswordHelper.validateDefaultPassword(null), isNotNull);
      expect(CompanyPasswordHelper.validateDefaultPassword(''), isNotNull);
      expect(CompanyPasswordHelper.validateDefaultPassword('   '), isNotNull);
    });

    test('Rejects short passwords (<6 chars)', () {
      expect(CompanyPasswordHelper.validateDefaultPassword('Pass1'), isNotNull);
    });

    test('Rejects trivial/weak passwords', () {
      expect(CompanyPasswordHelper.validateDefaultPassword('123456'), isNotNull);
      expect(CompanyPasswordHelper.validateDefaultPassword('password'), isNotNull);
      expect(CompanyPasswordHelper.validateDefaultPassword('company'), isNotNull);
      expect(CompanyPasswordHelper.validateDefaultPassword('12345678'), isNotNull);
    });

    test('Accepts valid strong default passwords', () {
      expect(CompanyPasswordHelper.validateDefaultPassword('Jazz@123'), isNull);
      expect(CompanyPasswordHelper.validateDefaultPassword('Abc@123'), isNull);
      expect(CompanyPasswordHelper.validateDefaultPassword('CompanyPass#2026'), isNull);
    });
  });
}
