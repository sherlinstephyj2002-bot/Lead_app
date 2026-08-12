class PasswordValidationResult {
  final bool hasMinLength;

  PasswordValidationResult({
    required this.hasMinLength,
  });

  bool get isValid => hasMinLength;
}

class PasswordValidator {
  static PasswordValidationResult validate(String password) {
    return PasswordValidationResult(
      hasMinLength: password.length >= 6,
    );
  }
}
