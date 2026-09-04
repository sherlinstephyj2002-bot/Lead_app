import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

import '../../../shared/services/file_download_service.dart';
import '../../../shared/utils/csv_export_helper.dart';
import '../../../shared/utils/app_notification.dart';
import '../../../shared/services/app_error_handler.dart';

class CsvExportService {
  /// Exports raw rows to CSV after running safety sanitization on all values.
  static Future<void> exportToCsv({
    required BuildContext context,
    required String filename,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final sanitizedRows = rows.map((row) {
        return row.map((cell) {
          if (cell == null) return '';
          if (cell is DateTime) {
            return CsvExportHelper.formatDateTime(cell);
          }
          if (cell is String) {
            return CsvExportHelper.sanitizeText(cell);
          }
          return cell;
        }).toList();
      }).toList();

      final csvData = const ListToCsvConverter().convert(sanitizedRows);

      await FileDownloadService.downloadCsv(
        csvContent: csvData,
        fileName: filename,
      );

      if (context.mounted) {
        AppNotification.showSuccess(context, '$filename downloaded to your Downloads folder.');
      }
    } catch (e) {
      if (context.mounted) {
        AppNotification.showError(context, AppErrorHandler.parseError(e));
      }
    }
  }
}
