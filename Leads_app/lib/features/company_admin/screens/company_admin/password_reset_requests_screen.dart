import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:worktrack/shared/models/password_reset_request_model.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/providers/providers.dart';

class PasswordResetRequestsScreen extends ConsumerStatefulWidget {
  final String? initialRequestId;

  const PasswordResetRequestsScreen({
    super.key,
    this.initialRequestId,
  });

  @override
  ConsumerState<PasswordResetRequestsScreen> createState() =>
      _PasswordResetRequestsScreenState();
}

class _PasswordResetRequestsScreenState
    extends ConsumerState<PasswordResetRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasHandledInitial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleInitialRequest() async {
    if (_hasHandledInitial || widget.initialRequestId == null || widget.initialRequestId!.isEmpty) return;
    _hasHandledInitial = true;

    final state = ref.read(passwordResetProvider);
    final currentUser = ref.read(authProvider).user;
    PasswordResetRequestModel? req;

    try {
      req = state.requests.firstWhere((r) => r.requestId == widget.initialRequestId);
    } catch (_) {
      req = null;
    }

    req ??= await ref.read(passwordResetRepositoryProvider).getRequestById(widget.initialRequestId!);

    if (req != null && mounted) {
      int tabIndex = 0;
      final st = req.status.toUpperCase();
      if (st == 'APPROVED') tabIndex = 1;
      if (st == 'REJECTED') tabIndex = 2;
      if (st == 'COMPLETED' || st == 'RESOLVED') tabIndex = 3;
      if (st == 'EXPIRED' || (st == 'PENDING' && req.isExpired)) tabIndex = 4;

      _tabController.animateTo(tabIndex);

      if (currentUser != null && (st == 'PENDING')) {
        await ref.read(passwordResetProvider.notifier).markRequestInReview(req, currentUser);
        req = req.copyWith(status: 'In Review');
      }

      if (mounted) {
        _showRequestDetailsModal(context, req, currentUser);
      }
    }
  }

  void _launchPhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.isEmpty) return;
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _launchWhatsApp(String? phoneNumber, String employeeName) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanNumber.isEmpty) return;
    final message = Uri.encodeComponent('Hello $employeeName, regarding your WorkTrack password reset request:');
    final uri = Uri.parse('https://wa.me/$cleanNumber?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetProvider);
    final currentUser = ref.watch(authProvider).user;

    const primaryColor = Color(0xFF5B4CF0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.initialRequestId != null && !_hasHandledInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialRequest();
      });
    }

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Password Reset Requests',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Review & approve employee recovery requests',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () =>
                ref.read(passwordResetProvider.notifier).loadRequests(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Completed'),
            Tab(text: 'Expired'),
          ],
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(state.requests, 'Pending', currentUser),
                _buildRequestList(state.requests, 'Approved', currentUser),
                _buildRequestList(state.requests, 'Rejected', currentUser),
                _buildRequestList(state.requests, 'Completed', currentUser),
                _buildRequestList(state.requests, 'Expired', currentUser),
              ],
            ),
    );
  }

  Widget _buildRequestList(
    List<PasswordResetRequestModel> allRequests,
    String targetStatus,
    UserModel? currentUser,
  ) {
    final filtered = allRequests.where((r) {
      final st = r.status.toUpperCase();
      if (targetStatus == 'Pending') {
        return (st == 'PENDING' || st == 'IN REVIEW' || st == 'IN_REVIEW' || st == 'CONTACTED') && !r.isExpired;
      } else if (targetStatus == 'Completed') {
        return st == 'COMPLETED' || st == 'RESOLVED';
      } else if (targetStatus == 'Expired') {
        return st == 'EXPIRED' || ((st == 'PENDING' || st == 'IN REVIEW' || st == 'IN_REVIEW' || st == 'CONTACTED') && r.isExpired);
      } else {
        return st == targetStatus.toUpperCase();
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No $targetStatus Password Reset Requests',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(passwordResetProvider.notifier).loadRequests(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final req = filtered[index];
          final isHighlighted = widget.initialRequestId == req.requestId;
          return _RequestCardItem(
            request: req,
            currentUser: currentUser,
            isHighlighted: isHighlighted,
            onCardTap: () {
              if (currentUser != null && req.status.toUpperCase() == 'PENDING') {
                ref.read(passwordResetProvider.notifier).markRequestInReview(req, currentUser);
              }
              _showRequestDetailsModal(context, req, currentUser);
            },
            onApprove: () => _handleApprove(context, req, currentUser),
            onRegenerateCode: () => _handleRegenerateRecoveryCode(context, req, currentUser),
            onReject: () => _handleReject(context, req, currentUser),
          );
        },
      ),
    );
  }

  // ---------------- REQUEST DETAILS MODAL DIALOG ----------------
  void _showRequestDetailsModal(
    BuildContext context,
    PasswordResetRequestModel req,
    UserModel? currentUser,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Request Details (${req.requestId})',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                  child: const Icon(Icons.person, color: Color(0xFF5B4CF0), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.employeeName,
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'ID: ${req.employeeId} ${req.department != null ? "• ${req.department}" : ""}',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchPhoneCall(req.registeredMobile),
                    icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
                    label: const Text('Call Employee', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchWhatsApp(req.registeredMobile, req.employeeName),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                    label: const Text('WhatsApp', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REASON / REQUEST DETAILS', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(req.reason, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    'Submitted: ${DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt)} • Expires: ${DateFormat('dd MMM yyyy, hh:mm a').format(req.expiresAt)}',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (req.status.toUpperCase() == 'PENDING' || req.status.toUpperCase() == 'IN REVIEW' || req.status.toUpperCase() == 'IN_REVIEW' || req.status.toUpperCase() == 'CONTACTED') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleResolve(context, req, currentUser);
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Mark as Resolved', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleApprove(context, req, currentUser);
                  },
                  icon: const Icon(Icons.vpn_key_rounded, size: 18),
                  label: const Text('Approve & Generate Temp Password', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleRegenerateRecoveryCode(context, req, currentUser);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Regenerate Code', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleReject(context, req, currentUser);
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject Request', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleResolve(
    BuildContext context,
    PasswordResetRequestModel req,
    UserModel? currentUser,
  ) async {
    if (currentUser == null) return;
    await ref
        .read(passwordResetProvider.notifier)
        .resolveResetRequest(req, currentUser);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request for "${req.employeeName}" marked as Resolved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------- APPROVE ACTION & TEMPORARY PASSWORD DIALOG ----------------
  void _handleApprove(
    BuildContext context,
    PasswordResetRequestModel req,
    UserModel? currentUser,
  ) {
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve Password Reset',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to reset the authentication password for "${req.employeeName}" (${req.employeeId})?\n\nA secure temporary password will be generated for the employee.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final tempPassword = await ref
                  .read(passwordResetProvider.notifier)
                  .approveResetRequest(req, currentUser);

              if (context.mounted && tempPassword != null) {
                _showTemporaryPasswordDialog(
                  context,
                  req.employeeName,
                  req.employeeId,
                  tempPassword,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve & Generate Password'),
          ),
        ],
      ),
    );
  }

  void _showTemporaryPasswordDialog(
    BuildContext context,
    String employeeName,
    String employeeId,
    String tempPassword,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xFF5B4CF0), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Temporary Password Generated',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The password reset for $employeeName ($employeeId) has been approved.',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF474555)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Temporary Password',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF4F46E5)),
                    tooltip: 'Copy Temporary Password',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPassword));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Temporary password copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Share this temporary password with the employee through an approved company communication method. It will NOT be stored in plain text and will NOT be shown again.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------- REGENERATE RECOVERY CODE ACTION DIALOG ----------------
  void _handleRegenerateRecoveryCode(
    BuildContext context,
    PasswordResetRequestModel req,
    UserModel? currentUser,
  ) {
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF5B4CF0)),
            SizedBox(width: 8),
            Text('Regenerate Recovery Code',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to generate a new Recovery Code for "${req.employeeName}" (${req.employeeId})?\n\nThe previous recovery code will be invalidated.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final newCode = await ref
                  .read(passwordResetProvider.notifier)
                  .regenerateRecoveryCode(req, currentUser);

              if (context.mounted && newCode != null) {
                _showRecoveryCodeDialog(
                  context,
                  req.employeeName,
                  req.employeeId,
                  newCode,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Regenerate Code'),
          ),
        ],
      ),
    );
  }

  void _showRecoveryCodeDialog(
    BuildContext context,
    String employeeName,
    String employeeId,
    String recoveryCode,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF5B4CF0), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'New Recovery Code Generated',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new Recovery Code has been generated for $employeeName ($employeeId).',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF474555)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recovery Code',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      recoveryCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4338CA),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFF4338CA)),
                    tooltip: 'Copy Recovery Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: recoveryCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recovery code copied to clipboard!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Share this Recovery Code securely with the employee. It allows them to reset their password via self-service.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF92400E), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Done', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------- REJECT ACTION DIALOG ----------------
  void _handleReject(
    BuildContext context,
    PasswordResetRequestModel req,
    UserModel? currentUser,
  ) {
    if (currentUser == null) return;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Password Reset Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject the request for "${req.employeeName}"?'),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Please contact HR directly for identity verification.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              Navigator.pop(ctx);
              await ref
                  .read(passwordResetProvider.notifier)
                  .rejectResetRequest(req, currentUser, rejectionReason: reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REQUEST CARD ITEM
// ─────────────────────────────────────────────
class _RequestCardItem extends StatelessWidget {
  final PasswordResetRequestModel request;
  final UserModel? currentUser;
  final bool isHighlighted;
  final VoidCallback onCardTap;
  final VoidCallback onApprove;
  final VoidCallback onRegenerateCode;
  final VoidCallback onReject;

  const _RequestCardItem({
    required this.request,
    required this.currentUser,
    this.isHighlighted = false,
    required this.onCardTap,
    required this.onApprove,
    required this.onRegenerateCode,
    required this.onReject,
  });

  String _maskMobile(String? mobile) {
    if (mobile == null || mobile.isEmpty) return 'Not Provided';
    final digits = mobile.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      return '******${digits.substring(digits.length - 4)}';
    }
    return mobile;
  }

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeText;

    final st = request.status.toUpperCase();
    switch (st) {
      case 'PENDING':
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        break;
      case 'IN REVIEW':
      case 'IN_REVIEW':
        badgeBg = const Color(0xFFE0E7FF);
        badgeText = const Color(0xFF4338CA);
        break;
      case 'CONTACTED':
        badgeBg = const Color(0xFFE0F2FE);
        badgeText = const Color(0xFF0369A1);
        break;
      case 'APPROVED':
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF166534);
        break;
      case 'REJECTED':
        badgeBg = const Color(0xFFFEF2F2);
        badgeText = const Color(0xFFDC2626);
        break;
      case 'COMPLETED':
        badgeBg = const Color(0xFFDBEAFE);
        badgeText = const Color(0xFF1E40AF);
        break;
      case 'EXPIRED':
      default:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
        break;
    }

    final isPending = (st == 'PENDING' || st == 'IN REVIEW' || st == 'IN_REVIEW' || st == 'CONTACTED') && !request.isExpired;
    final expiresFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(request.expiresAt);
    final requestTypeLabel = request.requestType == 'RECOVERY_CODE_RESET' ? 'Recovery Code Reset' : 'Password Recovery';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlighted ? const Color(0xFF5B4CF0) : const Color(0xFFE2E8F0),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.status.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          requestTypeLabel.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B4CF0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(request.createdAt),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF5B4CF0), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.employeeName,
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${request.employeeId} ${request.department != null ? "• ${request.department}" : ""} • Mobile: ${_maskMobile(request.registeredMobile)}',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REASON / DESCRIPTION',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.reason,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (isPending) ...[
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: $expiresFormatted (24h validity)',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(Icons.vpn_key_rounded, size: 16),
                            label: const Text('Generate Temp Password', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onRegenerateCode,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Regenerate Code', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B4CF0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject Request', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (st == 'APPROVED') ...[
                if (request.reviewedByName != null)
                  Text(
                    'Approved by ${request.reviewedByName} (${request.reviewedByRole ?? ""}) on ${DateFormat('dd MMM yyyy, hh:mm a').format(request.reviewedAt ?? request.createdAt)}',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                  ),
              ] else if (st == 'REJECTED') ...[
                if (request.rejectionReason != null)
                  Text(
                    'Rejection Reason: ${request.rejectionReason}',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
