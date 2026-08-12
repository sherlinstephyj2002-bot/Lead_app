class PasswordEncryption {
  static const String _key = 'WorkTrackSecureKey123!';

  static String encrypt(String password) {
    final List<int> chars = password.codeUnits;
    final List<int> keyChars = _key.codeUnits;
    final List<int> encrypted = [];
    for (int i = 0; i < chars.length; i++) {
      encrypted.add(chars[i] ^ keyChars[i % keyChars.length]);
    }
    return encrypted.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  static String decrypt(String hexString) {
    final List<int> encrypted = [];
    for (int i = 0; i < hexString.length; i += 2) {
      encrypted.add(int.parse(hexString.substring(i, i + 2), radix: 16));
    }
    final List<int> keyChars = _key.codeUnits;
    final List<int> decrypted = [];
    for (int i = 0; i < encrypted.length; i++) {
      decrypted.add(encrypted[i] ^ keyChars[i % keyChars.length]);
    }
    return String.fromCharCodes(decrypted);
  }
}
