import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityPinService {
  /// Hashes a 6-digit PIN using SHA-256 with a fixed salt
  static String hashPin(String pin) {
    final cleanPin = pin.trim();
    const salt = 'WorkTrack_Security_PIN_Salt_2026_!#';
    final bytes = utf8.encode('$cleanPin:$salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies a 6-digit PIN against its stored hash
  static bool verifyPin(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    final hashedInput = hashPin(pin);
    return hashedInput == storedHash;
  }

  /// Checks if a 6-digit PIN is weak or overly sequential/repeated
  static bool isWeakPin(String pin) {
    final cleanPin = pin.trim();
    if (cleanPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      return true;
    }

    // Repeated digit sequences (000000, 111111, ..., 999999)
    for (int i = 0; i <= 9; i++) {
      final repeated = '$i' * 6;
      if (cleanPin == repeated) return true;
    }

    // Common sequential patterns
    const weakSequences = [
      '123456',
      '654321',
      '012345',
      '543210',
      '234567',
      '765432',
      '345678',
      '876543',
      '456789',
      '987654',
      '000111',
      '111000',
      '121212',
      '112233',
    ];

    return weakSequences.contains(cleanPin);
  }
}
