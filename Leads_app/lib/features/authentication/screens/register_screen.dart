import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/providers.dart';
import '../../../constants/user_roles.dart';
import '../../../shared/services/password_validator.dart';
import '../../../shared/utils/app_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Admin Controllers
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Company Controllers
  final _companyNameController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _companyMobileController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipController = TextEditingController();
  final _gstVatController = TextEditingController();
  final _websiteController = TextEditingController();

  String _companyType = 'Field Service';
  String _timeZone = 'UTC+05:30 — India Standard Time';

  // Optional Logo upload variables
  Uint8List? _logoBytes;
  String? _logoUrl;

  final List<String> _companyTypes = [
    'Field Service',
    'Retail',
    'Wholesale',
    'Manufacturing',
    'Consulting',
    'Technology',
    'Other'
  ];

  final List<String> _timeZones = [
    'UTC',
    'UTC+05:30 — India Standard Time',
    'UTC-05:00 — Eastern Standard Time',
    'UTC+00:00 — Greenwich Mean Time',
    'UTC+01:00 — Central European Time',
    'UTC+08:00 — Singapore Standard Time',
    'UTC+09:00 — Korea Standard Time',
    'UTC-08:00 — Pacific Standard Time',
    'UTC+10:00 — Australian Eastern Time',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _businessEmailController.dispose();
    _companyMobileController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _gstVatController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      var bytes = file.bytes;

      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await io.File(file.path!).readAsBytes();
      }

      if (bytes == null) return;

      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo size exceeds 2MB limit.')),
          );
        }
        return;
      }

      final base64Str = base64Encode(bytes);
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'png';
      final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';

      setState(() {
        _logoBytes = bytes;
        _logoUrl = 'data:$mime;base64,$base64Str';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick logo: $e')),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBytes = null;
      _logoUrl = null;
    });
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).register(
        name: _nameController.text.trim(),
        email: _businessEmailController.text.trim(),
        password: _passwordController.text,
        companyName: _companyNameController.text.trim(),
        companyType: _companyType,
        businessEmail: _businessEmailController.text.trim(),
        companyMobile: _companyMobileController.text.trim(),
        country: _countryController.text.trim(),
        stateAddress: _stateController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        zip: _zipController.text.trim(),
        timeZone: _timeZone,
        gstVat: _gstVatController.text.trim(),
        website: _websiteController.text.trim(),
        role: UserRoles.companyAdmin,
        phoneNumber: _companyMobileController.text.trim(),
        logoUrl: _logoUrl,
      );

      if (success && mounted) {
        context.go('/verify-email');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF8FAFC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Create Your Company', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cardBg,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 750 : double.infinity),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header / Intro
                    const Text(
                      'Create Your Company',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set up your company workspace and verify your business email to continue.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 24),

                    if (authState.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SECTION A: Company Information
                    _buildSectionCard(
                      title: 'Company Information',
                      subtitle: 'Basic details about your organization',
                      icon: Icons.business_rounded,
                      children: [
                        const Text('Company Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _companyNameController,
                          decoration: const InputDecoration(hintText: 'e.g. Acme Corporation', prefixIcon: Icon(Icons.business)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required.' : null,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Company Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _companyType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                                    items: _companyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _companyType = val);
                                    },
                                    validator: (v) => v == null || v.isEmpty ? 'Company type is required.' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Company Mobile Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _companyMobileController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(hintText: 'Enter contact phone number', prefixIcon: Icon(Icons.phone_outlined)),
                                    validator: (v) => AppValidators.validateCompanyPhone(v, isRequired: true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text('Business Email *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _businessEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(hintText: 'admin@company.com', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) => AppValidators.validateBusinessEmail(v, isRequired: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION B: Company Address
                    _buildSectionCard(
                      title: 'Company Address',
                      subtitle: 'Worldwide business location details',
                      icon: Icons.location_on_outlined,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Country *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _countryController,
                                    decoration: const InputDecoration(hintText: 'Enter country'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Country is required.' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('State / Province *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _stateController,
                                    decoration: const InputDecoration(hintText: 'Enter state or province'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'State / Province is required.' : null,
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
                                  const Text('City *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _cityController,
                                    decoration: const InputDecoration(hintText: 'Enter city'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'City is required.' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Postal Code *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _zipController,
                                    decoration: const InputDecoration(hintText: 'Enter postal code'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Postal code is required.' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text('Address *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(hintText: 'Enter full address'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Address is required.' : null,
                        ),
                        const SizedBox(height: 16),

                        const Text('Time Zone *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _timeZone,
                          isExpanded: true,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                          items: _timeZones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _timeZone = val);
                          },
                          validator: (v) => v == null || v.isEmpty ? 'Time zone is required.' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION C: Company Branding
                    _buildSectionCard(
                      title: 'Company Branding',
                      subtitle: 'Company logo and web address (Optional)',
                      icon: Icons.palette_outlined,
                      children: [
                        const Text('Company Logo (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: _logoBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.business_rounded, color: Color(0xFF94A3B8), size: 32),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.upload_rounded, size: 18),
                                  label: Text(_logoBytes == null ? 'Upload Logo' : 'Replace Logo'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                if (_logoBytes != null) ...[
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: _removeLogo,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Remove Logo', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text('Website (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _websiteController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(hintText: 'https://company.com', prefixIcon: Icon(Icons.language_rounded)),
                          validator: (v) => AppValidators.validateWebsite(v),
                        ),
                        const SizedBox(height: 12),

                        const Text('GST / VAT Tax ID (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _gstVatController,
                          decoration: const InputDecoration(hintText: 'e.g. Tax / Registration ID', prefixIcon: Icon(Icons.receipt_long_outlined)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION D: Admin Account Setup
                    _buildSectionCard(
                      title: 'Admin Account Setup',
                      subtitle: 'Credentials for the primary administrator account',
                      icon: Icons.admin_panel_settings_outlined,
                      children: [
                        const Text('Admin Full Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(hintText: 'e.g. John Doe', prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                        ),
                        const SizedBox(height: 16),

                        const Text('Password *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (v) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Enter strong password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => PasswordValidator.validate(v ?? '').isValid ? null : 'Password must be at least 6 characters',
                        ),
                        const SizedBox(height: 12),
                        _buildPasswordRequirementsList(),
                        const SizedBox(height: 16),

                        const Text('Confirm Password *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          onChanged: (v) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Re-enter password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (v) => (v == _passwordController.text) ? null : 'Passwords do not match',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Create Company', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRequirementsList() {
    final password = _passwordController.text;
    final result = PasswordValidator.validate(password);

    return Row(
      children: [
        Icon(
          result.isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: result.isValid ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Minimum 6 characters',
          style: TextStyle(
            fontSize: 12,
            color: result.isValid ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            fontWeight: result.isValid ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
