import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:worktrack/constants/user_roles.dart';
import 'package:worktrack/constants/feature_flags.dart';
import 'package:worktrack/shared/providers/providers.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/models/department_model.dart';
import 'package:worktrack/shared/services/app_error_handler.dart';
import 'package:worktrack/shared/services/password_validator.dart';
import 'package:worktrack/shared/utils/app_validators.dart';
import 'package:worktrack/shared/widgets/app_user_avatar.dart';
import 'package:worktrack/shared/widgets/placeholder_screen.dart';
import 'package:worktrack/features/company_admin/models/designation_model.dart';
import '../../providers/company_admin_providers.dart';
import 'employee_documents_screen.dart';

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  final UserModel? employee;
  const EmployeeProfileScreen({super.key, this.employee});

  @override
  ConsumerState<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  late UserModel _employeeState;
  
  String? resolvedDeptName;
  String? resolvedDesigName;
  String? resolvedManagerName;
  String? resolvedShiftName;
  String? resolvedBranchName;
  
  bool isLoadingData = true;
  bool isSavingProfile = false;
  bool isEditMode = false;

  // Edit Mode Form Controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _personalEmailCtrl;
  late TextEditingController _emergencyNameCtrl;
  late TextEditingController _emergencyPhoneCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNumCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _aadhaarCtrl;
  late TextEditingController _companyNameCtrl;
  late TextEditingController _companyEmailCtrl;
  late TextEditingController _companyMobileCtrl;
  late TextEditingController _companyAddressCtrl;

  String? _selectedGender;
  DateTime? _selectedDob;
  String? _selectedBloodGroup;
  String? _selectedMaritalStatus;
  String? _selectedDeptId;
  String? _selectedDesigId;
  String? _selectedEmpType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authProvider).user;
    _employeeState = widget.employee ?? authUser ?? UserModel(
      uid: '',
      email: '',
      name: 'Employee Profile',
      role: UserRoles.employee,
      companyId: '',
      companyName: '',
      createdAt: DateTime.now(),
    );
    _initControllers();
    _loadRelatedData();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: _employeeState.name);
    _phoneCtrl = TextEditingController(text: _employeeState.phoneNumber ?? '');
    _personalEmailCtrl = TextEditingController(text: _employeeState.personalEmail ?? _employeeState.employeeEmail ?? '');
    _emergencyNameCtrl = TextEditingController(text: _employeeState.emergencyContactName ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: _employeeState.emergencyContactPhone ?? '');
    _bankNameCtrl = TextEditingController(text: _employeeState.bankName ?? '');
    _accountNumCtrl = TextEditingController(text: _employeeState.accountNumber ?? '');
    _ifscCtrl = TextEditingController(text: _employeeState.ifscCode ?? '');
    _panCtrl = TextEditingController(text: _employeeState.panNumber ?? '');
    _aadhaarCtrl = TextEditingController(text: _employeeState.aadhaarNumber ?? '');

    final company = ref.read(companyProvider).value;
    _companyNameCtrl = TextEditingController(text: company?.name ?? _employeeState.companyName);
    _companyEmailCtrl = TextEditingController(text: company?.businessEmail.isNotEmpty == true ? company!.businessEmail : (_employeeState.companyEmail ?? ''));
    _companyMobileCtrl = TextEditingController(text: company?.companyMobile ?? '');
    _companyAddressCtrl = TextEditingController(text: company?.address ?? '');

    _selectedGender = _employeeState.gender;
    _selectedDob = _employeeState.dateOfBirth;
    _selectedBloodGroup = _employeeState.bloodGroup;
    _selectedMaritalStatus = _employeeState.maritalStatus;
    _selectedDeptId = _employeeState.departmentId;
    _selectedDesigId = _employeeState.designationId;
    _selectedEmpType = _employeeState.employmentType ?? 'Full-time';
    _selectedStatus = _employeeState.status;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _personalEmailCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumCtrl.dispose();
    _ifscCtrl.dispose();
    _panCtrl.dispose();
    _aadhaarCtrl.dispose();
    _companyNameCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyMobileCtrl.dispose();
    _companyAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRelatedData() async {
    if (!mounted) return;
    setState(() { isLoadingData = true; });
    
    try {
      final fs = FirebaseFirestore.instance;
      
      // If displaying logged in user, refresh from authProvider
      if (widget.employee == null) {
        final freshAuthUser = ref.read(authProvider).user;
        if (freshAuthUser != null) {
          _employeeState = freshAuthUser;
          _initControllers();
        }
      }

      // 1. Fetch Department name
      if (_employeeState.departmentId != null && _employeeState.departmentId!.isNotEmpty) {
        final doc = await fs.collection('departments').doc(_employeeState.departmentId).get();
        if (doc.exists) {
          resolvedDeptName = doc.data()?['name'] ?? doc.data()?['departmentName'];
        }
      }
      
      // 2. Fetch Designation name
      if (_employeeState.designationId != null && _employeeState.designationId!.isNotEmpty) {
        final doc = await fs.collection('designations').doc(_employeeState.designationId).get();
        if (doc.exists) {
          resolvedDesigName = doc.data()?['designationName'];
        }
      }
      
      // 3. Fetch Manager name
      if (_employeeState.managerId != null && _employeeState.managerId!.isNotEmpty) {
        final doc = await fs.collection('users').doc(_employeeState.managerId).get();
        if (doc.exists) {
          resolvedManagerName = doc.data()?['name'];
        }
      }
      
      // 4. Fetch Shift name
      if (_employeeState.shiftId != null && _employeeState.shiftId!.isNotEmpty) {
        final doc = await fs.collection('work_shifts').doc(_employeeState.shiftId).get();
        if (doc.exists) {
          resolvedShiftName = doc.data()?['shiftName'];
        }
      }

      // 5. Fetch Branch name
      if (_employeeState.branchId != null && _employeeState.branchId!.isNotEmpty) {
        final doc = await fs.collection('branches').doc(_employeeState.branchId).get();
        if (doc.exists) {
          resolvedBranchName = doc.data()?['branchName'];
        }
      }
    } catch (e) {
      debugPrint('Error loading related employee profile data: $e');
    } finally {
      if (mounted) {
        setState(() { isLoadingData = false; });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (!FeatureFlags.enableImageUpload) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File upload is currently disabled.')),
        );
      }
      return;
    }
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final fileName = file.name;
      var fileBytes = file.bytes;

      if (fileBytes == null && file.path != null && !kIsWeb) {
        fileBytes = await io.File(file.path!).readAsBytes();
      }

      if (fileBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data. Please try again.')),
          );
        }
        return;
      }

      if (fileBytes.lengthInBytes > 3 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image size exceeds 3MB limit.')),
          );
        }
        return;
      }

      setState(() => isSavingProfile = true);
      final currentUser = ref.read(authProvider).user;
      final isSelf = currentUser != null && (currentUser.uid == _employeeState.uid || (currentUser.employeeId != null && currentUser.employeeId == _employeeState.employeeId));

      String? downloadUrl;
      if (isSelf) {
        downloadUrl = await ref.read(authProvider.notifier).uploadAvatar(fileName, fileBytes);
      } else {
        downloadUrl = await ref.read(userRepositoryProvider).uploadProfileImage(_employeeState.uid, fileName, fileBytes);
        final updatedEmp = _employeeState.copyWith(profileImageUrl: downloadUrl);
        await ref.read(adminEmployeesProvider.notifier).editEmployee(updatedEmp);
      }
      
      if (!mounted) return;
      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        setState(() {
          _employeeState = _employeeState.copyWith(profileImageUrl: downloadUrl);
          isSavingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        _loadRelatedData();
      } else {
        setState(() => isSavingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      setState(() => isSavingProfile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _saveCompanyAdminProfileChanges() async {
    setState(() => isSavingProfile = true);
    try {
      final adminName = _nameCtrl.text.trim();
      final adminPhone = _phoneCtrl.text.trim();
      final adminEmail = _personalEmailCtrl.text.trim();
      final companyName = _companyNameCtrl.text.trim();
      final companyEmail = _companyEmailCtrl.text.trim();
      final companyPhone = _companyMobileCtrl.text.trim();
      final companyAddress = _companyAddressCtrl.text.trim();

      if (adminName.isEmpty) {
        setState(() => isSavingProfile = false);
        _showSnackBar('Admin Name cannot be empty.', isError: true);
        return;
      }
      if (adminPhone.isNotEmpty) {
        final err = AppValidators.validateMobileNumber(adminPhone, isRequired: false);
        if (err != null) {
          setState(() => isSavingProfile = false);
          _showSnackBar(err, isError: true);
          return;
        }
      }
      if (adminEmail.isNotEmpty) {
        final err = AppValidators.validatePersonalEmail(adminEmail, isRequired: false);
        if (err != null) {
          setState(() => isSavingProfile = false);
          _showSnackBar(err, isError: true);
          return;
        }
      }
      if (companyEmail.isNotEmpty) {
        final err = AppValidators.validateBusinessEmail(companyEmail, isRequired: false);
        if (err != null) {
          setState(() => isSavingProfile = false);
          _showSnackBar(err, isError: true);
          return;
        }
      }
      if (companyPhone.isNotEmpty) {
        final err = AppValidators.validateCompanyPhone(companyPhone, isRequired: false);
        if (err != null) {
          setState(() => isSavingProfile = false);
          _showSnackBar(err, isError: true);
          return;
        }
      }

      final updatedUser = _employeeState.copyWith(
        name: adminName,
        phoneNumber: adminPhone,
        personalEmail: adminEmail.isNotEmpty ? adminEmail : _employeeState.personalEmail,
      );

      final currentUser = ref.read(authProvider).user;
      if (currentUser != null && currentUser.uid == _employeeState.uid) {
        await ref.read(authProvider.notifier).updateProfile(
          name: updatedUser.name,
          phoneNumber: updatedUser.phoneNumber,
        );
      } else {
        await ref.read(userRepositoryProvider).updateUserProfile(
          updatedUser.uid,
          name: updatedUser.name,
          phoneNumber: updatedUser.phoneNumber,
        );
      }

      final company = ref.read(companyProvider).value;
      if (company != null) {
        final updatedCompany = company.copyWith(
          name: companyName.isNotEmpty ? companyName : company.name,
          businessEmail: companyEmail,
          companyMobile: companyPhone,
          address: companyAddress,
        );
        await ref.read(companyProvider.notifier).updateCompany(updatedCompany);
      }

      if (mounted) {
        setState(() {
          _employeeState = updatedUser;
          isEditMode = false;
          isSavingProfile = false;
        });
        _showSnackBar('Company Admin Profile updated successfully.');
      }
    } catch (e) {
      setState(() => isSavingProfile = false);
      _showSnackBar('Error updating admin profile: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveProfileChanges() async {
    final isCompanyAdminProfile = _employeeState.role == UserRoles.companyAdmin;
    if (isCompanyAdminProfile) {
      await _saveCompanyAdminProfileChanges();
      return;
    }
    setState(() => isSavingProfile = true);

    try {
      final depts = ref.read(adminDepartmentsProvider).value ?? [];
      final desigs = ref.read(adminDesignationsProvider).value ?? [];

      final deptObj = depts.firstWhere(
        (d) => d.departmentId == _selectedDeptId,
        orElse: () => DepartmentModel(departmentId: '', companyId: '', departmentName: '', departmentCode: '', createdAt: DateTime.now(), updatedAt: DateTime.now(), createdBy: ''),
      );
      final desigObj = desigs.firstWhere(
        (d) => d.designationId == _selectedDesigId,
        orElse: () => DesignationModel(designationId: '', designationName: '', departmentId: '', designationLevel: 1, companyId: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );

      final updatedModel = _employeeState.copyWith(
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        personalEmail: _personalEmailCtrl.text.trim(),
        gender: _selectedGender,
        dateOfBirth: _selectedDob,
        bloodGroup: _selectedBloodGroup,
        maritalStatus: _selectedMaritalStatus,
        emergencyContactName: _emergencyNameCtrl.text.trim(),
        emergencyContactPhone: _emergencyPhoneCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        accountNumber: _accountNumCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim(),
        panNumber: _panCtrl.text.trim(),
        aadhaarNumber: _aadhaarCtrl.text.trim(),
        departmentId: _selectedDeptId,
        department: deptObj.name.isNotEmpty ? deptObj.name : _employeeState.department,
        designationId: _selectedDesigId,
        designation: desigObj.designationName.isNotEmpty ? desigObj.designationName : _employeeState.designation,
        employmentType: _selectedEmpType,
        status: _selectedStatus ?? _employeeState.status,
      );

      final currentUser = ref.read(authProvider).user;
      final isSelf = currentUser != null && currentUser.uid == _employeeState.uid;

      if (isSelf) {
        await ref.read(authProvider.notifier).updateProfile(
          name: updatedModel.name,
          phoneNumber: updatedModel.phoneNumber,
        );
      }
      
      await ref.read(adminEmployeesProvider.notifier).editEmployee(updatedModel);

      if (mounted) {
        setState(() {
          _employeeState = updatedModel;
          isEditMode = false;
          isSavingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadRelatedData();
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => isSavingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToModule({
    required BuildContext context,
    required String routePath,
    required String title,
    required String description,
    required IconData icon,
  }) {
    try {
      context.push(routePath);
    } catch (e) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkTrackPlaceholderScreen(
            title: title,
            description: description,
            icon: icon,
          ),
        ),
      );
    }
  }

  Widget _buildCompanyAdminProfileContent(
    BuildContext context,
    UserModel targetEmployee,
    bool isDark,
    bool isSelfProfile,
  ) {
    final company = ref.watch(companyProvider).value;
    final companyCode = company?.companyCode ?? targetEmployee.companyCode ?? 'N/A';
    final companyName = company?.name ?? targetEmployee.companyName;
    final adminCode = targetEmployee.adminCode;

    final companyEmail = company?.businessEmail.isNotEmpty == true
        ? company!.businessEmail
        : (targetEmployee.companyEmail ?? 'Not Provided');
    final companyPhone = company?.companyMobile.isNotEmpty == true
        ? company!.companyMobile
        : 'Not Provided';

    final addressParts = [
      if (company?.address != null && company!.address.trim().isNotEmpty) company.address.trim(),
      if (company?.city != null && company!.city.trim().isNotEmpty) company.city.trim(),
      if (company?.state != null && company!.state.trim().isNotEmpty) company.state.trim(),
      if (company?.country != null && company!.country.trim().isNotEmpty) company.country.trim(),
      if (company?.zip != null && company!.zip.trim().isNotEmpty) company.zip.trim(),
    ];
    final companyAddressStr = addressParts.isNotEmpty ? addressParts.join(', ') : 'Not Provided';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card with Admin Avatar & Badges
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007834),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF5B4CF0).withOpacity(0.2),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: AppUserAvatar(
                          user: targetEmployee,
                          companyId: targetEmployee.companyId,
                          radius: 40,
                          backgroundColor: Colors.transparent,
                          iconColor: const Color(0xFF5B4CF0),
                        ),
                      ),
                    ),
                    if (FeatureFlags.enableImageUpload)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: const Color(0xFF5B4CF0),
                          elevation: 3,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _pickAndUploadPhoto,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SelectableText(
                  targetEmployee.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isDark ? Colors.white : const Color(0xFF191C1F),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4CF0).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_rounded, size: 14, color: Color(0xFF5B4CF0)),
                          const SizedBox(width: 6),
                          SelectableText(
                            'Admin Code: $adminCode',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5B4CF0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, size: 14, color: Color(0xFF10B981)),
                          SizedBox(width: 6),
                          Text(
                            'COMPANY ADMIN',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Change Password Shortcut for Admin
          if (isSelfProfile)
            Row(
              children: [
                _buildQuickActionButton(
                  icon: Icons.lock_rounded,
                  label: 'Change Password',
                  onPressed: () => _showChangePasswordModal(context),
                ),
              ],
            ),
          if (isSelfProfile) const SizedBox(height: 20),

          // 2. Admin Information Section
          _buildSectionCard(
            title: 'Admin Information',
            titleIcon: Icons.admin_panel_settings_rounded,
            children: [
              if (isEditMode) ...[
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Admin Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Admin Contact Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _personalEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Admin Code (Immutable)',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                    filled: true,
                    fillColor: Color(0xFFF1F5F9),
                  ),
                  child: Text(
                    adminCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ] else ...[
                _buildInfoRow('Admin Code', adminCode, showCopyIcon: true),
                _buildDivider(),
                _buildInfoRow('Admin Name', targetEmployee.name),
                _buildDivider(),
                _buildInfoRow('Admin Email', targetEmployee.email, showCopyIcon: true),
                _buildDivider(),
                _buildInfoRow('Contact Number', targetEmployee.phoneNumber ?? 'Not Provided'),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // 3. Company Information Section
          _buildSectionCard(
            title: 'Company Information',
            titleIcon: Icons.business_rounded,
            children: [
              if (isEditMode) ...[
                TextFormField(
                  controller: _companyNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company Name *',
                    prefixIcon: Icon(Icons.domain_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Company Code (Immutable)',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                    filled: true,
                    fillColor: Color(0xFFF1F5F9),
                  ),
                  child: Text(
                    companyCode,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Company Email',
                    prefixIcon: Icon(Icons.markunread_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyMobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Company Phone',
                    prefixIcon: Icon(Icons.phone_android_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyAddressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Company Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
              ] else ...[
                _buildInfoRow('Company Name', companyName),
                _buildDivider(),
                _buildInfoRow('Company Code', companyCode, showCopyIcon: true),
                _buildDivider(),
                _buildInfoRow('Company Email', companyEmail, showCopyIcon: true),
                _buildDivider(),
                _buildInfoRow('Company Phone', companyPhone),
                _buildDivider(),
                _buildInfoRow('Company Address', companyAddressStr),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final targetEmployee = _employeeState;

    final isSameCompany = currentUser != null &&
        (currentUser.companyId == targetEmployee.companyId);

    final isSelfProfile = currentUser != null &&
        ((currentUser.uid == targetEmployee.uid) ||
         (currentUser.employeeId != null &&
          targetEmployee.employeeId != null &&
          currentUser.employeeId == targetEmployee.employeeId));

    final isAdminOrHR = currentUser != null && isSameCompany &&
        (currentUser.role == UserRoles.companyAdmin ||
         currentUser.role == UserRoles.hrAdmin ||
         currentUser.role == UserRoles.hrExecutive ||
         currentUser.role == UserRoles.hr);

    final canEdit = isSameCompany && (isAdminOrHR || isSelfProfile);
    final canViewDocs = isSameCompany && (isAdminOrHR || isSelfProfile);

    final statusColor = targetEmployee.status.toLowerCase() == 'active' ? const Color(0xFF007834) : const Color(0xFFBA1A1A);
    final statusBg = targetEmployee.status.toLowerCase() == 'active' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2);

    final joinDateStr = targetEmployee.joiningDate != null
        ? DateFormat('dd MMM yyyy').format(targetEmployee.joiningDate!)
        : 'N/A';
    final dobStr = targetEmployee.dateOfBirth != null
        ? DateFormat('dd MMM yyyy').format(targetEmployee.dateOfBirth!)
        : 'Not Specified';
    final createdDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(targetEmployee.createdAt);
    final lastLoginStr = targetEmployee.lastLogin != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(targetEmployee.lastLogin!)
        : 'Never';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompanyAdminProfile = targetEmployee.role == UserRoles.companyAdmin;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(
          isEditMode
              ? (isCompanyAdminProfile ? 'Edit Company Admin Profile' : 'Edit Employee Profile')
              : (isCompanyAdminProfile ? 'Company Admin Profile' : 'Employee Profile'),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF5B4CF0),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5B4CF0)),
        backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
        actions: [
          if (isEditMode) ...[
            TextButton.icon(
              onPressed: isSavingProfile ? null : () => setState(() => isEditMode = false),
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
              label: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: isSavingProfile ? null : _saveProfileChanges,
              icon: isSavingProfile
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4CF0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF5B4CF0)),
                tooltip: 'Edit Profile Mode',
                onPressed: () => setState(() => isEditMode = true),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B4CF0)),
              tooltip: 'Reload',
              onPressed: _loadRelatedData,
            ),
          ],
        ],
      ),
      body: isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: isCompanyAdminProfile
                    ? _buildCompanyAdminProfileContent(context, targetEmployee, isDark, isSelfProfile)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card with Avatar & Quick Meta
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: isDark ? Theme.of(context).cardColor : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF111827).withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: SelectableText(
                                  targetEmployee.status.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF5B4CF0).withOpacity(0.2), width: 3),
                                  ),
                                  child: ClipOval(
                                    child: AppUserAvatar(
                                      user: targetEmployee,
                                      companyId: targetEmployee.companyId,
                                      radius: 40,
                                      backgroundColor: Colors.transparent,
                                      iconColor: const Color(0xFF5B4CF0),
                                    ),
                                  ),
                                ),
                                if (FeatureFlags.enableImageUpload)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Material(
                                      color: const Color(0xFF5B4CF0),
                                      elevation: 3,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        onTap: _pickAndUploadPhoto,
                                        customBorder: const CircleBorder(),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6.0),
                                          child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SelectableText(
                              targetEmployee.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: isDark ? Colors.white : const Color(0xFF191C1F),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SelectableText(
                                  targetEmployee.employeeId ?? 'N/A',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    color: Color(0xFF5B4CF0),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (targetEmployee.employeeId != null && targetEmployee.employeeId!.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: targetEmployee.employeeId!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Employee ID copied.'),
                                          duration: Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2.0),
                                      child: Icon(Icons.content_copy_rounded, size: 13, color: Color(0xFF5B4CF0)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                if (resolvedDeptName != null || targetEmployee.department != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.business_rounded, size: 14, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 6),
                                        SelectableText(
                                          resolvedDeptName ?? targetEmployee.department!,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF6366F1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (resolvedDesigName != null || targetEmployee.designation != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0EA5E9).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF0EA5E9)),
                                        const SizedBox(width: 6),
                                        SelectableText(
                                          resolvedDesigName ?? targetEmployee.designation!,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0EA5E9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5B4CF0).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Color(0xFF5B4CF0)),
                                      const SizedBox(width: 6),
                                      SelectableText(
                                        UserModel.denormalizeRole(targetEmployee.role),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF5B4CF0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Role-based Quick Action Navigation Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              // Employee Self-Service or HR Viewing Employee Docs
                              if (isSelfProfile || isAdminOrHR)
                                _buildQuickActionButton(
                                  icon: Icons.description_rounded,
                                  label: isSelfProfile ? 'My Docs' : 'View Docs',
                                  onPressed: () {
                                    if (!canViewDocs) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('You do not have permission to view documents.')),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EmployeeDocumentsScreen(employee: targetEmployee),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              // Employee Self-Service Shortcuts (Hidden for Admin Profile)
                              if (isSelfProfile && currentUser.role != UserRoles.companyAdmin) ...[
                                _buildQuickActionButton(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Attendance',
                                  onPressed: () {
                                    _navigateToModule(
                                      context: context,
                                      routePath: '/attendance',
                                      title: 'Attendance History',
                                      description: 'Attendance history and daily log management module.',
                                      icon: Icons.calendar_today_rounded,
                                    );
                                  },
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.event_busy_rounded,
                                  label: 'Leave',
                                  onPressed: () {
                                    _navigateToModule(
                                      context: context,
                                      routePath: '/leaves',
                                      title: 'Leave History',
                                      description: 'Leave application and balance details module.',
                                      icon: Icons.event_busy_rounded,
                                    );
                                  },
                                ),
                                _buildQuickActionButton(
                                  icon: Icons.payments_rounded,
                                  label: 'Payslips',
                                  onPressed: () {
                                    _navigateToModule(
                                      context: context,
                                      routePath: '/company-admin/payroll',
                                      title: 'Payslips',
                                      description: 'Payroll processing and payslip details module.',
                                      icon: Icons.payments_rounded,
                                    );
                                  },
                                ),
                              ],
                              // Password action
                              if (isSelfProfile)
                                _buildQuickActionButton(
                                  icon: Icons.lock_rounded,
                                  label: 'Change Pass',
                                  onPressed: () => _showChangePasswordModal(context),
                                )
                              else if (isAdminOrHR)
                                _buildQuickActionButton(
                                  icon: Icons.lock_reset_rounded,
                                  label: 'Reset Pass',
                                  onPressed: () => _handleResetPassword(context, targetEmployee.uid, targetEmployee.name),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 1: Personal Information
                      _buildSectionCard(
                        title: 'Personal Information',
                        titleIcon: Icons.person_rounded,
                        children: [
                          if (isEditMode) ...[
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: ['Male', 'Female', 'Other', 'Prefer Not to Say'].contains(_selectedGender) ? _selectedGender : null,
                              decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc_outlined)),
                              items: ['Male', 'Female', 'Other', 'Prefer Not to Say'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (val) => setState(() => _selectedGender = val),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDob ?? DateTime(1995, 1, 1),
                                  firstDate: DateTime(1950),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setState(() => _selectedDob = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date of Birth', prefixIcon: Icon(Icons.cake_outlined)),
                                child: Text(_selectedDob != null ? DateFormat('dd MMM yyyy').format(_selectedDob!) : 'Select Date of Birth'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].contains(_selectedBloodGroup) ? _selectedBloodGroup : null,
                              decoration: const InputDecoration(labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype_outlined)),
                              items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                              onChanged: (val) => setState(() => _selectedBloodGroup = val),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: ['Single', 'Married', 'Divorced', 'Widowed'].contains(_selectedMaritalStatus) ? _selectedMaritalStatus : null,
                              decoration: const InputDecoration(labelText: 'Marital Status', prefixIcon: Icon(Icons.favorite_outline)),
                              items: ['Single', 'Married', 'Divorced', 'Widowed'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                              onChanged: (val) => setState(() => _selectedMaritalStatus = val),
                            ),
                          ] else ...[
                            _buildInfoRow('Full Name', targetEmployee.name),
                            _buildDivider(),
                            _buildInfoRow('Gender', targetEmployee.gender ?? 'Not Specified'),
                            _buildDivider(),
                            _buildInfoRow('Date of Birth', dobStr),
                            _buildDivider(),
                            _buildInfoRow('Blood Group', targetEmployee.bloodGroup ?? 'Not Specified'),
                            _buildDivider(),
                            _buildInfoRow('Marital Status', targetEmployee.maritalStatus ?? 'Not Specified'),
                          ],
                        ],
                      ),

                      // SECTION 2: Company Information
                      _buildSectionCard(
                        title: 'Company Information',
                        titleIcon: Icons.corporate_fare_rounded,
                        children: [
                          _buildInfoRow('Employee ID', targetEmployee.employeeId ?? 'N/A', showCopyIcon: true),
                          _buildDivider(),
                          _buildInfoRow('Company Code', targetEmployee.companyCode ?? 'N/A', showCopyIcon: true),
                          _buildDivider(),
                          _buildInfoRow('Company Name', targetEmployee.companyName, showCopyIcon: true),
                          _buildDivider(),
                          if (isEditMode && isAdminOrHR) ...[
                            Consumer(
                              builder: (context, ref, _) {
                                final depts = ref.watch(adminDepartmentsProvider).value ?? [];
                                return DropdownButtonFormField<String>(
                                  value: depts.any((d) => d.departmentId == _selectedDeptId) ? _selectedDeptId : null,
                                  decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.corporate_fare_outlined)),
                                  items: depts.map((d) => DropdownMenuItem(value: d.departmentId, child: Text(d.name))).toList(),
                                  onChanged: (val) => setState(() => _selectedDeptId = val),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Consumer(
                              builder: (context, ref, _) {
                                final desigs = ref.watch(adminDesignationsProvider).value ?? [];
                                return DropdownButtonFormField<String>(
                                  value: desigs.any((d) => d.designationId == _selectedDesigId) ? _selectedDesigId : null,
                                  decoration: const InputDecoration(labelText: 'Designation', prefixIcon: Icon(Icons.badge_outlined)),
                                  items: desigs.map((d) => DropdownMenuItem(value: d.designationId, child: Text(d.designationName))).toList(),
                                  onChanged: (val) => setState(() => _selectedDesigId = val),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            _buildInfoRow('Department', resolvedDeptName ?? targetEmployee.department ?? 'N/A'),
                            _buildDivider(),
                            _buildInfoRow('Designation', resolvedDesigName ?? targetEmployee.designation ?? 'N/A'),
                            _buildDivider(),
                          ],
                          _buildInfoRow('Branch', resolvedBranchName ?? targetEmployee.branchName ?? 'N/A'),
                          _buildDivider(),
                          _buildInfoRow('Shift', resolvedShiftName ?? 'N/A'),
                          if (resolvedManagerName != null) ...[
                            _buildDivider(),
                            _buildInfoRow('Reporting Manager', resolvedManagerName!),
                          ],
                          _buildDivider(),
                          _buildInfoRow('Join Date', joinDateStr),
                        ],
                      ),

                      // SECTION 3: Contact Details
                      _buildSectionCard(
                        title: 'Contact Information',
                        titleIcon: Icons.alternate_email_rounded,
                        children: [
                          _buildInfoRow('Work Email', targetEmployee.companyEmail ?? targetEmployee.hiddenEmail ?? targetEmployee.email, showCopyIcon: true),
                          _buildDivider(),
                          if (isEditMode) ...[
                            TextFormField(
                              controller: _personalEmailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Personal Email', prefixIcon: Icon(Icons.email_outlined)),
                              validator: (v) => AppValidators.validatePersonalEmail(v, isRequired: false),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined), hintText: 'e.g. 9876543210'),
                              validator: (v) => AppValidators.validateMobileNumber(v, isRequired: false),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emergencyNameCtrl,
                              decoration: const InputDecoration(labelText: 'Emergency Contact Name', prefixIcon: Icon(Icons.person_add_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emergencyPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: const InputDecoration(labelText: 'Emergency Contact Phone', prefixIcon: Icon(Icons.phone_paused_outlined), hintText: 'e.g. 9876543210'),
                              validator: (v) => AppValidators.validateMobileNumber(v, isRequired: false, fieldName: 'Emergency phone'),
                            ),
                          ] else ...[
                            _buildInfoRow('Personal Email', targetEmployee.personalEmail ?? targetEmployee.employeeEmail ?? 'N/A', showCopyIcon: true),
                            _buildDivider(),
                            _buildInfoRow('Phone Number', targetEmployee.phoneNumber ?? 'N/A', showCopyIcon: true),
                            _buildDivider(),
                            _buildInfoRow('Emergency Contact', (targetEmployee.emergencyContactName != null && targetEmployee.emergencyContactName!.isNotEmpty)
                                ? '${targetEmployee.emergencyContactName} (${targetEmployee.emergencyContactPhone ?? "N/A"})'
                                : 'Not Specified'),
                          ],
                        ],
                      ),

                      // SECTION 4: Employment Details
                      _buildSectionCard(
                        title: 'Employment Details',
                        titleIcon: Icons.badge_rounded,
                        children: [
                          if (isEditMode && isAdminOrHR) ...[
                            DropdownButtonFormField<String>(
                              value: ['Full-time', 'Part-time', 'Contract', 'Internship'].contains(_selectedEmpType) ? _selectedEmpType : 'Full-time',
                              decoration: const InputDecoration(labelText: 'Employment Type', prefixIcon: Icon(Icons.work_outline)),
                              items: ['Full-time', 'Part-time', 'Contract', 'Internship'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) => setState(() => _selectedEmpType = val),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: ['active', 'suspended'].contains(_selectedStatus?.toLowerCase()) ? _selectedStatus!.toLowerCase() : 'active',
                              decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.shield_outlined)),
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Active')),
                                DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                              ],
                              onChanged: (val) => setState(() => _selectedStatus = val),
                            ),
                          ] else ...[
                            _buildInfoRow('Employment Type', targetEmployee.employmentType ?? 'Full-time'),
                            _buildDivider(),
                            _buildInfoRow('Status', targetEmployee.status.toUpperCase()),
                            _buildDivider(),
                            _buildInfoRow('Created Date', createdDateStr),
                            _buildDivider(),
                            _buildInfoRow('Last Login Time', lastLoginStr),
                          ],
                        ],
                      ),

                      // SECTION 5: Banking & Statutory
                      _buildSectionCard(
                        title: 'Banking & Statutory',
                        titleIcon: Icons.account_balance_rounded,
                        children: [
                          if (isEditMode) ...[
                            TextFormField(
                              controller: _bankNameCtrl,
                              decoration: const InputDecoration(labelText: 'Bank Name', prefixIcon: Icon(Icons.account_balance_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _accountNumCtrl,
                              decoration: const InputDecoration(labelText: 'Account Number', prefixIcon: Icon(Icons.credit_card_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ifscCtrl,
                              decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.numbers_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _panCtrl,
                              decoration: const InputDecoration(labelText: 'PAN Number', prefixIcon: Icon(Icons.subtitles_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _aadhaarCtrl,
                              decoration: const InputDecoration(labelText: 'Aadhaar Number', prefixIcon: Icon(Icons.fingerprint_outlined)),
                            ),
                          ] else ...[
                            _buildInfoRow('Bank Name', targetEmployee.bankName ?? 'Not Specified'),
                            _buildDivider(),
                            _buildInfoRow('Account Number', targetEmployee.accountNumber ?? 'Not Specified', showCopyIcon: true),
                            _buildDivider(),
                            _buildInfoRow('IFSC Code', targetEmployee.ifscCode ?? 'Not Specified', showCopyIcon: true),
                            _buildDivider(),
                            _buildInfoRow('PAN Number', targetEmployee.panNumber ?? 'Not Specified', showCopyIcon: true),
                            _buildDivider(),
                            _buildInfoRow('Aadhaar Number', targetEmployee.aadhaarNumber ?? 'Not Specified', showCopyIcon: true),
                          ],
                        ],
                      ),

                      // SECTION 6: Documents & Status Summary
                      Consumer(
                        builder: (context, ref, _) {
                          final docsAsync = ref.watch(adminEmployeeDocumentsProvider(targetEmployee.uid));
                          return docsAsync.when(
                            loading: () => _buildSectionCard(
                              title: 'Documents & Certificates',
                              titleIcon: Icons.folder_shared_rounded,
                              children: [const Center(child: CircularProgressIndicator())],
                            ),
                            error: (e, _) => _buildSectionCard(
                              title: 'Documents & Certificates',
                              titleIcon: Icons.folder_shared_rounded,
                              children: [Text('Error loading docs: $e')],
                            ),
                            data: (docs) {
                              final verified = docs.where((d) => d.verificationStatus.toLowerCase() == 'verified').length;
                              final pending = docs.where((d) => d.verificationStatus.toLowerCase() == 'pending').length;
                              final rejected = docs.where((d) => d.verificationStatus.toLowerCase() == 'rejected').length;
                              final missing = 4 - docs.length > 0 ? 4 - docs.length : 0;

                              return _buildSectionCard(
                                title: 'Document Status Summary',
                                titleIcon: Icons.folder_shared_rounded,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildDocSummaryMetric('Verified', verified, Colors.green),
                                      _buildDocSummaryMetric('Pending', pending, Colors.amber),
                                      _buildDocSummaryMetric('Rejected', rejected, Colors.red),
                                      _buildDocSummaryMetric('Missing', missing, Colors.grey),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EmployeeDocumentsScreen(employee: targetEmployee),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                      label: const Text('Open Documents →', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5B4CF0),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      // Action Buttons when in Edit Mode
                      if (isEditMode) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSavingProfile ? null : () => setState(() => isEditMode = false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel Changes', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSavingProfile ? null : _saveProfileChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B4CF0),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: isSavingProfile
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Save Profile', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
              backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
              foregroundColor: const Color(0xFF5B4CF0),
              elevation: 0,
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3)),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF474555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFC8C4D8).withOpacity(0.3);
    final dividerCol = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(titleIcon, size: 20, color: const Color(0xFF5B4CF0)),
                const SizedBox(width: 10),
                SelectableText(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF191C1F),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: dividerCol),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocSummaryMetric(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool showCopyIcon = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SelectableText(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF191C1F),
                  ),
                ),
              ),
              if (showCopyIcon && value != 'N/A' && value != 'Not Specified' && value.isNotEmpty) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied.'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.content_copy_rounded,
                      size: 13,
                      color: Color(0xFF5B4CF0),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
    );
  }

  void _showNoCredentialsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF5B4CF0)),
            SizedBox(width: 8),
            Text('No Login Credentials', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This employee does not have login credentials yet.\n\nWould you like to create login credentials for this employee now?',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _handleCreateCredentials(context);
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Create Login Credentials'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCreateCredentials(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.microtask(() async {
          try {
            final result = await ref.read(adminEmployeesProvider.notifier).createCredentialsForEmployee(_employeeState);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              setState(() {
                _employeeState = _employeeState.copyWith(
                  companyEmail: result['companyEmail'],
                  email: result['companyEmail'] ?? _employeeState.email,
                  employeeId: result['employeeId'],
                  tempPassword: result['tempPassword'],
                );
              });
              _showCredentialsCreatedDialog(context, _employeeState.name, result['companyEmail'] ?? '');
            }
          } catch (e, stack) {
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
              );
            }
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Creating login credentials...')),
            ],
          ),
        );
      },
    );
  }

  void _showCredentialsCreatedDialog(BuildContext context, String name, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Credentials Created', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          ],
        ),
        content: Text(
          'Login account created for $name ($email).\n\nAn email password reset link can now be dispatched to the employee to set up their password securely.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
            child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleResetPassword(BuildContext context, String uid, String name) {
    final email = _employeeState.email.isNotEmpty ? _employeeState.email : _employeeState.companyEmail;
    final hasEmail = email != null && email.contains('@');

    if (!hasEmail) {
      _showNoCredentialsDialog(context);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF5B4CF0)),
            SizedBox(width: 8),
            Text('Reset Employee Password', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Send password reset email link to $name ($email)?\n\n'
          'The employee will receive an email containing a secure link to create a new password.',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Inter')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _showResetProgressDialog(context, email, name, uid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4CF0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Reset Link', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetProgressDialog(BuildContext context, String email, String name, String uid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.microtask(() async {
          try {
            await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
            await FirebaseFirestore.instance.collection('users').doc(uid).update({'mustChangePassword': true});
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                      SizedBox(width: 8),
                      Text('Reset Link Sent', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    ],
                  ),
                  content: Text(
                    'A password reset link has been successfully sent to $name ($email).\n\nThey will be prompted to set a new password.',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF475569)),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(c),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
                      child: const Text('OK', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
          } catch (e, stack) {
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
              );
            }
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Sending reset link email...', style: TextStyle(fontFamily: 'Inter'))),
            ],
          ),
        );
      },
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFF5B4CF0)),
              SizedBox(width: 8),
              Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: currentPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current Password *', prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password *', prefixIcon: Icon(Icons.lock_reset)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New Password *', prefixIcon: Icon(Icons.check_circle_outline)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Inter')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B4CF0), foregroundColor: Colors.white),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final currentPass = currentPassCtrl.text.trim();
                      final newPass = newPassCtrl.text.trim();
                      final confirmPass = confirmPassCtrl.text.trim();

                      if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in all password fields.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      if (newPass != confirmPass) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('New passwords do not match.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final validation = PasswordValidator.validate(newPass);
                      if (!validation.isValid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters long.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setModalState(() => isSubmitting = true);
                      try {
                        final success = await ref.read(authProvider.notifier).updatePassword(
                          newPass,
                          currentPassword: currentPass,
                        );

                        if (success && mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully.'),
                              backgroundColor: Color(0xFF22C55E),
                            ),
                          );
                        } else {
                          setModalState(() => isSubmitting = false);
                        }
                      } catch (e, stack) {
                        setModalState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppErrorHandler.parseError(e, stack)), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
