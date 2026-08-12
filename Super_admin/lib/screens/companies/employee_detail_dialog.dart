import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';

class EmployeeDetailDialog extends StatelessWidget {
  final UserModel employee;
  final List<Map<String, dynamic>> attendanceRecords;

  const EmployeeDetailDialog({
    super.key,
    required this.employee,
    required this.attendanceRecords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compute attendance statistics for this employee
    final empAttendance = attendanceRecords.where((a) {
      final uid = (a['userId'] ?? a['employeeId'] ?? a['uid'] ?? '').toString();
      return uid == employee.uid || uid == (employee.employeeId ?? '');
    }).toList();

    int presentDays = 0;
    int absentDays = 0;
    int leaveDays = 0;
    int lateDays = 0;
    int checkInCount = 0;
    int checkOutCount = 0;

    for (final record in empAttendance) {
      final status = (record['status'] ?? '').toString().toLowerCase();
      if (status == 'present') presentDays++;
      if (status == 'absent') absentDays++;
      if (status == 'leave' || status == 'on leave') leaveDays++;
      if (record['isLate'] == true || status == 'late') lateDays++;
      if (record['checkIn'] != null || record['checkInTime'] != null) checkInCount++;
      if (record['checkOut'] != null || record['checkOutTime'] != null) checkOutCount++;
    }

    final totalWorkingDays = empAttendance.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                    backgroundImage: employee.profileImageUrl != null
                        ? NetworkImage(employee.profileImageUrl!)
                        : null,
                    child: employee.profileImageUrl == null
                        ? Text(
                            employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              employee.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (employee.status?.toLowerCase() == 'active')
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                employee.status ?? 'Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: (employee.status?.toLowerCase() == 'active')
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${employee.designation ?? 'Employee'} • ${employee.department ?? 'General'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${employee.employeeId ?? employee.uid}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // PROFILE & CONTACT SECTION
              Text(
                'Profile & Contact Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _buildDetailItem(theme, 'Company Email', employee.email, Icons.email_outlined),
                  if (employee.personalEmail != null && employee.personalEmail!.isNotEmpty)
                    _buildDetailItem(theme, 'Personal Email', employee.personalEmail!, Icons.mail_outline_rounded),
                  if (employee.phoneNumber != null && employee.phoneNumber!.isNotEmpty)
                    _buildDetailItem(theme, 'Phone Number', employee.phoneNumber!, Icons.phone_outlined),
                  _buildDetailItem(theme, 'Branch', employee.branch ?? 'Main Branch', Icons.location_city_rounded),
                  _buildDetailItem(
                    theme,
                    'Joining Date',
                    employee.joiningDate != null
                        ? DateFormat('MMM dd, yyyy').format(employee.joiningDate!)
                        : DateFormat('MMM dd, yyyy').format(employee.createdAt),
                    Icons.calendar_today_rounded,
                  ),
                  _buildDetailItem(
                    theme,
                    'Last Login',
                    employee.lastLogin != null
                        ? DateFormat('MMM dd, yyyy HH:mm').format(employee.lastLogin!)
                        : 'N/A',
                    Icons.access_time_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // WORK INFORMATION SECTION
              Text(
                'Work Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _buildDetailItem(theme, 'Department', employee.department ?? 'N/A', Icons.business_center_outlined),
                  _buildDetailItem(theme, 'Designation', employee.designation ?? 'N/A', Icons.badge_outlined),
                  _buildDetailItem(theme, 'Role', employee.role.toUpperCase(), Icons.security_rounded),
                  _buildDetailItem(theme, 'Employment Status', employee.status ?? 'Active', Icons.verified_user_outlined),
                ],
              ),
              const SizedBox(height: 24),

              // ATTENDANCE SUMMARY SECTION
              Text(
                'Attendance Summary Oversight',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.5,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatTile(theme, 'Total Recorded Days', '$totalWorkingDays', Colors.indigoAccent),
                  _buildStatTile(theme, 'Present Days', '$presentDays', Colors.greenAccent),
                  _buildStatTile(theme, 'Absent Days', '$absentDays', Colors.redAccent),
                  _buildStatTile(theme, 'On Leave Days', '$leaveDays', Colors.orangeAccent),
                  _buildStatTile(theme, 'Late Arrivals', '$lateDays', Colors.amberAccent),
                  _buildStatTile(theme, 'Check-Ins / Check-Outs', '$checkInCount / $checkOutCount', Colors.tealAccent),
                ],
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(ThemeData theme, String label, String value, IconData icon) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(ThemeData theme, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
