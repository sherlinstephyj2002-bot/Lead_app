import 'package:flutter/material.dart';

class ShiftDurationResult {
  final int totalShiftMinutes;
  final int netWorkingMinutes;
  final double workingHours;
  final bool isValid;
  final String? errorMessage;
  final String formattedTotalDuration;
  final String formattedWorkingHours;
  final String formattedShort;

  const ShiftDurationResult({
    required this.totalShiftMinutes,
    required this.netWorkingMinutes,
    required this.workingHours,
    required this.isValid,
    this.errorMessage,
    required this.formattedTotalDuration,
    required this.formattedWorkingHours,
    required this.formattedShort,
  });

  factory ShiftDurationResult.invalid(String message) {
    return ShiftDurationResult(
      totalShiftMinutes: 0,
      netWorkingMinutes: 0,
      workingHours: 0.0,
      isValid: false,
      errorMessage: message,
      formattedTotalDuration: '0 hours',
      formattedWorkingHours: '0 hours',
      formattedShort: '0h',
    );
  }
}

class ShiftDurationCalculator {
  /// Parses a time string (12-hour AM/PM or 24-hour format) into minutes from midnight.
  ///
  /// Examples:
  /// - "09:00 AM", "9:00 AM", "9:15 am" -> 540 / 555
  /// - "12:00 PM" -> 720 (Noon)
  /// - "12:30 PM" -> 750
  /// - "01:00 PM", "1:00 PM" -> 780
  /// - "06:00 PM", "6:00 PM" -> 1080
  /// - "12:00 AM" -> 0 (Midnight)
  /// - "09:00", "18:00", "22:00" -> 540 / 1080 / 1320
  static int? parseTimeToMinutes(String timeStr) {
    final cleanStr = timeStr.trim();
    if (cleanStr.isEmpty) return null;

    final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?$');
    final match = regex.firstMatch(cleanStr);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();

    if (minute < 0 || minute >= 60) return null;

    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
    } else {
      if (hour < 0 || hour >= 24) return null;
    }

    return hour * 60 + minute;
  }

  /// Converts a [TimeOfDay] object to total minutes from midnight.
  static int timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  /// Formats minutes from midnight to a 12-hour string (e.g., "09:00 AM" or "06:00 PM").
  static String formatMinutesTo12Hour(int totalMinutes) {
    final normalized = (totalMinutes % 1440 + 1440) % 1440;
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hStr = hour12.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  /// Calculates the total shift duration and net working hours given start time, end time, and break duration.
  static ShiftDurationResult calculateShiftDuration({
    required String startTimeStr,
    required String endTimeStr,
    int breakDurationMinutes = 0,
  }) {
    final startMins = parseTimeToMinutes(startTimeStr);
    final endMins = parseTimeToMinutes(endTimeStr);

    if (startMins == null || endMins == null) {
      return ShiftDurationResult.invalid('Please select valid Start Time and End Time');
    }

    // Handle overnight shifts (e.g. 10:00 PM to 06:00 AM)
    var totalShiftMins = endMins - startMins;
    if (totalShiftMins <= 0) {
      totalShiftMins += 1440; // Add 24 hours (1440 minutes)
    }

    if (breakDurationMinutes < 0) {
      return ShiftDurationResult.invalid('Break duration cannot be negative');
    }

    if (breakDurationMinutes > totalShiftMins) {
      return ShiftDurationResult.invalid(
        'Break duration (${formatMinutesToHumanReadable(breakDurationMinutes)}) exceeds total shift duration (${formatMinutesToHumanReadable(totalShiftMins)})',
      );
    }

    final netWorkingMins = totalShiftMins - breakDurationMinutes;
    final workingHours = netWorkingMins / 60.0;

    return ShiftDurationResult(
      totalShiftMinutes: totalShiftMins,
      netWorkingMinutes: netWorkingMins,
      workingHours: workingHours,
      isValid: true,
      formattedTotalDuration: formatMinutesToHumanReadable(totalShiftMins),
      formattedWorkingHours: formatMinutesToHumanReadable(netWorkingMins),
      formattedShort: formatMinutesShort(netWorkingMins),
    );
  }

  /// Formats minutes into human-readable text (e.g., "8 hours", "7 hours 30 minutes", "45 minutes").
  static String formatMinutesToHumanReadable(int minutes) {
    if (minutes <= 0) return '0 hours';

    final hrs = minutes ~/ 60;
    final mins = minutes % 60;

    if (hrs > 0 && mins > 0) {
      return '$hrs ${hrs == 1 ? "hour" : "hours"} $mins ${mins == 1 ? "minute" : "minutes"}';
    } else if (hrs > 0) {
      return '$hrs ${hrs == 1 ? "hour" : "hours"}';
    } else {
      return '$mins ${mins == 1 ? "minute" : "minutes"}';
    }
  }

  /// Formats minutes into short text (e.g., "8h", "7h 30m", "45m").
  static String formatMinutesShort(int minutes) {
    if (minutes <= 0) return '0h';

    final hrs = minutes ~/ 60;
    final mins = minutes % 60;

    if (hrs > 0 && mins > 0) {
      return '${hrs}h ${mins}m';
    } else if (hrs > 0) {
      return '${hrs}h';
    } else {
      return '${mins}m';
    }
  }
}
