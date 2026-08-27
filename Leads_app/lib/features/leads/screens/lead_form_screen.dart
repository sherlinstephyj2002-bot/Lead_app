import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/lead_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/utils/app_validators.dart';
import '../../../shared/utils/app_notification.dart';

class LeadFormScreen extends ConsumerStatefulWidget {
  final LeadModel? leadToEdit;

  const LeadFormScreen({super.key, this.leadToEdit});

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  late TextEditingController _emailController;
  late TextEditingController _locationController;
  late TextEditingController _requirementController;
  late TextEditingController _remarksController;
  late String _selectedSource;
  late String _selectedEmployeeId;
  late String _selectedEmployeeName;

  final List<String> _sources = ['Direct', 'Referral', 'Web Inquiry', 'Exhibition', 'Cold Call', 'Others'];

  @override
  void initState() {
    super.initState();
    final edit = widget.leadToEdit;
    _nameController = TextEditingController(text: edit?.customerName ?? '');
    _phoneController = TextEditingController(text: edit?.mobileNumber ?? '');
    _companyController = TextEditingController(text: edit?.companyName ?? '');
    _emailController = TextEditingController(text: edit?.email ?? '');
    _locationController = TextEditingController(text: edit?.location ?? '');
    _requirementController = TextEditingController(text: edit?.requirement ?? '');
    _remarksController = TextEditingController(text: edit?.remarks ?? '');
    _selectedSource = edit?.leadSource ?? 'Direct';

    final user = ref.read(authProvider).user;
    _selectedEmployeeId = edit?.assignedToId ?? user?.uid ?? '';
    _selectedEmployeeName = edit?.assignedTo ?? user?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _requirementController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final notifier = ref.read(leadsProvider.notifier);
      final user = ref.read(authProvider).user;
      if (user == null) return;

      if (widget.leadToEdit != null) {
        // Edit existing lead
        final updatedLead = widget.leadToEdit!.copyWith(
          customerName: _nameController.text.trim(),
          mobileNumber: _phoneController.text.trim(),
          companyName: _companyController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          location: _locationController.text.trim(),
          requirement: _requirementController.text.trim(),
          remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
          leadSource: _selectedSource,
          assignedTo: _selectedEmployeeName,
          assignedToId: _selectedEmployeeId,
          updatedAt: DateTime.now(),
        );
        await notifier.updateLead(updatedLead);
        if (mounted) {
          context.pop();
          AppNotification.showSuccess(context, 'Lead updated successfully');
        }
      } else {
        // Create new lead
        await notifier.addLead(
          _nameController.text.trim(),
          _phoneController.text.trim(),
          _companyController.text.trim(),
          _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          _locationController.text.trim(),
          _requirementController.text.trim(),
          _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
          _selectedSource,
          assignedToId: _selectedEmployeeId,
          assignedToName: _selectedEmployeeName,
        );
        if (mounted) {
          context.pop();
          AppNotification.showSuccess(context, 'Lead saved successfully');
        }
      }
    }
  }

  InputDecoration _buildStitchInputDecoration({
    required String hint,
    required IconData prefixIcon,
    bool isRequired = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: fillBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCol),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderCol),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Color(0xFF5B4CF0), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = true, String? optionalText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF334155);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Outfit'),
          children: [
            if (isRequired)
              const TextSpan(text: ' *', style: TextStyle(color: Color(0xFF5B4CF0), fontWeight: FontWeight.bold))
            else if (optionalText != null)
              TextSpan(text: ' $optionalText', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.leadToEdit != null;
    final currentUser = ref.watch(authProvider).user;
    final userInitials = currentUser?.name.isNotEmpty == true ? currentUser!.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase() : 'WA';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F9FB);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dividerCol = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B4CF0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Lead Details' : 'Add New Lead',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                userInitials,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 1: Customer Information
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: headerBg,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: dividerCol)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Text(
                                'CUSTOMER INFORMATION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Form Body
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 550;
                              return Column(
                                children: [
                                  if (isWide) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Customer Name'),
                                              TextFormField(
                                                controller: _nameController,
                                                decoration: _buildStitchInputDecoration(hint: 'Enter full name', prefixIcon: Icons.person_outline_rounded),
                                                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter customer name' : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Mobile Number', isRequired: false, optionalText: '(Optional)'),
                                              TextFormField(
                                                controller: _phoneController,
                                                keyboardType: TextInputType.phone,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(10),
                                                ],
                                                decoration: _buildStitchInputDecoration(hint: 'Phone number (optional)', prefixIcon: Icons.phone_outlined, isRequired: false),
                                                validator: (v) => AppValidators.validateMobileNumber(v, isRequired: false),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Company Name'),
                                              TextFormField(
                                                controller: _companyController,
                                                decoration: _buildStitchInputDecoration(hint: 'Acme Corp', prefixIcon: Icons.business_rounded),
                                                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter company name' : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Email Address', isRequired: false, optionalText: '(Optional)'),
                                              TextFormField(
                                                controller: _emailController,
                                                keyboardType: TextInputType.emailAddress,
                                                decoration: _buildStitchInputDecoration(hint: 'alex@company.com', prefixIcon: Icons.mail_outline_rounded, isRequired: false),
                                                validator: (v) => AppValidators.validatePersonalEmail(v, isRequired: false),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Customer Name'),
                                        TextFormField(
                                          controller: _nameController,
                                          decoration: _buildStitchInputDecoration(hint: 'Enter full name', prefixIcon: Icons.person_outline_rounded),
                                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter customer name' : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFieldLabel('Mobile Number', isRequired: false, optionalText: '(Optional)'),
                                        TextFormField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                          decoration: _buildStitchInputDecoration(hint: 'Phone number (optional)', prefixIcon: Icons.phone_outlined, isRequired: false),
                                          validator: (v) => AppValidators.validateMobileNumber(v, isRequired: false),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFieldLabel('Company Name'),
                                        TextFormField(
                                          controller: _companyController,
                                          decoration: _buildStitchInputDecoration(hint: 'Acme Corp', prefixIcon: Icons.business_rounded),
                                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter company name' : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFieldLabel('Email Address', isRequired: false, optionalText: '(Optional)'),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType: TextInputType.emailAddress,
                                          decoration: _buildStitchInputDecoration(hint: 'alex@company.com', prefixIcon: Icons.mail_outline_rounded, isRequired: false),
                                          validator: (v) => AppValidators.validatePersonalEmail(v, isRequired: false),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: Lead Details
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: headerBg,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: dividerCol)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.work_outline_rounded, size: 18, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Text(
                                'LEAD DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Form Body
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 550;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isWide) ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Location / City'),
                                              TextFormField(
                                                controller: _locationController,
                                                decoration: _buildStitchInputDecoration(hint: 'San Francisco, CA', prefixIcon: Icons.location_on_outlined),
                                                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter location' : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Requirement / Scope'),
                                              TextFormField(
                                                controller: _requirementController,
                                                decoration: _buildStitchInputDecoration(hint: 'ERP Implementation', prefixIcon: Icons.description_outlined),
                                                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter requirement' : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Lead Source'),
                                              DropdownButtonFormField<String>(
                                                value: _selectedSource,
                                                decoration: _buildStitchInputDecoration(hint: 'Select Lead Source', prefixIcon: Icons.layers_outlined),
                                                isExpanded: true,
                                                items: _sources.map((src) => DropdownMenuItem(
                                                  value: src,
                                                  child: Text(src, overflow: TextOverflow.ellipsis),
                                                )).toList(),
                                                onChanged: (val) {
                                                  if (val != null) setState(() => _selectedSource = val);
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildFieldLabel('Assign To'),
                                              ref.watch(companyEmployeesProvider).when(
                                                data: (employees) {
                                                  final allAssignees = [currentUser, ...employees].whereType<UserModel>().toList();
                                                  final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();

                                                  if (!uniqueAssignees.any((e) => e.uid == _selectedEmployeeId)) {
                                                    final firstAssignee = uniqueAssignees.isNotEmpty ? uniqueAssignees.first : null;
                                                    _selectedEmployeeId = firstAssignee?.uid ?? '';
                                                    _selectedEmployeeName = firstAssignee?.name ?? '';
                                                  }

                                                  return DropdownButtonFormField<String>(
                                                    value: _selectedEmployeeId.isEmpty && uniqueAssignees.isNotEmpty ? uniqueAssignees.first.uid : _selectedEmployeeId,
                                                    decoration: _buildStitchInputDecoration(hint: 'Assign To', prefixIcon: Icons.person_add_alt_1_outlined),
                                                    isExpanded: true,
                                                    items: uniqueAssignees.map((emp) => DropdownMenuItem(
                                                      value: emp.uid,
                                                      child: Text(
                                                        emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    )).toList(),
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        final selected = uniqueAssignees.firstWhere((e) => e.uid == val);
                                                        setState(() {
                                                          _selectedEmployeeId = selected.uid;
                                                          _selectedEmployeeName = selected.name;
                                                        });
                                                      }
                                                    },
                                                  );
                                                },
                                                loading: () => const Center(child: CircularProgressIndicator()),
                                                error: (err, _) => Text('Error loading employees: $err', style: const TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('Location / City'),
                                        TextFormField(
                                          controller: _locationController,
                                          decoration: _buildStitchInputDecoration(hint: 'San Francisco, CA', prefixIcon: Icons.location_on_outlined),
                                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter location' : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFieldLabel('Requirement / Scope'),
                                        TextFormField(
                                          controller: _requirementController,
                                          decoration: _buildStitchInputDecoration(hint: 'ERP Implementation', prefixIcon: Icons.description_outlined),
                                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter requirement' : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFieldLabel('Lead Source'),
                                        DropdownButtonFormField<String>(
                                          value: _selectedSource,
                                          decoration: _buildStitchInputDecoration(hint: 'Select Lead Source', prefixIcon: Icons.layers_outlined),
                                          isExpanded: true,
                                          items: _sources.map((src) => DropdownMenuItem(
                                            value: src,
                                            child: Text(src, overflow: TextOverflow.ellipsis),
                                          )).toList(),
                                          onChanged: (val) {
                                            if (val != null) setState(() => _selectedSource = val);
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildFieldLabel('Assign To'),
                                        ref.watch(companyEmployeesProvider).when(
                                          data: (employees) {
                                            final allAssignees = [currentUser, ...employees].whereType<UserModel>().toList();
                                            final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();

                                            if (!uniqueAssignees.any((e) => e.uid == _selectedEmployeeId)) {
                                              final firstAssignee = uniqueAssignees.isNotEmpty ? uniqueAssignees.first : null;
                                              _selectedEmployeeId = firstAssignee?.uid ?? '';
                                              _selectedEmployeeName = firstAssignee?.name ?? '';
                                            }

                                            return DropdownButtonFormField<String>(
                                              value: _selectedEmployeeId.isEmpty && uniqueAssignees.isNotEmpty ? uniqueAssignees.first.uid : _selectedEmployeeId,
                                              decoration: _buildStitchInputDecoration(hint: 'Assign To', prefixIcon: Icons.person_add_alt_1_outlined),
                                              isExpanded: true,
                                              items: uniqueAssignees.map((emp) => DropdownMenuItem(
                                                value: emp.uid,
                                                child: Text(
                                                  emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              )).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  final selected = uniqueAssignees.firstWhere((e) => e.uid == val);
                                                  setState(() {
                                                    _selectedEmployeeId = selected.uid;
                                                    _selectedEmployeeName = selected.name;
                                                  });
                                                }
                                              },
                                            );
                                          },
                                          loading: () => const Center(child: CircularProgressIndicator()),
                                          error: (err, _) => Text('Error loading employees: $err', style: const TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _buildFieldLabel('Additional Remarks / Notes', isRequired: false, optionalText: '(Optional)'),
                                  TextFormField(
                                    controller: _remarksController,
                                    maxLines: 3,
                                    decoration: _buildStitchInputDecoration(hint: 'Enter any additional details...', prefixIcon: Icons.notes_rounded, isRequired: false),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // SUBMIT ACTION BUTTON
                  ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: Text(
                      isEditing ? 'Save Changes' : 'Create CRM Lead',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4CF0),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF5B4CF0).withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'All mandatory fields marked with an asterisk (*) must be completed before submission.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
