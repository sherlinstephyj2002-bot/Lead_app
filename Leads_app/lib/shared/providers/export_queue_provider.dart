import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/models/export_job_model.dart';
import 'package:worktrack/shared/models/app_notification_model.dart';
import 'package:worktrack/shared/providers/providers.dart';

class ExportQueueNotifier extends StateNotifier<List<ExportJobModel>> {
  final Ref _ref;

  ExportQueueNotifier(this._ref) : super(_getInitialJobs());

  static List<ExportJobModel> _getInitialJobs() {
    return [];
  }

  Future<void> createExportJob({required String reportName, required String fileType}) async {
    final user = _ref.read(authProvider).user;
    final jobId = const Uuid().v4();

    final newJob = ExportJobModel(
      id: jobId,
      companyId: user?.companyId ?? 'company-1',
      reportName: reportName,
      requestedBy: user?.name ?? 'Company User',
      requestedByUid: user?.uid ?? 'user-1',
      requestedByRole: user?.role ?? 'Employee',
      requestedDate: DateTime.now(),
      status: 'Processing',
      fileType: fileType,
      progress: 15,
    );

    state = [newJob, ...state];

    // Simulate real-time background processing ticker
    Timer.periodic(const Duration(milliseconds: 1200), (timer) async {
      final current = state.firstWhere((j) => j.id == jobId, orElse: () => newJob);
      if (current.status != 'Processing') {
        timer.cancel();
        return;
      }

      final nextProgress = current.progress + 30;
      if (nextProgress >= 100) {
        timer.cancel();
        _completeJob(jobId, reportName, fileType, user?.uid, user?.companyId);
      } else {
        state = state.map((j) => j.id == jobId ? j.copyWith(progress: nextProgress) : j).toList();
      }
    });
  }

  Future<void> _completeJob(String jobId, String reportName, String fileType, String? userId, String? companyId) async {
    state = state.map((j) {
      if (j.id == jobId) {
        return j.copyWith(
          status: 'Completed',
          progress: 100,
          downloadUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          fileSize: '1.8 MB',
        );
      }
      return j;
    }).toList();

    // Create Notification
    if (userId != null && companyId != null) {
      try {
        final notif = AppNotificationModel(
          notificationId: const Uuid().v4(),
          companyId: companyId,
          title: '$reportName Ready',
          body: 'Your $fileType report has been generated. Tap to view and download.',
          notificationType: 'EXPORT_READY',
          isRead: false,
          createdAt: DateTime.now(),
          targetType: 'USER',
          targetUserId: userId,
          relatedModule: 'REPORTS',
          relatedEntityId: jobId,
        );
        await _ref.read(userRepositoryProvider).createNotification(notif);
      } catch (e) {
        debugPrint('[EXPORT QUEUE] Notification error: $e');
      }
    }
  }

  void retryJob(String jobId) {
    final job = state.firstWhere((j) => j.id == jobId);
    state = state.map((j) => j.id == jobId ? j.copyWith(status: 'Processing', progress: 20, errorMessage: null) : j).toList();
    createExportJob(reportName: job.reportName, fileType: job.fileType);
  }

  void cancelJob(String jobId) {
    state = state.map((j) => j.id == jobId ? j.copyWith(status: 'Cancelled', progress: 0) : j).toList();
  }
}

final exportQueueProvider = StateNotifierProvider<ExportQueueNotifier, List<ExportJobModel>>((ref) {
  return ExportQueueNotifier(ref);
});
