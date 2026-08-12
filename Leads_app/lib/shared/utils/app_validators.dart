import 'package:worktrack/shared/models/user_model.dart';

/// Centralized application validation rules and messages.
class AppValidators {
  /// Production-grade RFC 5322 compliant regex for email validation.
  static final RegExp _emailRegExp = RegExp(
    r'^(?!\.)(?!.*\.\.)[a-zA-Z0-9._%+-]+(?<!\.)@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
  );

  /// Validates Login identifier (Email, Mobile number, or Employee ID).
  static String? validateLoginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email or mobile number.';
    }

    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      if (!_emailRegExp.hasMatch(trimmed)) {
        return 'Please enter a valid email address.';
      }
    } else {
      final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isNotEmpty && !RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
        if (digitsOnly.length != 10) {
          return 'Phone number must contain exactly 10 digits.';
        }
      }
    }
    return null;
  }

  /// Validates standard 10-digit India mobile numbers.
  /// Allowed: 9876543210 (exactly 10 digits)
  /// Rejected: 1234, 12345678901, 98765abc10, abcdefghij, etc.
  static String? validateMobileNumber(String? value, {bool isRequired = true, String fieldName = 'Phone number'}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required.';
      return null;
    }

    final trimmed = value.trim();

    // Check if input contains letters
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return '$fieldName must contain only digits.';
    }

    // Extract digits only
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length != 10) {
      return '$fieldName must contain exactly 10 digits.';
    }

    return null;
  }

  /// Validates company contact / international phone numbers.
  /// Rejects letters and invalid structures while supporting international formats.
  static String? validateCompanyPhone(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Phone number is required.';
      return null;
    }

    final trimmed = value.trim();

    // Reject alphabetic characters
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Phone number must contain only digits.';
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 10) {
      return 'Phone number must contain exactly 10 digits.';
    }

    return null;
  }

  /// Validates Personal Email format (e.g. john@gmail.com).
  static String? validatePersonalEmail(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Personal email is required.';
      return null;
    }

    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  /// Validates Business Email format (e.g. contact@business.co, admin@company.com).
  static String? validateBusinessEmail(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Business email is required.';
      return null;
    }

    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  /// Validates Company / Internal Email format (e.g. jass01@jasscreative.com).
  static String? validateCompanyEmail(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Company internal email is required.';
      return null;
    }

    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  /// Validates Website URL format (optional field).
  static String? validateWebsite(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    final websiteRegExp = RegExp(
      r'^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
      caseSensitive: false,
    );

    if (!websiteRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid website URL.';
    }

    return null;
  }

  /// Validates Employee ID format (e.g. JASS01).
  static String? validateEmployeeIdFormat(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Employee ID is required.';
      return null;
    }

    final trimmed = value.trim().toUpperCase();
    if (!RegExp(r'^[a-zA-Z0-9\-_]{2,20}$').hasMatch(trimmed)) {
      return 'Please enter a valid Employee ID.';
    }

    return null;
  }

  /// Validates Employee ID uniqueness within a company.
  /// Ignores the employee's own record when editing ([currentUid]).
  static String? validateEmployeeIdUniqueness(
    String? value,
    List<UserModel> existingEmployees, {
    String? currentUid,
  }) {
    if (value == null || value.trim().isEmpty) return null;

    final trimmed = value.trim().toUpperCase();

    final hasDuplicate = existingEmployees.any((emp) {
      if (currentUid != null && emp.uid == currentUid) return false;
      final existingId = (emp.employeeId ?? '').trim().toUpperCase();
      return existingId == trimmed;
    });

    if (hasDuplicate) {
      return 'Employee ID already exists. Please use a unique Employee ID.';
    }

    return null;
  }

  /// Validates Company Email uniqueness within a company.
  /// Ignores the employee's own record when editing ([currentUid]).
  static String? validateCompanyEmailUniqueness(
    String? value,
    List<UserModel> existingEmployees, {
    String? currentUid,
  }) {
    if (value == null || value.trim().isEmpty) return null;

    final trimmed = value.trim().toLowerCase();

    final hasDuplicate = existingEmployees.any((emp) {
      if (currentUid != null && emp.uid == currentUid) return false;
      final existingEmail = (emp.companyEmail ?? emp.email).trim().toLowerCase();
      return existingEmail == trimmed;
    });

    if (hasDuplicate) {
      return 'Company email already exists. Please use a unique company email address.';
    }

    return null;
  }

  /// Validates Personal Email uniqueness within a company.
  /// Ignores the employee's own record when editing ([currentUid]).
  static String? validatePersonalEmailUniqueness(
    String? value,
    List<UserModel> existingEmployees, {
    String? currentUid,
  }) {
    if (value == null || value.trim().isEmpty) return null;

    final trimmed = value.trim().toLowerCase();

    final hasDuplicate = existingEmployees.any((emp) {
      if (currentUid != null && emp.uid == currentUid) return false;
      final existingPersonal = (emp.personalEmail ?? emp.employeeEmail ?? '').trim().toLowerCase();
      return existingPersonal.isNotEmpty && existingPersonal == trimmed;
    });

    if (hasDuplicate) {
      return 'This personal email is already registered.';
    }

    return null;
  }

  /// Validates password confirmation matching.
  static String? validatePasswordConfirmation(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  /// Validates 12-digit Aadhaar number (numeric only).
  static String? validateAadhaar(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Aadhaar number is required.';
      return null;
    }

    final trimmed = value.trim();
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Aadhaar number must contain only digits.';
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 12) {
      return 'Aadhaar number must contain exactly 12 digits.';
    }

    return null;
  }

  /// Validates PAN number (5 uppercase letters + 4 digits + 1 uppercase letter).
  static String? validatePan(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'PAN number is required.';
      return null;
    }

    final uppercaseVal = value.trim().toUpperCase();
    final panRegExp = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
    if (!panRegExp.hasMatch(uppercaseVal)) {
      return 'Enter a valid PAN number (e.g., ABCDE1234F).';
    }

    return null;
  }

  /// Validates Passport number (6 to 12 alphanumeric characters).
  static String? validatePassport(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Passport number is required.';
      return null;
    }

    final trimmed = value.trim();
    final passportRegExp = RegExp(r'^[a-zA-Z0-9]{6,12}$');
    if (!passportRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid passport number.';
    }

    return null;
  }

  /// Validates Driving License number.
  static String? validateDrivingLicense(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Driving license number is required.';
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.length < 5 || trimmed.length > 20) {
      return 'Please enter a valid driving license number.';
    }

    return null;
  }

  /// Validates Name on Document.
  static String? validateNameOnDocument(String? value, String docType, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Please enter name as per $docType.';
      return null;
    }

    final trimmed = value.trim();
    if (RegExp(r'\d').hasMatch(trimmed)) {
      return 'Name as per $docType cannot contain numbers.';
    }

    return null;
  }

  /// Masks sensitive Aadhaar number for security (e.g. XXXX XXXX 1234).
  static String maskAadhaar(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not Provided';
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12) {
      return 'XXXX XXXX ${digits.substring(8)}';
    }
    return 'XXXX XXXX ${digits.length > 4 ? digits.substring(digits.length - 4) : digits}';
  }

  /// Masks sensitive PAN number for security (e.g. ABCDE****F).
  static String maskPan(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not Provided';
    final upper = value.trim().toUpperCase();
    if (upper.length == 10) {
      return '${upper.substring(0, 5)}****${upper.substring(9)}';
    }
    return upper;
  }

  /// Masks generic document numbers for privacy.
  static String maskGenericDocument(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not Provided';
    final str = value.trim();
    if (str.length <= 4) return '****';
    return '${str.substring(0, 2)}****${str.substring(str.length - 2)}';
  }
}
