import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:worktrack/shared/models/export_job_model.dart';
import 'package:worktrack/shared/providers/export_queue_provider.dart';
import 'package:worktrack/shared/services/file_download_service.dart';
import 'package:worktrack/shared/utils/csv_export_helper.dart';
import '../utils/app_notification.dart';

class ExportQueueSheet extends ConsumerStatefulWidget {
  const ExportQueueSheet({super.key});

  @override
  ConsumerState<ExportQueueSheet> createState() => _ExportQueueSheetState();
}

class _ExportQueueSheetState extends ConsumerState<ExportQueueSheet> {
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';

  IconData _getFileIcon(String fileType) {
    if (fileType.contains('Excel')) return Icons.table_chart_rounded;
    if (fileType.contains('CSV')) return Icons.receipt_long_rounded;
    return Icons.picture_as_pdf_rounded;
  }

  Color _getFileColor(String fileType) {
    if (fileType.contains('Excel')) return const Color(0xFF10B981);
    if (fileType.contains('CSV')) return const Color(0xFF3B82F6);
    return const Color(0xFFEF4444);
  }

  void _downloadFile(ExportJobModel job) async {
    try {
      final List<List<dynamic>> rows = [
        ['Record ID', 'Employee Name', 'Department', 'Type', 'Date', 'Status', 'Remarks'],
        [CsvExportHelper.formatId('REC-1001'), CsvExportHelper.sanitizeText('John Doe'), CsvExportHelper.sanitizeText('Engineering'), CsvExportHelper.sanitizeText('Override Request'), CsvExportHelper.formatDateOnly(DateTime(2026, 7, 30)), CsvExportHelper.sanitizeText('Approved'), CsvExportHelper.sanitizeText('Verified by HR')],
        [CsvExportHelper.formatId('REC-1002'), CsvExportHelper.sanitizeText('Jane Smith'), CsvExportHelper.sanitizeText('Operations'), CsvExportHelper.sanitizeText('Attendance Correction'), CsvExportHelper.formatDateOnly(DateTime(2026, 7, 29)), CsvExportHelper.sanitizeText('Approved'), CsvExportHelper.sanitizeText('System Verified')],
        [CsvExportHelper.formatId('REC-1003'), CsvExportHelper.sanitizeText('Robert Chen'), CsvExportHelper.sanitizeText('Marketing'), CsvExportHelper.sanitizeText('Expense Claim'), CsvExportHelper.formatDateOnly(DateTime(2026, 7, 28)), CsvExportHelper.sanitizeText('Completed'), CsvExportHelper.sanitizeText('Audited')],
      ];

      final csvContent = const ListToCsvConverter().convert(rows);
      final safeName = job.reportName.replaceAll(' ', '_');
      final fileName = '${safeName}_Report.csv';
      await FileDownloadService.downloadCsv(csvContent: csvContent, fileName: fileName);

      if (mounted) {
        AppNotification.showSuccess(context, '$fileName downloaded to your Downloads folder.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(exportQueueProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredJobs = jobs.where((j) {
      if (_selectedStatusFilter != 'All' && j.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final title = j.reportName.toLowerCase();
        final by = j.requestedBy.toLowerCase();
        final type = j.fileType.toLowerCase();
        return title.contains(q) || by.contains(q) || type.contains(q);
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[350], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.file_upload_outlined, color: Color(0xFF5B4CF0), size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Export Queue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Inter'),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1),

          // Filters & Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search Report Name or Format...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedStatusFilter,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Status')),
                    DropdownMenuItem(value: 'Processing', child: Text('Processing')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Queued', child: Text('Queued')),
                    DropdownMenuItem(value: 'Failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedStatusFilter = v);
                  },
                ),
              ],
            ),
          ),

          // Jobs List / Empty State
          Expanded(
            child: filteredJobs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file_outlined, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No Export Jobs',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Inter', color: Color(0xFF191C1F)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You have not generated any reports yet.\nGenerate a report to see it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Inter', height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredJobs.length,
                    itemBuilder: (ctx, idx) {
                      final job = filteredJobs[idx];
                      return _buildJobCard(job, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(ExportJobModel job, bool isDark) {
    Color statusColor;
    switch (job.status.toLowerCase()) {
      case 'completed':
        statusColor = const Color(0xFF10B981);
        break;
      case 'processing':
        statusColor = const Color(0xFF3B82F6);
        break;
      case 'queued':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'failed':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF64748B);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getFileColor(job.fileType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getFileIcon(job.fileType), color: _getFileColor(job.fileType), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.reportName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B), fontFamily: 'Inter')),
                    Text('${job.fileType} ${job.fileSize != null ? "• ${job.fileSize}" : ""}', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  job.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),

          if (job.status == 'Processing') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: job.progress / 100,
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    color: const Color(0xFF3B82F6),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${job.progress}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
              ],
            ),
          ],

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Requested by ${job.requestedBy} • ${DateFormat('dd MMM yyyy, hh:mm a').format(job.requestedDate)}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
              Row(
                children: [
                  if (job.status == 'Completed')
                    ElevatedButton.icon(
                      onPressed: () => _downloadFile(job),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  if (job.status == 'Failed')
                    OutlinedButton.icon(
                      onPressed: () => ref.read(exportQueueProvider.notifier).retryJob(job.id),
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  if (job.status == 'Queued' || job.status == 'Processing') ...[
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => ref.read(exportQueueProvider.notifier).cancelJob(job.id),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
