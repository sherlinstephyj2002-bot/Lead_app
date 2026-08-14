import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/models/app_notification_model.dart';
import 'package:worktrack/shared/utils/app_validators.dart';
import 'package:worktrack/constants/user_roles.dart';
import 'package:worktrack/constants/feature_flags.dart';
import 'package:worktrack/features/company_admin/models/employee_document_model.dart';
import 'package:worktrack/features/company_admin/providers/company_admin_providers.dart';
import 'package:worktrack/shared/widgets/app_user_avatar.dart';

class EmployeeDocumentsScreen extends ConsumerStatefulWidget {
  final UserModel? employee;
  const EmployeeDocumentsScreen({super.key, this.employee});

  @override
  ConsumerState<EmployeeDocumentsScreen> createState() => _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends ConsumerState<EmployeeDocumentsScreen> {
  String _searchQuery = '';

  static const List<String> _identityDocumentTypes = [
    'Aadhaar',
    'PAN',
    'Passport',
    'Driving License',
  ];

  IconData _getDocumentIcon(String docType) {
    switch (docType.toLowerCase()) {
      case 'aadhaar':
      case 'pan':
        return Icons.badge_rounded;
      case 'passport':
        return Icons.flight_takeoff_rounded;
      case 'driving license':
        return Icons.directions_car_rounded;
      default:
        return Icons.verified_user_rounded;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetEmployee = widget.employee ?? currentUser;

    if (targetEmployee == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Identity & Document Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isManagingSelf = currentUser != null && currentUser.uid == targetEmployee.uid;
    final isHrOrAdmin = currentUser != null &&
        (currentUser.role == UserRoles.companyAdmin ||
            currentUser.role == UserRoles.hrAdmin ||
            currentUser.role == UserRoles.hrExecutive);

    // If Company Admin and no specific employee passed, show company employee selector list
    if (widget.employee == null && currentUser?.role == UserRoles.companyAdmin) {
      return _buildCompanyAdminEmployeeSelectorScreen(context, currentUser!, isDark);
    }

    final docsAsync = ref.watch(adminEmployeeDocumentsProvider(targetEmployee.uid));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isManagingSelf ? 'Identity & Document Details' : '${targetEmployee.name} Documents',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!FeatureFlags.enableDocumentUpload)
              _buildDocumentUploadUnavailableCard(context, isDark),

            // Top Explanation Banner
            _buildExplanationBanner(context, isDark, isManagingSelf),
            const SizedBox(height: 20),

            // Employee Summary Header (if viewing employee as Admin/HR)
            if (!isManagingSelf) ...[
              _buildEmployeeHeaderCard(context, targetEmployee, isDark),
              const SizedBox(height: 20),
            ],

            // Identity Document Cards
            docsAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, _) => Center(child: Text('Error loading document details: $err')),
              data: (docs) {
                final docMap = {for (var d in docs) d.documentType: d};
                return Column(
                  children: _identityDocumentTypes.map((docType) {
                    final existingDoc = docMap[docType];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildIdentityDocumentCard(
                        context: context,
                        docType: docType,
                        doc: existingDoc,
                        targetEmployee: targetEmployee,
                        isManagingSelf: isManagingSelf,
                        isHrOrAdmin: isHrOrAdmin,
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationBanner(BuildContext context, bool isDark, bool isManagingSelf) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_rounded, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identity & Document Details',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isManagingSelf
                      ? 'Enter your official identification details. Please ensure the information matches your original documents for verification.'
                      : 'Review and verify employee official identity numbers and names against official records.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadUnavailableCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF3730A3) : const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_off_rounded, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documents',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Document upload is currently unavailable. This feature will be available in a future update.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeaderCard(BuildContext context, UserModel emp, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).cardColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          AppUserAvatar(user: emp, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${UserModel.denormalizeRole(emp.role)} • ID: ${emp.employeeId ?? "N/A"}',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityDocumentCard({
    required BuildContext context,
    required String docType,
    required EmployeeDocumentModel? doc,
    required UserModel targetEmployee,
    required bool isManagingSelf,
    required bool isHrOrAdmin,
    required bool isDark,
  }) {
    final cardBgColor = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final status = doc?.verificationStatus ?? 'not_provided';
    final docNumber = doc?.documentNumber;
    final nameOnDoc = doc?.nameOnDocument;
    final expiryDate = doc?.expiryDate;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getDocumentIcon(docType), color: const Color(0xFF5B4CF0), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$docType${(docType == "Passport" || docType == "Driving License") ? " (Optional)" : ""}',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                    ),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content Fields
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('$docType Number', _getMaskedDocNumber(docType, docNumber), titleColor),
                const SizedBox(height: 10),
                _buildInfoRow('Name as per $docType', nameOnDoc ?? 'Not Provided', titleColor),
                if (docType == 'Passport' || docType == 'Driving License') ...[
                  const SizedBox(height: 10),
                  _buildInfoRow('Expiry Date', expiryDate != null ? DateFormat('dd MMM yyyy').format(expiryDate) : 'Not Provided', titleColor),
                ],
                if (doc?.rejectionReason != null && doc!.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Correction Required: ${doc.rejectionReason}',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isManagingSelf || isHrOrAdmin)
                  TextButton.icon(
                    onPressed: () => _openEditDetailsDialog(context, docType, targetEmployee, existingDoc: doc),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(docNumber != null ? 'Edit Details' : 'Enter Details',
                        style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                if (isHrOrAdmin && docNumber != null && status != 'verified') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openVerifyDetailsDialog(context, docType, targetEmployee, doc!),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: const Text('Verify Details', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMaskedDocNumber(String docType, String? rawNumber) {
    if (rawNumber == null || rawNumber.trim().isEmpty) return 'Not Provided';
    switch (docType.toLowerCase()) {
      case 'aadhaar':
        return AppValidators.maskAadhaar(rawNumber);
      case 'pan':
        return AppValidators.maskPan(rawNumber);
      default:
        return AppValidators.maskGenericDocument(rawNumber);
    }
  }

  Widget _buildInfoRow(String label, String value, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: titleColor)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'verified':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF10B981);
        label = 'Verified';
        break;
      case 'rejected':
      case 'correction_required':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFEF4444);
        label = 'Correction Required';
        break;
      case 'pending':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFF59E0B);
        label = 'Pending Verification';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'Not Provided';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  void _openEditDetailsDialog(BuildContext context, String docType, UserModel targetEmployee, {EmployeeDocumentModel? existingDoc}) {
    final numberController = TextEditingController(text: existingDoc?.documentNumber ?? '');
    final nameController = TextEditingController(text: existingDoc?.nameOnDocument ?? targetEmployee.name);
    DateTime? selectedExpiry = existingDoc?.expiryDate;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(_getDocumentIcon(docType), color: const Color(0xFF5B4CF0)),
                  const SizedBox(width: 10),
                  Text('$docType Details', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter official information exactly as shown on original $docType.',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      // Document Number Input Field
                      TextFormField(
                        controller: numberController,
                        textCapitalization: docType == 'PAN' ? TextCapitalization.characters : TextCapitalization.none,
                        keyboardType: docType == 'Aadhaar' ? TextInputType.number : TextInputType.text,
                        inputFormatters: [
                          if (docType == 'Aadhaar') ...[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          if (docType == 'PAN') ...[
                            UpperCaseTextFormatter(),
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ],
                        decoration: InputDecoration(
                          labelText: '$docType Number ${(docType == 'Passport' || docType == 'Driving License') ? '(Optional)' : '*'}',
                          hintText: docType == 'Aadhaar' ? '12-digit number' : (docType == 'PAN' ? 'ABCDE1234F' : 'Enter number'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) {
                          if (docType == 'Aadhaar') return AppValidators.validateAadhaar(val);
                          if (docType == 'PAN') return AppValidators.validatePan(val);
                          if (docType == 'Passport') return AppValidators.validatePassport(val, isRequired: false);
                          if (docType == 'Driving License') return AppValidators.validateDrivingLicense(val, isRequired: false);
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Name on Document Input Field
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Name as per $docType ${(docType == 'Passport' || docType == 'Driving License') ? '(Optional)' : '*'}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) => AppValidators.validateNameOnDocument(
                          val,
                          docType,
                          isRequired: docType == 'Aadhaar' || docType == 'PAN',
                        ),
                      ),

                      // Expiry Date (Passport / Driving License)
                      if (docType == 'Passport' || docType == 'Driving License') ...[
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedExpiry ?? DateTime.now().add(const Duration(days: 365 * 3)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedExpiry = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Expiry Date (Optional)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedExpiry != null ? DateFormat('dd MMM yyyy').format(selectedExpiry!) : 'Select Expiry Date',
                                  style: TextStyle(fontFamily: 'Inter', color: selectedExpiry != null ? Colors.black : Colors.grey),
                                ),
                                const Icon(Icons.calendar_today_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4CF0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final docNumber = numberController.text.trim();
                    final nameOnDoc = nameController.text.trim();

                    final newDoc = EmployeeDocumentModel(
                      documentId: existingDoc?.documentId ?? const Uuid().v4(),
                      companyId: targetEmployee.companyId,
                      employeeId: targetEmployee.uid,
                      documentType: docType,
                      documentName: '$docType Details',
                      storagePath: '',
                      fileUrl: '',
                      uploadedBy: ref.read(authProvider).user?.uid ?? '',
                      uploadedAt: DateTime.now(),
                      documentNumber: docNumber,
                      nameOnDocument: nameOnDoc,
                      verificationStatus: 'pending',
                      expiryDate: selectedExpiry,
                    );

                    Navigator.pop(ctx);

                    try {
                      await ref.read(adminEmployeeDocumentsProvider(targetEmployee.uid).notifier).saveDocument(newDoc);
                      _showSnackBar('$docType details saved successfully.');
                    } catch (e) {
                      _showSnackBar('Failed to save document details: $e', isError: true);
                    }
                  },
                  child: const Text('Save Details'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openVerifyDetailsDialog(BuildContext context, String docType, UserModel targetEmployee, EmployeeDocumentModel doc) {
    final remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Verify $docType Details', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Employee: ${targetEmployee.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('$docType Number: ${doc.documentNumber ?? "N/A"}'),
              Text('Name on Document: ${doc.nameOnDocument ?? "N/A"}'),
              if (doc.expiryDate != null) Text('Expiry Date: ${DateFormat("dd MMM yyyy").format(doc.expiryDate!)}'),
              const SizedBox(height: 16),
              TextField(
                controller: remarkController,
                decoration: const InputDecoration(
                  labelText: 'Verification / Correction Remarks',
                  hintText: 'Enter reason if correction is required',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final remark = remarkController.text.trim();
                final reason = remark.isEmpty ? 'Document number could not be verified. Please check details.' : remark;
                Navigator.pop(ctx);
                try {
                  await ref.read(adminEmployeeDocumentsProvider(targetEmployee.uid).notifier).rejectDocument(doc.documentId, reason);

                  final notif = AppNotificationModel(
                    notificationId: const Uuid().v4(),
                    companyId: targetEmployee.companyId,
                    title: '$docType Details Correction Required',
                    body: 'Your $docType details require correction. Reason: $reason',
                    notificationType: 'DOCUMENT_REJECTED',
                    isRead: false,
                    createdAt: DateTime.now(),
                    targetType: 'USER',
                    targetUserId: targetEmployee.uid,
                    relatedModule: 'EMPLOYEE',
                    relatedEntityId: doc.documentId,
                  );
                  await ref.read(userRepositoryProvider).createNotification(notif);

                  _showSnackBar('Marked $docType as correction required.', isError: true);
                } catch (e) {
                  _showSnackBar('Error updating verification status: $e', isError: true);
                }
              },
              child: const Text('Request Correction'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(adminEmployeeDocumentsProvider(targetEmployee.uid).notifier).approveDocument(doc.documentId);
                  _showSnackBar('$docType verified successfully!');
                } catch (e) {
                  _showSnackBar('Error verifying document: $e', isError: true);
                }
              },
              child: const Text('Mark as Verified'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompanyAdminEmployeeSelectorScreen(BuildContext context, UserModel adminUser, bool isDark) {
    final employeesAsync = ref.watch(companyEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Document Directory', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter & Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search employee name or ID...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading employees: $e')),
              data: (employees) {
                final filtered = employees.where((emp) {
                  if (emp.role == UserRoles.companyAdmin) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty &&
                      !emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
                      !(emp.employeeId?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No employees found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final emp = filtered[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        leading: AppUserAvatar(user: emp, radius: 20),
                        title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                        subtitle: Text('${UserModel.denormalizeRole(emp.role)} • ID: ${emp.employeeId ?? "N/A"}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EmployeeDocumentsScreen(employee: emp)),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
