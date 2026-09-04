import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/company_model.dart';
import '../../../shared/models/department_model.dart';
import '../../company_admin/models/branch_model.dart';
import '../../company_admin/models/designation_model.dart';
import '../../company_admin/models/role_model.dart';
import '../../company_admin/models/shift_model.dart';
import '../../company_admin/models/holiday_model.dart';
import '../../company_admin/providers/company_admin_providers.dart';
import '../../../constants/feature_flags.dart';
import '../../../shared/utils/shift_duration_calculator.dart';
import '../../../shared/widgets/multi_select_department_dropdown.dart';
import '../../../shared/utils/app_notification.dart';
import '../../../shared/widgets/searchable_dropdown.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isInitialized = false;

  List<int> get _availableSteps {
    return [
      0, // Profile
      if (FeatureFlags.enableBranchManagement) 1, // Branches
      2, // Departments
      3, // Designations
      7, // Roles & Permissions
      4, // Shifts
      5, // Holidays
      6, // Review
    ];
  }

  // Step 1: Profile Form Fields
  final _formKeyProfile = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  String? _logoUrl;

  String _timeZone = 'UTC+05:30 — India Standard Time';
  String _currency = 'INR';
  List<String> _selectedWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  final List<String> _commonCurrencies = ['INR', 'USD', 'EUR', 'GBP', 'AUD', 'CAD', 'SGD', 'AED', 'JPY', 'CNY'];
  final List<String> _commonTimeZones = [
    'UTC+05:30 — India Standard Time',
    'UTC+05:30 (India)',
    'UTC+00:00 (GMT/UTC)',
    'UTC-05:00 (EST)',
    'UTC-08:00 (PST)',
    'UTC+01:00 (CET)',
    'UTC+04:00 (GST - Dubai)',
    'UTC+08:00 (SGT - Singapore)',
    'UTC+09:00 (JST - Tokyo)'
  ];
  final List<String> _weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // Initialize Step 1 controllers with existing company info
  void _initFields(CompanyModel company) {
    if (_isInitialized) return;
    _nameController.text = company.name;
    _addressController.text = company.address;
    _countryController.text = company.country;
    _stateController.text = company.state;
    _cityController.text = company.city;
    _logoUrl = company.logoUrl;
    final rawTz = company.timeZone.isNotEmpty ? company.timeZone : 'UTC+05:30 — India Standard Time';
    _timeZone = _commonTimeZones.contains(rawTz)
        ? rawTz
        : (_commonTimeZones.firstWhere((tz) => tz.contains('05:30') || tz.contains('India'), orElse: () => _commonTimeZones.first));
    final rawCurr = company.currency.isNotEmpty ? company.currency : 'INR';
    _currency = _commonCurrencies.contains(rawCurr) ? rawCurr : _commonCurrencies.first;
    _selectedWorkingDays = List<String>.from(company.workingDays);
    final available = _availableSteps;
    int dbStep = company.setupWizardStep;
    int index = available.indexOf(dbStep);
    if (index == -1) {
      index = available.indexWhere((s) => s >= dbStep);
      if (index == -1) index = available.length - 1;
    }
    _currentStep = index;
    _isInitialized = true;
  }

  // Helper mapping from category name to icon
  IconData _getStepIcon(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return Icons.business_rounded;
      case 1:
        return Icons.location_city_rounded;
      case 2:
        return Icons.business_center_rounded;
      case 3:
        return Icons.badge_outlined;
      case 7:
        return Icons.security_rounded;
      case 4:
        return Icons.schedule_rounded;
      case 5:
        return Icons.calendar_today_rounded;
      default:
        return Icons.verified_user_outlined;
    }
  }

  String _getStepTitle(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return 'Company Profile';
      case 1:
        return 'Configure Branches';
      case 2:
        return 'Configure Departments';
      case 3:
        return 'Configure Designations';
      case 7:
        return 'Roles & Permissions';
      case 4:
        return 'Work Shifts';
      case 5:
        return 'Holiday Calendar';
      default:
        return 'Review & Finish';
    }
  }

  // Handle logo image upload to Firebase Storage
  Future<void> _uploadLogo() async {
    if (!FeatureFlags.enableImageUpload) {
      _showSnackBar('File upload is currently disabled.', isError: true);
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;
      final company = ref.read(companyProvider).value;
      if (company == null) return;

      final storagePath = 'companies/${company.companyId}/logo_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final uploadTask = await FirebaseStorage.instance.ref(storagePath).putData(fileBytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() {
        _logoUrl = downloadUrl;
      });
      _showSnackBar('Logo uploaded successfully.');
    } catch (e) {
      _showSnackBar('Failed to upload logo: $e', isError: true);
    } finally {
      setState(() => _isUploadingLogo = false);
    }
  }

  // Save current step progress and move to next step
  Future<void> _handleNext(CompanyModel company) async {
    final available = _availableSteps;
    if (available[_currentStep] == 0) {
      // Validate Step 1 Form
      if (!_formKeyProfile.currentState!.validate()) return;
      if (_selectedWorkingDays.isEmpty) {
        _showSnackBar('Please select at least one working day.', isError: true);
        return;
      }

      setState(() => _isSaving = true);
      try {
        final nextDbStep = available[1];
        final updatedCompany = company.copyWith(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          country: _countryController.text.trim(),
          state: _stateController.text.trim(),
          city: _cityController.text.trim(),
          logoUrl: _logoUrl,
          timeZone: _timeZone,
          currency: _currency,
          workingDays: _selectedWorkingDays,
          setupWizardStep: nextDbStep,
        );

        await ref.read(companyProvider.notifier).updateCompany(updatedCompany);
        setState(() {
          _currentStep = 1;
        });
      } catch (e) {
        _showSnackBar('Failed to save company profile: $e', isError: true);
      } finally {
        setState(() => _isSaving = false);
      }
    } else {
      // For CRUD steps (1-5 which maps to Steps 2-6), simply increment local step and update setupWizardStep in Firestore
      setState(() => _isSaving = true);
      try {
        final nextStepIndex = _currentStep + 1;
        final nextDbStep = nextStepIndex < available.length ? available[nextStepIndex] : 7;
        final updatedCompany = company.copyWith(
          setupWizardStep: nextDbStep,
        );
        await ref.read(companyProvider.notifier).updateCompany(updatedCompany);
        setState(() {
          _currentStep = nextStepIndex;
        });
      } catch (e) {
        _showSnackBar('Failed to update progress: $e', isError: true);
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  // Complete Onboarding Wizard (Step 7 Finish)
  Future<void> _completeWizard(CompanyModel company) async {
    setState(() => _isSaving = true);
    try {
      final updatedCompany = company.copyWith(
        isSetupCompleted: true,
        setupWizardStep: 7,
      );

      await ref.read(companyProvider.notifier).updateCompany(updatedCompany);

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Company setup completed successfully!');
      }
    } catch (e) {
      _showSnackBar('Failed to complete onboarding: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Skip wizard or close dialog
  void _skipWizard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Continue Setup Later?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'You can exit the setup wizard now and resume configuring the branches, shifts, and configurations later from your Home Dashboard.',
          style: TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close Wizard
            },
            child: const Text('Exit Wizard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppNotification.showError(context, message);
    } else {
      AppNotification.showSuccess(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider);

    return companyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red)))),
      data: (company) {
        if (company != null) {
          _initFields(company);
        } else {
          return const Scaffold(body: Center(child: Text('No company details found.')));
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(_getStepTitle(_availableSteps[_currentStep]), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _currentStep > 0
                  ? () {
                      setState(() {
                        _currentStep--;
                      });
                    }
                  : () => _skipWizard(),
            ),
            actions: [
              TextButton(
                onPressed: _skipWizard,
                child: const Text('Skip & Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildStepContent(company),
                    ),
                  ),
                ),
              ),
              _buildNavigationButtons(company),
            ],
          ),
        );
      },
    );
  }

  // Premium Top Step Progress Indicator
  Widget _buildProgressIndicator() {
    final available = _availableSteps;
    final totalSteps = available.length;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;
          final isLast = index == totalSteps - 1;
          final stepVal = available[index];

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green
                              : (isActive ? Theme.of(context).primaryColor : Colors.grey[200]),
                          shape: BoxShape.circle,
                          border: isActive
                              ? Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2), width: 3)
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : Icon(
                                  _getStepIcon(stepVal),
                                  color: isActive || isCompleted ? Colors.white : Colors.grey[500],
                                  size: 14,
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Step ${index + 1}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Theme.of(context).primaryColor : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 20,
                    height: 2,
                    color: isCompleted ? Colors.green : Colors.grey[300],
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // Stepper content switch
  Widget _buildStepContent(CompanyModel company) {
    final available = _availableSteps;
    final stepVal = _currentStep < available.length ? available[_currentStep] : 0;
    switch (stepVal) {
      case 0:
        return _buildStep1Profile();
      case 1:
        return _buildStep2Branches(company);
      case 2:
        return _buildStep3Departments(company);
      case 3:
        return _buildStep4Designations(company);
      case 7:
        return _buildRolesAndPermissionsStep(company);
      case 4:
        return _buildStep5Shifts(company);
      case 5:
        return _buildStep6Holidays(company);
      case 6:
        return _buildStep7Review(company);
      default:
        return _buildStep1Profile();
    }
  }

  // ==========================================
  // ROLES & PERMISSIONS STEP (STEP 7)
  // ==========================================
  Widget _buildRolesAndPermissionsStep(CompanyModel company) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('roles')
          .where('companyId', isEqualTo: company.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final customRoles = docs.map((d) {
          final data = d.data();
          return {
            'roleId': d.id,
            'roleName': data['roleName'] ?? '',
            'description': data['description'] ?? '',
            'createdAt': data['createdAt'],
          };
        }).toList();

        return Card(
          elevation: 0,
          color: isDark ? Theme.of(context).cardColor : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Roles & Permissions Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                          const SizedBox(height: 4),
                          Text('Create custom operational roles based on your company\'s actual organizational structure.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showWizardRoleDialog(company.companyId),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Custom Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4CF0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (customRoles.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B4CF0).withValues(alpha: isDark ? 0.15 : 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5B4CF0).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.security_rounded, size: 36, color: Color(0xFF5B4CF0)),
                        const SizedBox(height: 10),
                        Text(
                          'No custom roles created yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create roles like "Tech Lead", "Team Lead", "Senior Analyst", "Sales Executive", etc. and assign appropriate permissions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () => _showWizardRoleDialog(company.companyId),
                          icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF5B4CF0)),
                          label: const Text('Create First Role', style: TextStyle(color: Color(0xFF5B4CF0), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF5B4CF0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customRoles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = customRoles[index];
                      final roleId = r['roleId'] as String;
                      final roleName = r['roleName'] as String;
                      final desc = r['description'] as String;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5B4CF0).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF5B4CF0), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(roleName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit')),
                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(desc, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontFamily: 'Outfit')),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFFF59E0B), size: 18),
                                  onPressed: () => _showWizardRoleDialog(company.companyId, existingRole: r),
                                  tooltip: 'Edit Role',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                  onPressed: () => _deleteWizardRoleConfirm(roleId, roleName),
                                  tooltip: 'Delete Role',
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWizardRoleDialog(String companyId, {Map<String, dynamic>? existingRole}) async {
    final isEdit = existingRole != null;
    final roleId = isEdit ? existingRole['roleId'] as String : const Uuid().v4();
    final nameCtrl = TextEditingController(text: existingRole != null ? existingRole['roleName'] : '');
    final descCtrl = TextEditingController(text: existingRole != null ? existingRole['description'] : '');
    final formKey = GlobalKey<FormState>();

    final deptsAsync = ref.read(adminDepartmentsProvider);
    final desigsAsync = ref.read(adminDesignationsProvider);

    final depts = (deptsAsync.value ?? []).where((d) => d.status == 'active').toList();
    final allDesigs = (desigsAsync.value ?? []).where((d) => d.status == 'active').toList();

    final rawDeptIds = existingRole != null ? (existingRole['departmentIds'] as List? ?? [existingRole['departmentId']]) : [];
    final rawDesigIds = existingRole != null ? (existingRole['designationIds'] as List? ?? [existingRole['designationId']]) : [];

    List<DepartmentModel> selectedDepts = depts.where((d) => rawDeptIds.contains(d.departmentId)).toList();
    List<DesignationModel> selectedDesigs = allDesigs.where((d) => rawDesigIds.contains(d.designationId)).toList();

    // Modules permission map
    final Map<String, List<Map<String, String>>> modules = {
      'EMPLOYEES': [
        {'id': 'employee_view', 'name': 'View Employees'},
        {'id': 'employee_create', 'name': 'Create Employees'},
        {'id': 'employee_edit', 'name': 'Edit Employees'},
        {'id': 'employee_delete', 'name': 'Delete Employees'},
      ],
      'LEADS': [
        {'id': 'lead_view', 'name': 'View Leads'},
        {'id': 'lead_create', 'name': 'Create Leads'},
        {'id': 'lead_edit', 'name': 'Edit Leads'},
        {'id': 'lead_delete', 'name': 'Delete Leads'},
        {'id': 'lead_convert_order', 'name': 'Convert Leads'},
      ],
      'ORDERS': [
        {'id': 'order_view', 'name': 'View Orders'},
        {'id': 'order_create', 'name': 'Create Orders'},
        {'id': 'order_edit', 'name': 'Edit Orders'},
        {'id': 'order_delete', 'name': 'Delete Orders'},
        {'id': 'order_close', 'name': 'Close Orders'},
        {'id': 'order_cancel', 'name': 'Cancel Orders'},
      ],
      'ATTENDANCE': [
        {'id': 'attendance_view', 'name': 'View Attendance'},
        {'id': 'attendance_approve', 'name': 'Approve Attendance'},
        {'id': 'attendance_correct', 'name': 'Correct Attendance'},
      ],
      'PAYROLL': [
        {'id': 'payroll_view', 'name': 'View Payroll'},
        {'id': 'payroll_generate', 'name': 'Generate Payroll'},
        {'id': 'payroll_approve', 'name': 'Approve Payroll'},
        {'id': 'payroll_manage', 'name': 'Manage Payroll'},
      ],
      'REPORTS': [
        {'id': 'reports_view', 'name': 'View Reports'},
        {'id': 'reports_export', 'name': 'Export Reports'},
      ],
      'COMPANY ADMINISTRATION': [
        {'id': 'department_create', 'name': 'Manage Departments'},
        {'id': 'designation_create', 'name': 'Manage Designations'},
        {'id': 'settings_manage', 'name': 'Settings Administration'},
      ],
      'TASKS': [
        {'id': 'task_view', 'name': 'View Tasks'},
        {'id': 'task_create', 'name': 'Create Tasks'},
        {'id': 'task_edit', 'name': 'Edit Tasks'},
        {'id': 'task_delete', 'name': 'Delete Tasks'},
        {'id': 'task_assign', 'name': 'Assign Tasks'},
      ],
      'FOLLOW-UPS': [
        {'id': 'followup_view', 'name': 'View Follow-ups'},
        {'id': 'followup_create', 'name': 'Create Follow-ups'},
        {'id': 'followup_edit', 'name': 'Edit Follow-ups'},
        {'id': 'followup_complete', 'name': 'Complete Follow-ups'},
      ],
    };

    List<String> selectedPermissions = [];

    if (isEdit) {
      final permsSnap = await FirebaseFirestore.instance
          .collection('role_permissions')
          .where('roleId', isEqualTo: roleId)
          .get();
      selectedPermissions = permsSnap.docs.map((d) => d.data()['permissionId'] as String).toList();
    } else {
      selectedPermissions = ['employee_view', 'attendance_view', 'leave_apply'];
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final availableDesigs = selectedDepts.isEmpty
              ? <DesignationModel>[]
              : allDesigs.where((desig) {
                  return selectedDepts.any((dept) =>
                      desig.applicableDepartmentIds.contains(dept.departmentId) ||
                      desig.departmentId == dept.departmentId ||
                      desig.applicableDepartmentIds.isEmpty);
                }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEdit ? 'Edit Custom Role' : 'Create Custom Role', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 550,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Organizational Hierarchy',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B4CF0)),
                      ),
                      const SizedBox(height: 10),

                      // STEP 1: Select Department(s)
                      SearchableMultiSelectDropdown<DepartmentModel>(
                        label: 'Departments *',
                        hint: 'Select Department(s)',
                        icon: Icons.business_center_rounded,
                        items: depts,
                        selectedItems: selectedDepts,
                        itemAsString: (d) => d.departmentName,
                        itemAsSubTitle: (d) => d.departmentCode,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedDepts = val;
                            final validDesigIds = availableDesigs.map((d) => d.designationId).toSet();
                            selectedDesigs.removeWhere((d) => !validDesigIds.contains(d.designationId));
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // STEP 2: Select Designation(s)
                      SearchableMultiSelectDropdown<DesignationModel>(
                        label: 'Designations *',
                        hint: selectedDepts.isEmpty ? 'Select Department first' : 'Select Designation(s)',
                        icon: Icons.badge_outlined,
                        enabled: selectedDepts.isNotEmpty,
                        items: availableDesigs,
                        selectedItems: selectedDesigs,
                        itemAsString: (d) => d.designationName,
                        onChanged: (val) {
                          setDialogState(() {
                            selectedDesigs = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // STEP 3: Role Name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Role Name *', hintText: 'e.g. Field Technician, Sales Manager'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Role Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Permissions by Module:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit', color: Color(0xFF5B4CF0))),
                      const SizedBox(height: 8),
                      ...modules.keys.map((modName) {
                        final modPerms = modules[modName]!;
                        final modIds = modPerms.map((p) => p['id']!).toList();
                        final allSelected = modIds.every((id) => selectedPermissions.contains(id));

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(modName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                                  TextButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        if (allSelected) {
                                          selectedPermissions.removeWhere((id) => modIds.contains(id));
                                        } else {
                                          for (final id in modIds) {
                                            if (!selectedPermissions.contains(id)) {
                                              selectedPermissions.add(id);
                                            }
                                          }
                                        }
                                      });
                                    },
                                    child: Text(allSelected ? 'Clear' : 'Select All', style: const TextStyle(fontSize: 10, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: modPerms.map((p) {
                                  final pId = p['id']!;
                                  final isChecked = selectedPermissions.contains(pId);
                                  return FilterChip(
                                    label: Text(p['name']!, style: TextStyle(fontSize: 11, fontFamily: 'Outfit', color: isChecked ? Colors.white : const Color(0xFF1E293B))),
                                    selected: isChecked,
                                    selectedColor: const Color(0xFF5B4CF0),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    onSelected: (val) {
                                      setDialogState(() {
                                        if (val) {
                                          selectedPermissions.add(pId);
                                        } else {
                                          selectedPermissions.remove(pId);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  if (selectedDepts.isEmpty) {
                    _showSnackBar('Please select at least one Department.', isError: true);
                    return;
                  }
                  if (selectedDesigs.isEmpty) {
                    _showSnackBar('Please select at least one Designation.', isError: true);
                    return;
                  }
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);
                    final deptIds = selectedDepts.map((d) => d.departmentId).toList();
                    final desigIds = selectedDesigs.map((d) => d.designationId).toList();
                    await _saveWizardRole(companyId, roleId, nameCtrl.text.trim(), deptIds, desigIds, selectedPermissions);
                  }
                },
                child: const Text('Save Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveWizardRole(String companyId, String roleId, String name, List<String> deptIds, List<String> desigIds, List<String> permissions) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final orgAssignments = <Map<String, String>>[];
      for (final dId in deptIds) {
        for (final dsId in desigIds) {
          orgAssignments.add({'departmentId': dId, 'designationId': dsId});
        }
      }

      batch.set(db.collection('roles').doc(roleId), {
        'roleId': roleId,
        'companyId': companyId,
        'roleName': name,
        'departmentId': deptIds.isNotEmpty ? deptIds.first : '',
        'designationId': desigIds.isNotEmpty ? desigIds.first : '',
        'departmentIds': deptIds,
        'designationIds': desigIds,
        'organizationalAssignments': orgAssignments,
        'description': '',
        'isSystemRole': false,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear existing mappings
      final existingPerms = await db.collection('role_permissions').where('roleId', isEqualTo: roleId).get();
      for (final doc in existingPerms.docs) {
        batch.delete(doc.reference);
      }

      // Add new mappings
      for (final permId in permissions) {
        final docId = '${roleId}_$permId';
        batch.set(db.collection('role_permissions').doc(docId), {
          'roleId': roleId,
          'permissionId': permId,
        });
      }

      await batch.commit();
      _showSnackBar('Custom role "$name" saved successfully.');
    } catch (e) {
      _showSnackBar('Failed to save custom role: $e', isError: true);
    }
  }

  Future<void> _deleteWizardRoleConfirm(String roleId, String roleName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Custom Role', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Text('Delete role "$roleName"?', style: const TextStyle(fontFamily: 'Outfit')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.delete(db.collection('roles').doc(roleId));

      final mappings = await db.collection('role_permissions').where('roleId', isEqualTo: roleId).get();
      for (final doc in mappings.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _showSnackBar('Custom role deleted.');
    }
  }

  // STEP 1 - Profile Details Form
  Widget _buildStep1Profile() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKeyProfile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Company Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFEFF6FF),
                          backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                          child: _logoUrl == null
                              ? Icon(Icons.business_rounded, size: 50, color: Colors.blue[300])
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            radius: 16,
                            child: _isUploadingLogo
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : IconButton(
                                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                    onPressed: _uploadLogo,
                                    padding: EdgeInsets.zero,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Company Logo', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Company Address *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City / Town *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'City / Town is required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(labelText: 'State / Province / Region'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'Country / Region *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Country / Region is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _commonTimeZones.contains(_timeZone) ? _timeZone : _commonTimeZones.first,
                decoration: const InputDecoration(
                  labelText: 'Time Zone *',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                items: _commonTimeZones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _timeZone = val);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _commonCurrencies.contains(_currency) ? _currency : _commonCurrencies.first,
                decoration: const InputDecoration(
                  labelText: 'Currency *',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
                items: _commonCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _currency = val);
                },
              ),
              const SizedBox(height: 20),
              const Text('Configure Working Days *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekDays.map((day) {
                  final isSelected = _selectedWorkingDays.contains(day);
                  return FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: isSelected,
                    selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Theme.of(context).primaryColor : const Color(0xFF64748B),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedWorkingDays.add(day);
                        } else {
                          _selectedWorkingDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 2 - Branches Management List
  Widget _buildStep2Branches(CompanyModel company) {
    final branchesAsync = ref.watch(adminBranchesProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Branches configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              onPressed: () => _showBranchFormDialog(company.companyId),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Branch', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        branchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading branches: $err', style: const TextStyle(color: Colors.red))),
          data: (branches) {
            final activeBranches = branches.where((b) => b.status == 'active').toList();
            if (activeBranches.isEmpty) {
              return _buildEmptyStateCard(
                icon: Icons.location_city_rounded,
                title: 'No branches added',
                description: 'Add your corporate office branch locations to manage employee geolocations.',
                onAddPressed: () => _showBranchFormDialog(company.companyId),
                buttonText: 'Add First Branch',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeBranches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final b = activeBranches[index];
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.location_on, color: Colors.blue),
                    ),
                    title: Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Code: ${b.branchCode} • ${b.city}, ${b.state}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                          onPressed: () => _showBranchFormDialog(company.companyId, branch: b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive_outlined, size: 18, color: Colors.red),
                          onPressed: () => _archiveBranchConfirm(b),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // STEP 3 - Departments Management List
  Widget _buildStep3Departments(CompanyModel company) {
    final deptsAsync = ref.watch(adminDepartmentsProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Departments configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              onPressed: () => _showDepartmentFormDialog(company.companyId),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Dept', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        deptsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading departments: $err', style: const TextStyle(color: Colors.red))),
          data: (depts) {
            final activeDepts = depts.where((d) => d.status == 'active').toList();
            if (activeDepts.isEmpty) {
              return _buildEmptyStateCard(
                icon: Icons.business_center_rounded,
                title: 'No departments added',
                description: 'Define departments (e.g. Sales, HR, Engineering) to categorize employee profiles.',
                onAddPressed: () => _showDepartmentFormDialog(company.companyId),
                buttonText: 'Add Department',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeDepts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final d = activeDepts[index];
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF7ED),
                      child: Icon(Icons.corporate_fare, color: Colors.orange),
                    ),
                    title: Text(d.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                          onPressed: () => _showDepartmentFormDialog(company.companyId, department: d),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _deleteDeptConfirm(d),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // STEP 4 - Designations Management List
  Widget _buildStep4Designations(CompanyModel company) {
    final designationsAsync = ref.watch(adminDesignationsProvider);
    final deptsAsync = ref.watch(adminDepartmentsProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Designations configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              onPressed: () {
                final activeDepts = (deptsAsync.value ?? []).where((d) => d.status == 'active').toList();
                if (activeDepts.isEmpty) {
                  _showSnackBar('Please add at least one department first.', isError: true);
                } else {
                  _showDesignationFormDialog(company.companyId, activeDepts);
                }
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Desig', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        designationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading designations: $err', style: const TextStyle(color: Colors.red))),
          data: (designations) {
            final activeDesigs = designations.where((d) => d.status == 'active').toList();
            if (activeDesigs.isEmpty) {
              return _buildEmptyStateCard(
                icon: Icons.badge_outlined,
                title: 'No designations added',
                description: 'Add corporate hierarchy designations (e.g. Sales Associate, Tech Lead, Director).',
                onAddPressed: () {
                  final activeDepts = (deptsAsync.value ?? []).where((d) => d.status == 'active').toList();
                  if (activeDepts.isEmpty) {
                    _showSnackBar('Please add at least one department first.', isError: true);
                  } else {
                    _showDesignationFormDialog(company.companyId, activeDepts);
                  }
                },
                buttonText: 'Add Designation',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeDesigs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final desig = activeDesigs[index];
                final dept = (deptsAsync.value ?? [])
                    .cast<DepartmentModel?>()
                    .firstWhere((d) => d!.departmentId == desig.departmentId,
                        orElse: () => null);
                final deptName = dept?.departmentName ?? 'Unknown';

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFECFDF5),
                      child: FeatureFlags.enableDesignationLevels
                          ? Text('${desig.designationLevel}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                          : const Icon(Icons.badge_outlined, color: Colors.green, size: 18),
                    ),
                    title: Text(desig.designationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      FeatureFlags.enableDesignationLevels
                          ? 'Department: $deptName • Level: ${desig.designationLevel}'
                          : 'Department: $deptName',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                          onPressed: () {
                            final activeDepts = (deptsAsync.value ?? []).where((d) => d.status == 'active').toList();
                            _showDesignationFormDialog(company.companyId, activeDepts, designation: desig);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _deleteDesigConfirm(desig),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // STEP 5 - Work Shifts Management List
  Widget _buildStep5Shifts(CompanyModel company) {
    final shiftsAsync = ref.watch(adminShiftsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Work Shifts configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              onPressed: () => _showShiftFormDialog(company.companyId),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Shift', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        shiftsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading shifts: $err', style: const TextStyle(color: Colors.red))),
          data: (shifts) {
            final activeShifts = shifts.where((s) => s.status == 'active').toList();
            if (activeShifts.isEmpty) {
              return _buildEmptyStateCard(
                icon: Icons.schedule_rounded,
                title: 'No shifts configured',
                description: 'Define your office timing shifts (e.g. Morning Shift, Night Shift) for logging check-ins.',
                onAddPressed: () => _showShiftFormDialog(company.companyId),
                buttonText: 'Add First Shift',
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeShifts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final s = activeShifts[index];
                final isDarkCard = Theme.of(context).brightness == Brightness.dark;
                final titleColor = isDarkCard ? Colors.white : const Color(0xFF1E293B);
                final borderCol = isDarkCard ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkCard ? Theme.of(context).cardColor : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B4CF0).withValues(alpha: isDarkCard ? 0.2 : 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.schedule_rounded, color: Color(0xFF5B4CF0), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.shiftName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                                  Text(s.shiftCode, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDarkCard ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                                onPressed: () => _showShiftFormDialog(company.companyId, shift: s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _deleteShiftConfirm(s),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Details: Timings, Break, Working Hours, OT Limit
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF6366F1)),
                              const SizedBox(width: 4),
                              Text('${s.startTime} – ${s.endTime}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.coffee_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 4),
                              Text(
                                'Break: ${s.breakDurationMinutes >= 60 && s.breakDurationMinutes % 60 == 0 ? "${s.breakDurationMinutes ~/ 60} ${s.breakDurationMinutes ~/ 60 == 1 ? "Hour" : "Hours"}" : "${s.breakDurationMinutes} Mins"}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDarkCard ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_rounded, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text('Working Hours: ${s.workingHours.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')} Hours', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFFEC4899)),
                              const SizedBox(width: 4),
                              Text(
                                'OT Limit: ${s.overtimeAllowed ? ShiftDurationCalculator.formatHoursShort(s.otLimitHours) : "Disabled"}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: s.overtimeAllowed ? const Color(0xFFEC4899) : const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Breakdown banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkCard ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Regular Hours', style: TextStyle(fontSize: 9, color: isDarkCard ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 1),
                                Text(ShiftDurationCalculator.formatHoursShort(s.workingHours), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Maximum OT', style: TextStyle(fontSize: 9, color: isDarkCard ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                const SizedBox(height: 1),
                                Text(
                                  s.overtimeAllowed ? ShiftDurationCalculator.formatHoursShort(s.otLimitHours) : 'Disabled',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: s.overtimeAllowed ? const Color(0xFFEC4899) : const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Max Total Working Time', style: TextStyle(fontSize: 9, color: isDarkCard ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                                const SizedBox(height: 1),
                                Text(
                                  ShiftDurationCalculator.formatHoursShort(s.maxTotalWorkingTimeHours),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5B4CF0)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // STEP 6 - Holidays Management List
  Widget _buildStep6Holidays(CompanyModel company) {
    final holidaysAsync = ref.watch(adminHolidaysProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Holidays configured', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              onPressed: () => _showHolidayFormDialog(company.companyId),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Holiday', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        holidaysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading holidays: $err', style: const TextStyle(color: Colors.red))),
          data: (holidays) {
            final activeHolidays = holidays.where((h) => h.status == 'active').toList();
            if (activeHolidays.isEmpty) {
              return _buildEmptyStateCard(
                icon: Icons.calendar_today_rounded,
                title: 'No holidays added',
                description: 'Configure company holidays (e.g. New Year, Independence Day) so salary and leave rules align.',
                onAddPressed: () => _showHolidayFormDialog(company.companyId),
                buttonText: 'Add First Holiday',
              );
            }

            // Sort holidays by date
            activeHolidays.sort((a, b) => a.holidayDate.compareTo(b.holidayDate));

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeHolidays.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final h = activeHolidays[index];
                final dateStr = DateFormat('dd MMM yyyy').format(h.holidayDate);
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF2F2),
                      child: Icon(Icons.event, color: Colors.red),
                    ),
                    title: Text(h.holidayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('$dateStr • Type: ${h.holidayType}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
                          onPressed: () => _showHolidayFormDialog(company.companyId, holiday: h),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _deleteHolidayConfirm(h),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // STEP 7 - Review & Finish
  Widget _buildStep7Review(CompanyModel company) {
    final branches = ref.watch(adminBranchesProvider).value ?? [];
    final depts = ref.watch(adminDepartmentsProvider).value ?? [];
    final designations = ref.watch(adminDesignationsProvider).value ?? [];
    final shifts = ref.watch(adminShiftsProvider).value ?? [];
    final holidays = ref.watch(adminHolidaysProvider).value ?? [];

    final activeBranchesCount = branches.where((b) => b.status == 'active').length;
    final activeDeptsCount = depts.where((d) => d.status == 'active').length;
    final activeDesigsCount = designations.where((d) => d.status == 'active').length;
    final activeShiftsCount = shifts.where((s) => s.status == 'active').length;
    final activeHolidaysCount = holidays.where((h) => h.status == 'active').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Column(
            children: [
              Icon(Icons.stars_rounded, size: 70, color: Colors.green),
              SizedBox(height: 12),
              Text(
                'Almost Done!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1E293B)),
              ),
              SizedBox(height: 4),
              Text(
                'Review your company configurations below before finishing setup.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Review Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 24),
                _buildSummaryRow(Icons.business, 'Company Name', company.name),
                _buildSummaryRow(Icons.map_outlined, 'Address', '${company.address}, ${company.city}, ${company.state}, ${company.country}'),
                _buildSummaryRow(Icons.public, 'Time Zone', company.timeZone),
                _buildSummaryRow(Icons.monetization_on_outlined, 'Currency', company.currency),
                _buildSummaryRow(Icons.calendar_today, 'Working Days', company.workingDays.join(', ')),
                const Divider(height: 24),
                if (FeatureFlags.enableBranchManagement)
                  _buildSummaryStatRow(Icons.location_city_rounded, 'Branches Configured', activeBranchesCount),
                _buildSummaryStatRow(Icons.business_center, 'Departments Configured', activeDeptsCount),
                _buildSummaryStatRow(Icons.badge_outlined, 'Designations Configured', activeDesigsCount),
                _buildSummaryStatRow(Icons.schedule, 'Shifts Defined', activeShiftsCount),
                _buildSummaryStatRow(Icons.celebration_rounded, 'Public Holidays Added', activeHolidaysCount),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.green[800] : Colors.blueGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onAddPressed,
    required String buttonText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.4)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add_circle_outline, size: 14),
            label: Text(buttonText, style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(CompanyModel company) {
    final isLastStep = _currentStep == _availableSteps.length - 1;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                  child: const Text('Back'),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _skipWizard,
                  child: const Text('Skip & Close'),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSaving
                    ? null
                    : () {
                        if (isLastStep) {
                          _completeWizard(company);
                        } else {
                          _handleNext(company);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isLastStep ? 'Complete Setup' : 'Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BRANCH MODAL SHEET FORM
  // ==========================================
  void _showBranchFormDialog(String companyId, {BranchModel? branch}) {
    final isEdit = branch != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: branch?.branchName);
    final codeCtrl = TextEditingController(text: branch?.branchCode);
    final emailCtrl = TextEditingController(text: branch?.email);
    final phoneCtrl = TextEditingController(text: branch?.phone);
    final addrCtrl = TextEditingController(text: branch?.address);
    final cityCtrl = TextEditingController(text: branch?.city);
    final stateCtrl = TextEditingController(text: branch?.state);
    final countryCtrl = TextEditingController(text: branch?.country ?? '');
    final zipCtrl = TextEditingController(text: branch?.postalCode);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Branch' : 'Add Branch', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Branch Name *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Branch Code *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: addrCtrl,
                          decoration: const InputDecoration(labelText: 'Address'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cityCtrl,
                                decoration: const InputDecoration(labelText: 'City'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: stateCtrl,
                                decoration: const InputDecoration(labelText: 'State'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: countryCtrl,
                                decoration: const InputDecoration(labelText: 'Country'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: zipCtrl,
                                decoration: const InputDecoration(labelText: 'Postal Code'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newBranch = BranchModel(
                        branchId: branch?.branchId ?? const Uuid().v4(),
                        companyId: companyId,
                        branchName: nameCtrl.text.trim(),
                        branchCode: codeCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addrCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        state: stateCtrl.text.trim(),
                        country: countryCtrl.text.trim(),
                        postalCode: zipCtrl.text.trim(),
                        status: branch?.status ?? 'active',
                        createdAt: branch?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      final errorMsg = await ref.read(adminBranchesProvider.notifier).saveBranch(newBranch);
                      if (errorMsg != null) {
                        _showSnackBar(errorMsg, isError: true);
                      } else {
                        Navigator.pop(ctx);
                        _showSnackBar('Branch saved successfully.');
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _archiveBranchConfirm(BranchModel branch) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Branch'),
        content: Text('Are you sure you want to archive "${branch.branchName}"? Employees will not be able to select this branch.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminBranchesProvider.notifier).archiveBranch(branch.branchId);
      _showSnackBar('Branch archived.');
    }
  }

  // ==========================================
  // DEPARTMENT MODAL SHEET FORM
  // ==========================================
  void _showDepartmentFormDialog(String companyId, {DepartmentModel? department}) {
    final isEdit = department != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: department?.departmentName);
    final codeCtrl = TextEditingController(text: department?.departmentCode);
    final descCtrl = TextEditingController(text: department?.description);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Edit Department' : 'Add Department', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Department Name *', hintText: 'e.g. Sales, Engineering'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Department Code *', hintText: 'e.g. SLS, ENG'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final depts = ref.read(adminDepartmentsProvider).value ?? [];
                  final inputName = nameCtrl.text.trim().toLowerCase();
                  final inputCode = codeCtrl.text.trim().toLowerCase();

                  final duplicateName = depts.any((d) => d.departmentId != department?.departmentId && d.departmentName.toLowerCase() == inputName);
                  if (duplicateName) {
                    _showSnackBar('Department with this name already exists.', isError: true);
                    return;
                  }

                  final duplicateCode = depts.any((d) => d.departmentId != department?.departmentId && d.departmentCode.toLowerCase() == inputCode);
                  if (duplicateCode) {
                    _showSnackBar('Department with this code already exists.', isError: true);
                    return;
                  }

                  final adminUser = ref.read(authProvider).user;
                  final newDept = DepartmentModel(
                    departmentId: department?.departmentId ?? const Uuid().v4(),
                    companyId: companyId,
                    departmentName: nameCtrl.text.trim(),
                    departmentCode: codeCtrl.text.trim().toUpperCase(),
                    description: '',
                    status: department?.status ?? 'active',
                    createdAt: department?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                    createdBy: department?.createdBy ?? adminUser?.email ?? 'Admin',
                  );

                  final result = await ref.read(adminDepartmentsProvider.notifier).saveDepartment(newDept);
                  if (result != 'success') {
                    _showSnackBar(result, isError: true);
                  } else {
                    Navigator.pop(ctx);
                    _showSnackBar('Department saved successfully.');
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteDeptConfirm(DepartmentModel department) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Are you sure you want to permanently delete "${department.departmentName}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(adminDepartmentsProvider.notifier).deleteDepartment(department.departmentId);
    }
  }

  // ==========================================
  // DESIGNATION CONFIGURATION MODAL SHEET FORM
  // ==========================================
  void _showDesignationFormDialog(String companyId, List<DepartmentModel> depts, {DesignationModel? designation}) {
    final isEdit = designation != null;
    final nameCtrl = TextEditingController(text: designation?.designationName ?? '');
    final levelCtrl = TextEditingController(text: '${designation?.designationLevel ?? 1}');
    final formKey = GlobalKey<FormState>();

    bool canManageDepts = designation?.canManageDepartments ?? (designation?.isManagerial ?? false);

    final Set<String> selectedDeptIds = Set<String>.from(
      designation?.managedDepartmentIds.isNotEmpty == true
          ? designation!.managedDepartmentIds
          : (designation?.departmentId.isNotEmpty == true ? [designation!.departmentId] : []),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final count = selectedDeptIds.length;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Designation' : 'Add Designation', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Designation Name *',
                            hintText: 'e.g. Manager, Team Lead, Executive',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Designation Name is required' : null,
                        ),
                        if (FeatureFlags.enableDesignationLevels) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: levelCtrl,
                            decoration: const InputDecoration(labelText: 'Hierarchy Level (1-10) *'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (!FeatureFlags.enableDesignationLevels) return null;
                              if (v == null || v.isEmpty) return 'Required';
                              final val = int.tryParse(v);
                              if (val == null || val < 1) return 'Must be positive integer';
                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: canManageDepts,
                          dense: true,
                          title: const Text('Can manage departments', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          subtitle: const Text('Grant management responsibility for employees assigned this designation.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          activeColor: const Color(0xFF4F46E5),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setDialogState(() {
                              canManageDepts = val ?? false;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        MultiSelectDepartmentDropdown(
                          departments: depts,
                          selectedDepartmentIds: selectedDeptIds.toList(),
                          label: 'Associated Departments *',
                          hint: 'Select departments for this designation',
                          onChanged: (newIds) {
                            setDialogState(() {
                              selectedDeptIds.clear();
                              selectedDeptIds.addAll(newIds);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final selectedList = selectedDeptIds.toList();
                      final primaryDeptId = selectedList.isNotEmpty ? selectedList.first : '';

                      final newDesig = DesignationModel(
                        designationId: designation?.designationId ?? const Uuid().v4(),
                        companyId: companyId,
                        designationName: nameCtrl.text.trim(),
                        designationLevel: int.tryParse(levelCtrl.text) ?? 1,
                        departmentId: primaryDeptId,
                        managedDepartmentIds: selectedList,
                        canManageDepartments: canManageDepts,
                        description: '',
                        status: designation?.status ?? 'active',
                        createdAt: designation?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      final success = await ref.read(adminDesignationsProvider.notifier).saveDesignation(newDesig);
                      if (!success) {
                        _showSnackBar('Designation "${nameCtrl.text.trim()}" already exists for this company.', isError: true);
                      } else {
                        Navigator.pop(ctx);
                        _showSnackBar('Designation saved successfully.');
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteDesigConfirm(DesignationModel designation) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Designation'),
        content: Text('Are you sure you want to permanently delete "${designation.designationName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminDesignationsProvider.notifier).deleteDesignation(designation.designationId);
      _showSnackBar('Designation deleted.');
    }
  }

  // ==========================================
  // SHIFT CONFIGURATION MODAL SHEET FORM
  // ==========================================
  void _showShiftFormDialog(String companyId, {ShiftModel? shift}) {
    final isEdit = shift != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: shift?.shiftName);
    final startCtrl = TextEditingController(text: shift?.startTime ?? '09:00 AM');
    final endCtrl = TextEditingController(text: shift?.endTime ?? '06:00 PM');
    final breakCtrl = TextEditingController(text: shift != null ? '${shift.breakDuration}' : '60');
    final hoursCtrl = TextEditingController(text: shift != null ? '${shift.workingHours}' : '8.0');
    final lateCtrl = TextEditingController(text: shift != null ? '${shift.lateToleranceMinutes}' : '15');
    
    double selectedOtLimit = shift?.otLimitHours ?? 2.0;
    bool overtimeEligible = shift?.overtimeEligible ?? true;

    ShiftDurationResult calcResult = ShiftDurationCalculator.calculateShiftDuration(
      startTimeStr: startCtrl.text.trim(),
      endTimeStr: endCtrl.text.trim(),
      breakDurationMinutes: int.tryParse(breakCtrl.text.trim()) ?? 0,
    );

    if (calcResult.isValid && shift == null) {
      hoursCtrl.text = calcResult.workingHours.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    }

    void recalculate(void Function(void Function()) setDialogState) {
      final bMins = int.tryParse(breakCtrl.text.trim()) ?? 0;
      final res = ShiftDurationCalculator.calculateShiftDuration(
        startTimeStr: startCtrl.text.trim(),
        endTimeStr: endCtrl.text.trim(),
        breakDurationMinutes: bMins,
      );
      setDialogState(() {
        calcResult = res;
        if (res.isValid) {
          hoursCtrl.text = res.workingHours.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Work Shift' : 'Add Work Shift', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Shift Name *', hintText: 'e.g. General Shift, Morning Shift, Night Shift'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: startCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Start Time *',
                                  hintText: '09:00 AM',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.access_time_rounded, size: 20),
                                    onPressed: () async {
                                      final initialMins = ShiftDurationCalculator.parseTimeToMinutes(startCtrl.text.trim()) ?? 540;
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(hour: initialMins ~/ 60, minute: initialMins % 60),
                                      );
                                      if (picked != null) {
                                        startCtrl.text = ShiftDurationCalculator.formatMinutesTo12Hour(
                                          ShiftDurationCalculator.timeOfDayToMinutes(picked),
                                        );
                                        recalculate(setDialogState);
                                      }
                                    },
                                  ),
                                ),
                                onChanged: (_) => recalculate(setDialogState),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (ShiftDurationCalculator.parseTimeToMinutes(v.trim()) == null) return 'Invalid format';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: endCtrl,
                                decoration: InputDecoration(
                                  labelText: 'End Time *',
                                  hintText: '06:00 PM',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.access_time_rounded, size: 20),
                                    onPressed: () async {
                                      final initialMins = ShiftDurationCalculator.parseTimeToMinutes(endCtrl.text.trim()) ?? 1080;
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay(hour: initialMins ~/ 60, minute: initialMins % 60),
                                      );
                                      if (picked != null) {
                                        endCtrl.text = ShiftDurationCalculator.formatMinutesTo12Hour(
                                          ShiftDurationCalculator.timeOfDayToMinutes(picked),
                                        );
                                        recalculate(setDialogState);
                                      }
                                    },
                                  ),
                                ),
                                onChanged: (_) => recalculate(setDialogState),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (ShiftDurationCalculator.parseTimeToMinutes(v.trim()) == null) return 'Invalid format';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: breakCtrl,
                                decoration: const InputDecoration(labelText: 'Break Duration (mins) *'),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => recalculate(setDialogState),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: hoursCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(labelText: 'Working Hours (Auto) *'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Working Hours Summary Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: calcResult.isValid
                                ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                                : (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: calcResult.isValid
                                  ? (isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE))
                                  : (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    calcResult.isValid ? Icons.auto_awesome_rounded : Icons.warning_amber_rounded,
                                    size: 16,
                                    color: calcResult.isValid ? const Color(0xFF4F46E5) : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    calcResult.isValid ? 'WORKING HOURS SUMMARY' : 'Invalid Time / Duration',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: calcResult.isValid
                                          ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3))
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (calcResult.isValid) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Shift Duration', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text(ShiftDurationCalculator.formatHoursShort(calcResult.workingHours), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Overtime', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text(
                                          overtimeEligible ? 'Enabled' : 'Disabled',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: overtimeEligible ? const Color(0xFF10B981) : Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (overtimeEligible)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('OT Limit', style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF64748B))),
                                          const SizedBox(height: 2),
                                          Text(
                                            ShiftDurationCalculator.formatHoursShort(selectedOtLimit),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEC4899)),
                                          ),
                                        ],
                                      ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Max Working Time', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(
                                          ShiftDurationCalculator.formatHoursShort(overtimeEligible ? (calcResult.workingHours + selectedOtLimit) : calcResult.workingHours),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Text(
                                  calcResult.errorMessage ?? 'Please enter valid Start Time and End Time',
                                  style: const TextStyle(fontSize: 11, color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            if (overtimeEligible) ...[
                              Expanded(
                                child: DropdownButtonFormField<double>(
                                  value: [1.0, 2.0, 3.0, 4.0].contains(selectedOtLimit) ? selectedOtLimit : 2.0,
                                  decoration: const InputDecoration(
                                    labelText: 'OT Limit *',
                                    prefixIcon: Icon(Icons.more_time_rounded),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 1.0, child: Text('1 Hour')),
                                    DropdownMenuItem(value: 2.0, child: Text('2 Hours (Default)')),
                                    DropdownMenuItem(value: 3.0, child: Text('3 Hours')),
                                    DropdownMenuItem(value: 4.0, child: Text('4 Hours')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        selectedOtLimit = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: TextFormField(
                                controller: lateCtrl,
                                decoration: const InputDecoration(labelText: 'Late Tolerance (mins)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Overtime Allowed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          value: overtimeEligible,
                          onChanged: (val) {
                            setDialogState(() {
                              overtimeEligible = val;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      if (!calcResult.isValid) {
                        _showSnackBar(calcResult.errorMessage ?? 'Invalid shift duration', isError: true);
                        return;
                      }

                      final newShift = ShiftModel(
                        shiftId: shift?.shiftId ?? const Uuid().v4(),
                        companyId: companyId,
                        shiftName: nameCtrl.text.trim(),
                        shiftCode: shift?.shiftCode ?? 'SF_${nameCtrl.text.trim().toUpperCase().replaceAll(' ', '_')}',
                        startTime: startCtrl.text.trim(),
                        endTime: endCtrl.text.trim(),
                        breakDurationMinutes: int.parse(breakCtrl.text),
                        workingHours: calcResult.workingHours,
                        gracePeriodMinutes: int.parse(lateCtrl.text.isEmpty ? '0' : lateCtrl.text),
                        halfDayThresholdHours: 4.0,
                        overtimeAllowed: overtimeEligible,
                        overtimeStartAfterHours: calcResult.workingHours,
                        otLimitHours: selectedOtLimit,
                        weeklyOffDays: const ['Sunday'],
                        status: shift?.status ?? 'active',
                        createdAt: shift?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      final result = await ref.read(adminShiftsProvider.notifier).saveShift(newShift);
                      if (result != 'success') {
                        _showSnackBar(result, isError: true);
                      } else {
                        Navigator.pop(ctx);
                        _showSnackBar('Shift configuration saved.');
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteShiftConfirm(ShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to permanently delete shift "${shift.shiftName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminShiftsProvider.notifier).deleteShift(shift.shiftId);
      _showSnackBar('Shift configuration deleted.');
    }
  }

  // ==========================================
  // HOLIDAY CONFIGURATION MODAL SHEET FORM
  // ==========================================
  void _showHolidayFormDialog(String companyId, {HolidayModel? holiday}) {
    final isEdit = holiday != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: holiday?.holidayName);
    final descCtrl = TextEditingController(text: holiday?.description);
    DateTime selectedDate = holiday?.holidayDate ?? DateTime.now();
    String holidayType = holiday?.holidayType ?? 'Public';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final dateStr = DateFormat('dd MMMM yyyy').format(selectedDate);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEdit ? 'Edit Holiday' : 'Add Holiday', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Holiday Name *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Holiday Date *', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          subtitle: Text(dateStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(DateTime.now().year - 1),
                                lastDate: DateTime(DateTime.now().year + 5),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            child: const Text('Select'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: holidayType,
                          decoration: const InputDecoration(labelText: 'Holiday Type *'),
                          items: const [
                            DropdownMenuItem(value: 'Public', child: Text('Public')),
                            DropdownMenuItem(value: 'National', child: Text('National')),
                            DropdownMenuItem(value: 'Regional', child: Text('Regional')),
                            DropdownMenuItem(value: 'Company Specific', child: Text('Company Specific')),
                            DropdownMenuItem(value: 'Restricted', child: Text('Restricted')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                holidayType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(labelText: 'Description'),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newHoliday = HolidayModel(
                        holidayId: holiday?.holidayId ?? const Uuid().v4(),
                        companyId: companyId,
                        branchId: null,
                        holidayName: nameCtrl.text.trim(),
                        holidayDate: selectedDate,
                        holidayType: holidayType,
                        description: descCtrl.text.trim(),
                        isRecurring: false,
                        status: holiday?.status ?? 'active',
                        createdAt: holiday?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await ref.read(adminHolidaysProvider.notifier).saveHoliday(newHoliday);
                      Navigator.pop(ctx);
                      _showSnackBar('Holiday saved successfully.');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteHolidayConfirm(HolidayModel holiday) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Holiday'),
        content: Text('Are you sure you want to permanently delete holiday "${holiday.holidayName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(adminHolidaysProvider.notifier).deleteHoliday(holiday.holidayId);
      _showSnackBar('Holiday deleted.');
    }
  }
}
