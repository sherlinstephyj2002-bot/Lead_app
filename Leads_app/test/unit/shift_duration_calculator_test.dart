import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack/shared/utils/shift_duration_calculator.dart';

void main() {
  group('ShiftDurationCalculator Tests', () {
    test('1. 9:00 AM to 6:00 PM = 9 Hours', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:00 AM',
        endTimeStr: '6:00 PM',
        breakDurationMinutes: 0,
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 540); // 9 hours
      expect(result.workingHours, 9.0);
      expect(result.formattedWorkingHours, '9 hours');
    });

    test('1b. 9:00 AM to 9:00 PM = 12 Hours', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:00 AM',
        endTimeStr: '9:00 PM',
        breakDurationMinutes: 60,
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 720); // 12 hours
      expect(result.workingHours, 12.0);
      expect(result.formattedWorkingHours, '12 hours');
    });

    test('2. 10:00 AM to 6:00 PM = 8 Hours', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '10:00 AM',
        endTimeStr: '6:00 PM',
        breakDurationMinutes: 30,
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 480);
      expect(result.workingHours, 8.0);
      expect(result.formattedWorkingHours, '8 hours');
    });

    test('3. 12:00 PM to 3:00 PM = 3 Hours', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '12:00 PM',
        endTimeStr: '3:00 PM',
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 180);
      expect(result.workingHours, 3.0);
      expect(result.formattedWorkingHours, '3 hours');
    });

    test('7c. 9:00 PM to 6:00 AM (Overnight Shift) = 9 Hours', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:00 PM',
        endTimeStr: '6:00 AM',
        breakDurationMinutes: 60,
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 540); // 9 hours total
      expect(result.workingHours, 9.0);
      expect(result.formattedWorkingHours, '9 hours');
    });

    test('11. formatHoursShort helper', () {
      expect(ShiftDurationCalculator.formatHoursShort(8.0), '8 hrs');
      expect(ShiftDurationCalculator.formatHoursShort(2.0), '2 hrs');
      expect(ShiftDurationCalculator.formatHoursShort(1.0), '1 hr');
      expect(ShiftDurationCalculator.formatHoursShort(2.5), '2.5 hrs');
    });
  });
}
