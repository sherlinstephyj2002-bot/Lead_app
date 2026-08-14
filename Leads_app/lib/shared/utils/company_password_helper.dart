import 'package:worktrack/shared/services/password_validator.dart';

/// Centralized utility for company-level default employee password generation & validation.
class CompanyPasswordHelper {
  /// Generates a company-specific default employee initial password.
  /// Example:
  ///   - "JAZZ CREATIVES" -> "Jazz@123"
  ///   - "ABC TECHNOLOGIES" -> "Abc@123"
  ///   - "WorkTrack Inc." -> "Worktrack@123"
  static String generateDefaultPassword(String companyName, {String? companyCode}) {
    final cleanName = companyName.trim();
    if (cleanName.isEmpty) {
      final cleanCode = (companyCode ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim();
      if (cleanCode.isNotEmpty) {
        final formattedCode = cleanCode[0].toUpperCase() + (cleanCode.length > 1 ? cleanCode.substring(1).toLowerCase() : '');
        return '$formattedCode@123';
      }
      return 'Work@123';
    }

    // Extract first word containing letters
    final words = cleanName.split(RegExp(r'\s+'));
    String prefix = '';
    for (final word in words) {
      final lettersOnly = word.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (lettersOnly.isNotEmpty) {
        prefix = lettersOnly;
        break;
      }
    }

    if (prefix.isEmpty) {
      prefix = cleanName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    }

    if (prefix.isEmpty) {
      prefix = 'Work';
    } else if (prefix.length == 1) {
      prefix = '${prefix.toUpperCase()}emp';
    } else {
      if (prefix.length > 12) {
        prefix = prefix.substring(0, 12);
      }
      prefix = prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
    }

    return '$prefix@123';
  }

  /// Validates company default password to prevent extremely weak passwords.
  static String? validateDefaultPassword(String? password) {
    if (password == null || password.trim().isEmpty) {
      return 'Default password cannot be empty.';
    }

    final trimmed = password.trim();
    if (trimmed.length < 6) {
      return 'Password must be at least 6 characters long.';
    }

    final lower = trimmed.toLowerCase();
    const weakPasswords = {
      '123456',
      'password',
      '12345678',
      'company',
      '123456789',
      'qwerty',
      'admin123',
      'admin',
      'worktrack',
    };

    if (weakPasswords.contains(lower)) {
      return 'This password is too weak. Please use a unique combination (e.g. Jazz@123).';
    }

    final validation = PasswordValidator.validate(trimmed);
    if (!validation.isValid) {
      return 'Password must be at least 6 characters long.';
    }

    return null;
  }
}
