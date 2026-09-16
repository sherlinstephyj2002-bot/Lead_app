import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/app_validators.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  // Employee Password Reset Form Controllers
  final _empFormKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _reasonController = TextEditingController(
    text: 'I forgot my password and need assistance accessing my WorkTrack account.',
  );

  // Company Admin Form Controllers
  final _adminFormKey = GlobalKey<FormState>();
  final _adminEmailController = TextEditingController();

  // Flow State
  int _employeeStep = 1; // 1: Form, 2: Success
  bool _adminSubmittedSuccess = false;

  // Rate Limiting Cooldown
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _employeeIdController.dispose();
    _reasonController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  bool _checkCooldown() {
    if (_cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!)) {
      final remaining = _cooldownUntil!.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too many failed attempts. Please wait $remaining seconds before trying again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  void _handleEmployeeRequestSubmit() async {
    if (!_checkCooldown()) return;

    if (_empFormKey.currentState!.validate()) {
      final success = await ref
          .read(passwordResetProvider.notifier)
          .submitEmployeeRequest(
            employeeId: _employeeIdController.text.trim(),
            reason: _reasonController.text.trim(),
          );

      if (mounted) {
        if (success) {
          setState(() {
            _employeeStep = 2; // Success screen
            _failedAttempts = 0;
          });
        } else {
          _failedAttempts++;
          if (_failedAttempts >= 3) {
            setState(() {
              _cooldownUntil = DateTime.now().add(const Duration(minutes: 3));
            });
          }
        }
      }
    }
  }

  void _handleAdminEmailReset() async {
    if (_adminFormKey.currentState!.validate()) {
      final email = _adminEmailController.text.trim();
      final success = await ref.read(authProvider.notifier).sendPasswordReset(email);

      if (mounted && success) {
        setState(() {
          _adminSubmittedSuccess = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordResetState = ref.watch(passwordResetProvider);
    final authState = ref.watch(authProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF5B4CF0);
    const primaryAccentColor = Color(0xFF4338CA);

    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: borderCol),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, size: 18, color: titleColor),
            onPressed: () {
              if (_employeeStep > 1) {
                setState(() => _employeeStep = 1);
              } else {
                context.pop();
              }
            },
            tooltip: 'Back',
          ),
        ),
        title: Text(
          'Password Recovery',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: titleColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.06),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Lock Icon & Titles
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withValues(alpha: 0.15),
                                  primaryAccentColor.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 38,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Password Recovery',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select your WorkTrack role to proceed with account recovery',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: subtitleColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Segmented Role Switcher
                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: subtitleColor,
                        labelStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.badge_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('Employee Reset'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.admin_panel_settings_outlined, size: 16),
                                SizedBox(width: 6),
                                Text('Admin Email'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tab Body
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _activeTabIndex == 0
                          ? _buildEmployeeRecoveryTab(
                              passwordResetState,
                              primaryColor,
                              titleColor,
                              subtitleColor,
                              borderCol,
                              inputBg,
                              isDark,
                            )
                          : _buildAdminTab(
                              authState,
                              primaryColor,
                              titleColor,
                              subtitleColor,
                              borderCol,
                              inputBg,
                              isDark,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- TAB 1: EMPLOYEE RECOVERY FLOW ----------------
  Widget _buildEmployeeRecoveryTab(
    PasswordResetState state,
    Color primaryColor,
    Color titleColor,
    Color subtitleColor,
    Color borderCol,
    Color inputBg,
    bool isDark,
  ) {
    // STEP 2: SUCCESS VIEW
    if (_employeeStep == 2) {
      return Column(
        key: const ValueKey('emp_step2_success'),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 52,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Request Submitted',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                Text(
                  'Password reset request submitted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Company Administrator has been notified. Please contact your administrator for further assistance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: subtitleColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(
                'Return to Login',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    // STEP 1: FORM
    return Form(
      key: _empFormKey,
      child: Column(
        key: const ValueKey('emp_step1_form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Reset Request',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your Employee ID and tell your administrator why you need a password reset.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: subtitleColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(fontFamily: 'Inter', color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            'Employee ID *',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: titleColor),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _employeeIdController,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: titleColor),
            decoration: _buildInputDecoration(
              hintText: 'e.g. JAS001-0002',
              prefixIcon: Icons.badge_outlined,
              inputBg: inputBg,
              borderCol: borderCol,
              primaryColor: primaryColor,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your Employee ID.' : null,
          ),
          const SizedBox(height: 16),

          Text(
            'Reason for Password Reset *',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: titleColor),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: titleColor),
            decoration: _buildInputDecoration(
              hintText: 'Describe why you need a password reset...',
              prefixIcon: Icons.description_outlined,
              inputBg: inputBg,
              borderCol: borderCol,
              primaryColor: primaryColor,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a reason for your password reset.' : null,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : _handleEmployeeRequestSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Submit Request',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- TAB 2: ADMIN EMAIL RECOVERY ----------------
  Widget _buildAdminTab(
    AuthState state,
    Color primaryColor,
    Color titleColor,
    Color subtitleColor,
    Color borderCol,
    Color inputBg,
    bool isDark,
  ) {
    if (_adminSubmittedSuccess) {
      return Column(
        key: const ValueKey('admin_success'),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF10B981),
              size: 52,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Instructions Sent!',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We have dispatched email recovery instructions to:\n${_adminEmailController.text.trim()}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: subtitleColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Login', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }

    return Form(
      key: _adminFormKey,
      child: Column(
        key: const ValueKey('admin_form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Admin Notice Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: primaryColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'For Company Admin personal accounts using email authentication. Reset links are sent directly to your email inbox.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(fontFamily: 'Inter', color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            'Registered Admin Email *',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: titleColor),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: titleColor),
            decoration: _buildInputDecoration(
              hintText: 'e.g. admin@company.com',
              prefixIcon: Icons.email_outlined,
              inputBg: inputBg,
              borderCol: borderCol,
              primaryColor: primaryColor,
            ),
            validator: (v) => AppValidators.validatePersonalEmail(v, isRequired: true),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: state.isLoading ? null : _handleAdminEmailReset,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: state.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Send Recovery Email',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    required Color inputBg,
    required Color borderCol,
    required Color primaryColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
    );
  }
}
