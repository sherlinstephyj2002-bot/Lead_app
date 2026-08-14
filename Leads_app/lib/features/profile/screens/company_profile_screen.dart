import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/company_model.dart';
import '../../../constants/user_roles.dart';
import '../../../constants/feature_flags.dart';
import '../../../shared/widgets/company_logo_avatar.dart';
import '../../../shared/utils/app_validators.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _businessEmailController;
  late TextEditingController _companyMobileController;
  late TextEditingController _gstVatController;
  late TextEditingController _websiteController;
  late TextEditingController _emailDomainController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipController;
  late TextEditingController _countryController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _radiusController;

  String _companyType = 'Field Service';
  String _timeZone = 'UTC+05:30 (India)';
  bool _isSaving = false;
  bool _isInitialized = false;

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
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _businessEmailController = TextEditingController();
    _companyMobileController = TextEditingController();
    _gstVatController = TextEditingController();
    _websiteController = TextEditingController();
    _emailDomainController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _zipController = TextEditingController();
    _countryController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _radiusController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final company = ref.read(companyProvider).value;
      if (company != null) {
        _initFields(company);
      }
    });
  }

  void _initFields(CompanyModel company) {
    _nameController.text = company.name;
    _businessEmailController.text = company.businessEmail;
    _companyMobileController.text = company.companyMobile;
    _gstVatController.text = company.gstVat;
    _websiteController.text = company.website;
    _emailDomainController.text = company.emailDomain ?? '';
    _addressController.text = company.address;
    _cityController.text = company.city;
    _stateController.text = company.state;
    _zipController.text = company.zip;
    _countryController.text = company.country;
    _companyType = company.companyType.isNotEmpty ? company.companyType : 'Field Service';
    _timeZone = _timeZones.contains(company.timeZone)
        ? company.timeZone
        : (_timeZones.firstWhere((tz) => tz.contains(company.timeZone), orElse: () => 'UTC+05:30 — India Standard Time'));
    
    if (company.geofenceLat != null) _latController.text = company.geofenceLat.toString();
    if (company.geofenceLng != null) _lngController.text = company.geofenceLng.toString();
    if (company.geofenceRadius != null) _radiusController.text = company.geofenceRadius.toString();
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessEmailController.dispose();
    _companyMobileController.dispose();
    _gstVatController.dispose();
    _websiteController.dispose();
    _emailDomainController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
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

      if (fileBytes.lengthInBytes > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo size exceeds the 2MB limit.')),
          );
        }
        return;
      }

      setState(() => _isSaving = true);
      final success = await ref.read(companyProvider.notifier).uploadLogo(fileName, fileBytes);
      setState(() => _isSaving = false);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company logo uploaded successfully.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload logo.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _isSaving = true);
    final success = await ref.read(companyProvider.notifier).removeLogo();
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company logo removed successfully.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove logo.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _saveCompanyDetails() async {
    if (!_formKey.currentState!.validate()) return;
    
    final company = ref.read(companyProvider).value;
    if (company == null) return;

    setState(() => _isSaving = true);
    
    final updatedCompany = company.copyWith(
      name: _nameController.text.trim(),
      companyType: _companyType,
      businessEmail: _businessEmailController.text.trim(),
      companyMobile: _companyMobileController.text.trim(),
      gstVat: _gstVatController.text.trim(),
      website: _websiteController.text.trim(),
      emailDomain: _emailDomainController.text.trim().isEmpty ? null : _emailDomainController.text.trim().toLowerCase(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      zip: _zipController.text.trim(),
      country: _countryController.text.trim(),
      timeZone: _timeZone,
      geofenceLat: double.tryParse(_latController.text),
      geofenceLng: double.tryParse(_lngController.text),
      geofenceRadius: double.tryParse(_radiusController.text),
    );

    final success = await ref.read(companyProvider.notifier).updateCompany(updatedCompany);
    setState(() => _isSaving = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile updated successfully.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update company profile.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyState = ref.watch(companyProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF7F8FC);
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Company Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF5B4CF0))),
        backgroundColor: cardBg,
        foregroundColor: titleColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderCol, height: 1),
        ),
      ),
      body: companyState.when(
        data: (company) {
          if (company == null) {
            return const Center(child: Text('Company details not found.'));
          }

          if (!_isInitialized) {
            _initFields(company);
          }

          final createdAtStr = DateFormat('dd MMMM yyyy').format(company.createdAt);

          final mainFormContent = Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Hero Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 3),
                            ),
                            child: CompanyLogoAvatar(
                              companyId: company.companyId,
                              radius: 44,
                              backgroundColor: const Color(0xFF5B4CF0).withOpacity(0.08),
                              iconColor: const Color(0xFF5B4CF0),
                            ),
                          ),
                          if (isAdmin && FeatureFlags.enableImageUpload)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: const Color(0xFF5B4CF0),
                                elevation: 2,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _isSaving ? null : _pickAndUploadLogo,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  company.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.workspace_premium_rounded, color: Color(0xFF007834), size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Premium',
                                        style: TextStyle(color: Color(0xFF007834), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_companyType}  •  ${_timeZone}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            _buildCompanyInfoCard(isAdmin, company),
                            const SizedBox(height: 24),
                            _buildAddressGeofenceCard(isAdmin, company),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildSubscriptionInfoCard(company, createdAtStr),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildCompanyInfoCard(isAdmin, company),
                      const SizedBox(height: 24),
                      _buildAddressGeofenceCard(isAdmin, company),
                      const SizedBox(height: 24),
                      _buildSubscriptionInfoCard(company, createdAtStr),
                    ],
                  ),

                if (isAdmin) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveCompanyDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4CF0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Save Configurations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: mainFormContent,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading company: $err')),
      ),
    );
  }

  Widget _buildCompanyInfoCard(bool isAdmin, CompanyModel company) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fillBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF5B4CF0), size: 20),
              const SizedBox(width: 8),
              Text(
                'Company Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Company Name *',
            controller: _nameController,
            enabled: isAdmin,
            validator: (v) => v == null || v.trim().isEmpty ? 'Company name required' : null,
          ),
          const SizedBox(height: 20),
          _buildReadOnlyField(
            label: 'Company Code (Read Only)',
            value: company.companyCode ?? 'N/A',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Business Email *',
            controller: _businessEmailController,
            enabled: isAdmin,
            hint: 'info@company.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => AppValidators.validateBusinessEmail(v, isRequired: true),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Company Mobile / Landline',
            controller: _companyMobileController,
            enabled: isAdmin,
            hint: 'e.g. 9876543210',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) => AppValidators.validateMobileNumber(v, isRequired: false, fieldName: 'Company Mobile'),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Company Website',
            controller: _websiteController,
            enabled: isAdmin,
            hint: 'www.jasscreative.com',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Official Employee Email Domain',
            controller: _emailDomainController,
            enabled: isAdmin,
            hint: 'jasscreative.com (Used for employee email creation)',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 450;
              final companyTypeCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Company Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _companyType,
                    isExpanded: true,
                    items: _companyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: titleColor)))).toList(),
                    onChanged: isAdmin ? (val) {
                      if (val != null) setState(() => _companyType = val);
                    } : null,
                    dropdownColor: cardBg,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: fillBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderCol),
                      ),
                    ),
                  ),
                ],
              );

              final timeZoneCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Time Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _timeZone,
                    isExpanded: true,
                    items: _timeZones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: titleColor)))).toList(),
                    onChanged: isAdmin ? (val) {
                      if (val != null) setState(() => _timeZone = val);
                    } : null,
                    dropdownColor: cardBg,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: fillBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderCol),
                      ),
                    ),
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  children: [
                    companyTypeCol,
                    const SizedBox(height: 16),
                    timeZoneCol,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: companyTypeCol),
                  const SizedBox(width: 16),
                  Expanded(child: timeZoneCol),
                ],
              );
            },
          ),
          if (isAdmin && company.logoUrl != null && company.logoUrl!.isNotEmpty) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _isSaving ? null : _removeLogo,
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBA1A1A), size: 18),
              label: const Text(
                'Remove Logo',
                style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressGeofenceCard(bool isAdmin, CompanyModel company) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          leading: const Icon(Icons.settings_applications_rounded, color: Color(0xFF5B4CF0)),
          title: Text(
            'Advanced & Technical Configurations',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
          ),
          children: [
            _buildReadOnlyField(
              label: 'Tenant ID (Internal Database Identifier)',
              value: company.companyId,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'GST / VAT Tax ID',
                    controller: _gstVatController,
                    enabled: isAdmin,
                    hint: 'Tax Registration',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'Website URL',
                    controller: _websiteController,
                    enabled: isAdmin,
                    hint: 'www.company.com',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: borderCol),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Color(0xFF5B4CF0), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Attendance Geofencing Settings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Office Latitude',
                    controller: _latController,
                    enabled: isAdmin,
                    hint: 'e.g. 12.9716',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'Office Longitude',
                    controller: _lngController,
                    enabled: isAdmin,
                    hint: 'e.g. 77.5946',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Geofence Radius (meters)',
              controller: _radiusController,
              enabled: isAdmin,
              hint: 'e.g. 200',
            ),
            const SizedBox(height: 20),
            Divider(color: borderCol),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.home_work_rounded, color: Color(0xFF5B4CF0), size: 18),
                const SizedBox(width: 6),
                Text(
                  'Street Address',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Address Line',
              controller: _addressController,
              enabled: isAdmin,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'City / Town',
                    controller: _cityController,
                    enabled: isAdmin,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'State / Province / Region',
                    controller: _stateController,
                    enabled: isAdmin,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'ZIP / Postal Code',
                    controller: _zipController,
                    enabled: isAdmin,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'Country / Region',
                    controller: _countryController,
                    enabled: isAdmin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionInfoCard(CompanyModel company, String createdAtStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Theme.of(context).cardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payment_rounded, color: Color(0xFF5B4CF0), size: 20),
              const SizedBox(width: 8),
              Text(
                'Subscription Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildReadOnlyField(
            label: 'Subscription Plan',
            value: company.subscriptionPlan.toUpperCase(),
          ),
          const SizedBox(height: 20),
          _buildReadOnlyField(
            label: 'Billing Status',
            value: company.status.toUpperCase(),
          ),
          const SizedBox(height: 20),
          _buildReadOnlyField(
            label: 'Creation Date',
            value: createdAtStr,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fillBg = enabled
        ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(fontSize: 14, color: titleColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: fillBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final fillBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: fillBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: titleColor),
          ),
        ),
      ],
    );
  }
}
