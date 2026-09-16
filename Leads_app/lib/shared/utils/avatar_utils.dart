import 'package:flutter/material.dart';

/// Dynamic Initials Avatar system utility function.
/// Converts any user or company name into 1 or 2 uppercase initials based on WorkTrack avatar rules:
/// - 1 name part: First letter uppercase (e.g. "Jasmine" -> "J", "Jela" -> "J", "Arun" -> "A", "Sherlin" -> "S")
/// - 2 name parts: First letter of both names uppercase (e.g. "John David" -> "JD", "Jasmine Kelly" -> "JK")
/// - 3+ name parts: First letter of first name and last name uppercase (e.g. "John Michael David" -> "JD")
/// - Leading/trailing spaces and multiple internal spaces are cleaned.
/// - Missing or empty names return fallback: "U".
String getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return 'U';
  final trimmed = name.trim();
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) {
    final word = parts[0];
    return word.substring(0, 1).toUpperCase();
  }
  final first = parts.first[0];
  final last = parts.last[0];
  return '$first$last'.toUpperCase();
}

/// Generates a deterministic background color from a string (e.g. name or ID)
Color getAvatarColor(String? key, {bool isDark = false}) {
  if (key == null || key.isEmpty) {
    return const Color(0xFF5B4CF0);
  }
  int hash = 0;
  for (int i = 0; i < key.length; i++) {
    hash = key.codeUnitAt(i) + ((hash << 5) - hash);
  }
  
  final List<Color> palette = isDark
      ? const [
          Color(0xFF4F46E5),
          Color(0xFF0284C7),
          Color(0xFF0D9488),
          Color(0xFF059669),
          Color(0xFFD97706),
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
        ]
      : const [
          Color(0xFF6366F1),
          Color(0xFF0EA5E9),
          Color(0xFF14B8A6),
          Color(0xFF10B981),
          Color(0xFFF59E0B),
          Color(0xFF8B5CF6),
          Color(0xFFEC4899),
        ];

  final index = hash.abs() % palette.length;
  return palette[index];
}
