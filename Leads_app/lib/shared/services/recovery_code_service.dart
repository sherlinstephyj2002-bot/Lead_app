import 'dart:math';
import 'password_encryption.dart';

class RecoveryCodeService {
  static const String _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Excludes visually ambiguous 0, O, 1, I

  /// Generates a new Recovery Code formatted as WK-XXXX-XXXX (e.g., WK-8F72-KP91)
  static String generateCode() {
    final rand = Random.secure();
    final part1 = List.generate(4, (_) => _charset[rand.nextInt(_charset.length)]).join();
    final part2 = List.generate(4, (_) => _charset[rand.nextInt(_charset.length)]).join();
    return 'WK-$part1-$part2';
  }

  /// Normalizes a recovery code string (removes extra punctuation/spaces, converts to uppercase)
  static String normalize(String code) {
    final clean = code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.startsWith('WK')) {
      final sub = clean.substring(2);
      if (sub.length == 8) {
        return 'WK-${sub.substring(0, 4)}-${sub.substring(4)}';
      }
    }
    if (clean.length == 8) {
      return 'WK-${clean.substring(0, 4)}-${clean.substring(4)}';
    }
    return code.trim().toUpperCase();
  }

  /// Hashes a recovery code for secure storage in Firestore
  static String hashRecoveryCode(String code) {
    final norm = normalize(code);
    int hash1 = 5381;
    int hash2 = 0x811c9dc5;
    for (int i = 0; i < norm.length; i++) {
      final char = norm.codeUnitAt(i);
      hash1 = ((hash1 << 5) + hash1) ^ char;
      hash2 = (hash2 ^ char) * 16777619;
    }
    final combinedHex = '${(hash1 & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}${(hash2 & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
    return PasswordEncryption.encrypt(combinedHex);
  }

  /// Encrypts raw recovery code so authorized admin can view/copy it if needed
  static String encryptCode(String code) {
    return PasswordEncryption.encrypt(normalize(code));
  }

  /// Decrypts encrypted recovery code
  static String decryptCode(String encrypted) {
    try {
      return PasswordEncryption.decrypt(encrypted);
    } catch (_) {
      return '';
    }
  }

  /// Verifies an input recovery code against stored hash or stored encrypted code
  static bool verifyCode(String input, {String? storedHash, String? storedEncrypted}) {
    if (input.trim().isEmpty) return false;
    final normInput = normalize(input);

    if (storedHash != null && storedHash.isNotEmpty) {
      if (hashRecoveryCode(normInput) == storedHash) return true;
    }

    if (storedEncrypted != null && storedEncrypted.isNotEmpty) {
      final decrypted = decryptCode(storedEncrypted);
      if (normalize(decrypted) == normInput) return true;
    }

    return false;
  }
}
