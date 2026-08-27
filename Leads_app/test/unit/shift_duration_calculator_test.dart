import 'package:flutter_test/flutter_test.dart';
import 'package:worktrack/shared/utils/shift_duration_calculator.dart';

void main() {
  group('ShiftDurationCalculator Tests', () {
    test('1. 9:00 AM to 6:00 PM (No Break)', () {
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

    test('1b. 9:00 AM to 6:00 PM with 1-hour Break (60 mins)', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:00 AM',
        endTimeStr: '6:00 PM',
        breakDurationMinutes: 60,
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 540);
      expect(result.netWorkingMinutes, 480);
      expect(result.workingHours, 8.0);
      expect(result.formattedWorkingHours, '8 hours');
    });

    test('2. 10:00 AM to 6:00 PM with 30-minute Break', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '10:00 AM',
        endTimeStr: '6:00 PM',
        breakDurationMinutes: 30,
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 480);
      expect(result.netWorkingMinutes, 450);
      expect(result.workingHours, 7.5);
      expect(result.formattedWorkingHours, '7 hours 30 minutes');
    });

    test('3. 12:00 PM to 3:00 PM', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '12:00 PM',
        endTimeStr: '3:00 PM',
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 180);
      expect(result.workingHours, 3.0);
      expect(result.formattedWorkingHours, '3 hours');
    });

    test('4. 9:00 AM to 5:00 PM', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:00 AM',
        endTimeStr: '5:00 PM',
      );
      expect(result.isValid, isTrue);
      expect(result.workingHours, 8.0);
      expect(result.formattedWorkingHours, '8 hours');
    });

    test('5. 9:30 AM to 6:00 PM', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:30 AM',
        endTimeStr: '6:00 PM',
      );
      expect(result.isValid, isTrue);
      expect(result.netWorkingMinutes, 510);
      expect(result.workingHours, 8.5);
      expect(result.formattedWorkingHours, '8 hours 30 minutes');
    });

    test('6. 11:00 AM to 1:00 PM', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '11:00 AM',
        endTimeStr: '1:00 PM',
      );
      expect(result.isValid, isTrue);
      expect(result.workingHours, 2.0);
      expect(result.formattedWorkingHours, '2 hours');
    });

    test('7. 10:00 PM to 6:00 AM (Overnight Shift)', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '10:00 PM',
        endTimeStr: '6:00 AM',
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 480); // 8 hours
      expect(result.workingHours, 8.0);
      expect(result.formattedWorkingHours, '8 hours');
    });

    test('7b. 11:00 PM to 2:00 AM (Overnight Shift)', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '11:00 PM',
        endTimeStr: '2:00 AM',
      );
      expect(result.isValid, isTrue);
      expect(result.totalShiftMinutes, 180);
      expect(result.workingHours, 3.0);
      expect(result.formattedWorkingHours, '3 hours');
    });

    test('8. 9:15 AM to 6:00 PM', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:15 AM',
        endTimeStr: '6:00 PM',
      );
      expect(result.isValid, isTrue);
      expect(result.netWorkingMinutes, 525);
      expect(result.formattedWorkingHours, '8 hours 45 minutes');
    });

    test('9. 24-Hour format: 09:00 to 18:00', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '09:00',
        endTimeStr: '18:00',
        breakDurationMinutes: 60,
      );
      expect(result.isValid, isTrue);
      expect(result.workingHours, 8.0);
      expect(result.formattedWorkingHours, '8 hours');
    });

    test('10. Invalid Break Duration exceeding total shift', () {
      final result = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: '9:00 AM',
        endTimeStr: '10:00 AM', // 1 hour = 60 mins
        breakDurationMinutes: 90, // Exceeds 60 mins
      );
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('exceeds total shift duration'));
    });
  });
}
