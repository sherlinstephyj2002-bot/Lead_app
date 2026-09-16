import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/password_validator.dart';
import '../../../shared/services/security_pin_service.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  // Step 1 / Profile Password Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2 Security PIN Controllers
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool _isPinVisible = false;
  bool _isConfirmPinVisible = false;

  // 1: Step 1 (Change Temp Password), 2: Step 2 (Create Security PIN)
  int _currentStep = 1;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _handleStep1Next() {
    if (_step1FormKey.currentState!.validate()) {
      setState(() {
        _currentStep = 2;
      });
    }
  }

  void _handleStep2Submit() async {
    if (_step2FormKey.currentState!.validate()) {
      final newPassword = _newPasswordController.text;
      final pin = _pinController.text.trim();
      final currentUser = ref.read(authProvider).user;

      if (currentUser == null) return;

      final success = await ref
          .read(passwordResetProvider.notifier)
          .completeAccountSetup(
            employeeUser: currentUser,
            newPassword: newPassword,
            securityPin: pin,
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account setup completed successfully! Welcome to WorkTrack.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/main');
      } else {
        final error = ref.read(passwordResetProvider).errorMessage ?? 'Failed to complete account setup';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleProfilePasswordChange() async {
    if (_profileFormKey.currentState!.validate()) {
      final newPassword = _newPasswordController.text;
      final currentPassword = _currentPasswordController.text;

      final success = await ref.read(authProvider.notifier).updatePassword(
            newPassword,
            currentPassword: currentPassword,
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/main');
      } else {
        final error = ref.read(authProvider).errorMessage ?? 'Failed to update password';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final passwordResetState = ref.watch(passwordResetProvider);
    final currentUser = authState.user;

    final isForcedSetup = currentUser != null &&
        (currentUser.mustChangePassword ||
            currentUser.temporaryPasswordRequired == true ||
            currentUser.firstLogin ||
            !currentUser.securityPinConfigured) &&
        !currentUser.passwordChanged;

    final isLoading = authState.isLoading || passwordResetState.isLoading;

    const primaryColor = Color(0xFF5B4CF0);
    const outlineVariantColor = Color(0xFFC8C4D8);
    const surfaceLowColor = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 44,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isForcedSetup ? 'Secure Your Account' : 'Change Password',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isForcedSetup
                                ? 'Please complete mandatory account security setup to continue.'
                                : 'Please choose a strong new password of at least 6 characters.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Progress Indicator for Forced Setup
                    if (isForcedSetup) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: _currentStep >= 1 ? primaryColor : Colors.grey.shade300,
                                      child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Change Password',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: _currentStep == 1 ? FontWeight.bold : FontWeight.w500,
                                        color: _currentStep == 1 ? primaryColor : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 3,
                                  color: _currentStep >= 1 ? primaryColor : Colors.grey.shade300,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: _currentStep == 2 ? primaryColor : Colors.grey.shade300,
                                      child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Create Security PIN',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: _currentStep == 2 ? FontWeight.bold : FontWeight.w500,
                                        color: _currentStep == 2 ? primaryColor : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 3,
                                  color: _currentStep == 2 ? primaryColor : Colors.grey.shade300,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // STEP 1: Forced Change - Change Temporary Password
                    if (isForcedSetup && _currentStep == 1) ...[
                      Form(
                        key: _step1FormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Temporary Password *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: !_isCurrentPasswordVisible,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter temporary password',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your temporary password.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'New Password *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: !_isNewPasswordVisible,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Enter new strong password',
                                prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a new password.';
                                }
                                final validation = PasswordValidator.validate(value);
                                if (!validation.isValid) {
                                  return 'Password must be at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Confirm New Password *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Confirm new password',
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your new password.';
                                }
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _handleStep1Next,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Next: Create Security PIN',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // STEP 2: Forced Change - Create Security PIN
                    if (isForcedSetup && _currentStep == 2) ...[
                      Form(
                        key: _step2FormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Create a secret 6-digit Security PIN. It will be required for self-service account recovery if you ever forget your password.',
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF3730A3), height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'Create 6-Digit Security PIN *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: !_isPinVisible,
                              maxLength: 6,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 4),
                              decoration: InputDecoration(
                                hintText: '••••••',
                                counterText: '',
                                prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPinVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isPinVisible = !_isPinVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                final clean = (value ?? '').trim();
                                if (clean.length != 6) {
                                  return 'Security PIN must be exactly 6 digits.';
                                }
                                if (SecurityPinService.isWeakPin(clean)) {
                                  return 'Please choose a stronger PIN (avoid 123456, 000000, etc.).';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            const Text(
                              'Confirm Security PIN *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPinController,
                              keyboardType: TextInputType.number,
                              obscureText: !_isConfirmPinVisible,
                              maxLength: 6,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 4),
                              decoration: InputDecoration(
                                hintText: '••••••',
                                counterText: '',
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPinVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isConfirmPinVisible = !_isConfirmPinVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                final clean = (value ?? '').trim();
                                if (clean.length != 6) {
                                  return 'Confirm PIN must be exactly 6 digits.';
                                }
                                if (clean != _pinController.text.trim()) {
                                  return 'Security PINs do not match.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: isLoading ? null : () => setState(() => _currentStep = 1),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Back'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _handleStep2Submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                            )
                                          : const Text(
                                              'Complete Account Setup',
                                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Standard Profile Password Change (When not forced setup)
                    if (!isForcedSetup) ...[
                      Form(
                        key: _profileFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Password *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: !_isCurrentPasswordVisible,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter current password',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isCurrentPasswordVisible = !_isCurrentPasswordVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your current password.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            const Text(
                              'New Password *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: !_isNewPasswordVisible,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Enter at least 6 characters',
                                prefixIcon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a new password.';
                                }
                                final validation = PasswordValidator.validate(value);
                                if (!validation.isValid) {
                                  return 'Password must be at least 6 characters.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            const Text(
                              'Confirm New Password *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Re-enter new password',
                                prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                ),
                                filled: true,
                                fillColor: surfaceLowColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariantColor)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your new password.';
                                }
                                if (value != _newPasswordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleProfilePasswordChange,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'Update Password',
                                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
