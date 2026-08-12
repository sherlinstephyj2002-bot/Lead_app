import 'dart:math';
import 'package:worktrack/shared/models/company_model.dart';
import 'package:worktrack/shared/models/user_model.dart';

/// Utility class for generating internal Employee IDs and Company Email addresses
class EmployeeIdGenerator {
  /// Extracts the 4-character uppercase prefix from the employee's FIRST NAME only.
  /// Examples:
  /// - Sheryl -> SHER
  /// - Abinaya Joseph -> ABIN
  /// - John -> JOHN
  /// - Ana -> ANA
  /// - Jass -> JASS
  static String extractFirstNamePrefix(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'EMP';

    // 1. Isolate the FIRST NAME (split by whitespace)
    final firstName = trimmed.split(RegExp(r'\s+')).first;

    // 2. Clean accent characters and non-alphanumeric symbols
    final clean = firstName
        .replaceAll(RegExp(r'[áàâäãÅå]'), 'a')
        .replaceAll(RegExp(r'[ÁÀÂÄÃÅå]'), 'A')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[óòôöõ]'), 'o')
        .replaceAll(RegExp(r'[ÓÒÔÖÕ]'), 'O')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll(RegExp(r'[ñÑ]'), 'N')
        .replaceAll(RegExp(r'[çÇ]'), 'C')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();

    if (clean.isEmpty) return 'EMP';
    return clean.length >= 4 ? clean.substring(0, 4) : clean;
  }

  /// Legacy alias for extractFirstNamePrefix
  static String extractNamePrefix(String name) => extractFirstNamePrefix(name);

  /// Converts full registered company name into a clean email domain.
  /// Rules:
  /// - Remove spaces and all non-alphanumeric special characters
  /// - Convert to lowercase
  /// - Append .com
  ///
  /// Examples:
  /// - Jazz Creative -> jazzcreative.com
  /// - Jazz Creative Pvt. Ltd. -> jazzcreativepvtltd.com
  /// - ABC Technologies -> abctechnologies.com
  /// - My Company Pvt Ltd -> mycompanypvtltd.com
  static String generateCompanyDomain(String? companyName, {CompanyModel? company}) {
    final nameToUse = (companyName != null && companyName.trim().isNotEmpty)
        ? companyName
        : (company?.name ?? '');

    if (nameToUse.trim().isEmpty) return 'company.com';

    final cleanName = nameToUse
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();

    return cleanName.isNotEmpty ? '$cleanName.com' : 'company.com';
  }

  /// Legacy alias for extractCompanyDomain
  static String extractCompanyDomain(CompanyModel? company, {String? companyName}) {
    return generateCompanyDomain(companyName ?? company?.name, company: company);
  }

  /// Generates a unique Employee ID using first name prefix + random 2-digit number (00-99).
  /// Checks uniqueness against existing employees in the company/tenant.
  static String generateUniqueEmployeeId({
    required String prefix,
    required List<UserModel> existingEmployees,
    Random? random,
  }) {
    final rand = random ?? Random();
    final normPrefix = prefix.toUpperCase();

    final existingIds = existingEmployees
        .map((e) => (e.employeeId ?? '').trim().toUpperCase())
        .toSet();

    // Try up to 100 random 2-digit attempts
    for (int attempts = 0; attempts < 100; attempts++) {
      final twoDigits = rand.nextInt(100).toString().padLeft(2, '0');
      final candidateId = '$normPrefix$twoDigits';
      if (!existingIds.contains(candidateId)) {
        return candidateId;
      }
    }

    // Sequential fallback if 2-digit space is filled
    for (int i = 0; i < 999; i++) {
      final pad = i.toString().padLeft(2, '0');
      final candidateId = '$normPrefix$pad';
      if (!existingIds.contains(candidateId)) {
        return candidateId;
      }
    }

    return '${normPrefix}99';
  }

  /// Formats the Employee ID
  static String formatEmployeeId(String prefix, int sequenceNum) {
    final normPrefix = prefix.toUpperCase();
    final padDigits = sequenceNum.toString().padLeft(2, '0');
    return '$normPrefix$padDigits';
  }

  /// Formats internal company email (e.g. sher42@jazzcreative.com)
  static String formatCompanyEmail({
    required String employeeId,
    required String companyDomain,
  }) {
    final cleanId = employeeId.trim().toLowerCase();
    final cleanDomain = companyDomain.trim().toLowerCase();
    return '$cleanId@$cleanDomain';
  }

  /// Convenience method to generate Employee ID and Company Login Email.
  static GeneratedCredentials generateCredentials({
    required String employeeName,
    required List<UserModel> existingEmployees,
    String? companyName,
    CompanyModel? company,
  }) {
    final prefix = extractFirstNamePrefix(employeeName);
    final employeeId = generateUniqueEmployeeId(
      prefix: prefix,
      existingEmployees: existingEmployees,
    );

    final companyDomain = generateCompanyDomain(companyName ?? company?.name, company: company);
    final companyEmail = formatCompanyEmail(
      employeeId: employeeId,
      companyDomain: companyDomain,
    );

    return GeneratedCredentials(
      prefix: prefix,
      sequence: 0,
      employeeId: employeeId,
      companyDomain: companyDomain,
      companyEmail: companyEmail,
      isDomainConfigured: true,
    );
  }
}

class GeneratedCredentials {
  final String prefix;
  final int sequence;
  final String employeeId;
  final String companyDomain;
  final String companyEmail;
  final bool isDomainConfigured;

  const GeneratedCredentials({
    required this.prefix,
    required this.sequence,
    required this.employeeId,
    required this.companyDomain,
    required this.companyEmail,
    required this.isDomainConfigured,
  });
}
