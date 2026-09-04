import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/utils/app_validators.dart';
import '../../../shared/utils/app_notification.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _hasCheckedBiometricAuto = false;
  bool _isBiometricButtonVisible = false;
  bool _isBiometricsAllowedForSaved = false;
  String _savedEmployeeId = '';

  @override
  void initState() {
    super.initState();
    _employeeIdController.addListener(_updateBiometricButtonVisibility);
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmpId = prefs.getString('remembered_employee_id') ?? prefs.getString('last_employee_id');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (savedEmpId != null && savedEmpId.isNotEmpty) {
      _savedEmployeeId = savedEmpId;
      if (!kIsWeb) {
        final localAuth = LocalAuthentication();
        final canCheck = await localAuth.canCheckBiometrics;
        final isSupported = canCheck || await localAuth.isDeviceSupported();
        final enrolled = await localAuth.getAvailableBiometrics();

        final secureStorage = const FlutterSecureStorage();
        final bioEnabled = await secureStorage.read(key: 'biometric_enabled_$savedEmpId') == 'true';

        _isBiometricsAllowedForSaved = isSupported && enrolled.isNotEmpty && bioEnabled;
      }
    }

    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (savedEmpId != null) {
          _employeeIdController.text = savedEmpId;
        }
      });
      _updateBiometricButtonVisibility();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndTriggerBiometricAuto();
      });
    }
  }

  void _updateBiometricButtonVisibility() {
    final currentText = _employeeIdController.text.trim();
    final show = _isBiometricsAllowedForSaved && _rememberMe && currentText == _savedEmployeeId && currentText.isNotEmpty;
    if (_isBiometricButtonVisible != show) {
      setState(() {
        _isBiometricButtonVisible = show;
      });
    }
  }

  void _checkAndTriggerBiometricAuto() {
    if (kIsWeb) return;
    final authState = ref.read(authProvider);
    final isLocked = authState.user != null && authState.isBiometricLocked;
    if (isLocked && !_hasCheckedBiometricAuto) {
      _hasCheckedBiometricAuto = true;
      _handleBiometricAuth();
    }
  }

  Future<void> _handleBiometricAuth() async {
    final localAuth = LocalAuthentication();
    try {
      final didAuth = await localAuth.authenticate(
        localizedReason: 'Please authenticate to login to WorkTrack',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (didAuth) {
        ref.read(authProvider.notifier).unlockBiometrics();
        if (mounted) {
          context.go('/main');
        }
      } else {
        _handleUsePasswordInstead();
      }
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      _handleUsePasswordInstead();
    }
  }

  Future<void> _loginWithBiometrics() async {
    final localAuth = LocalAuthentication();
    try {
      final didAuth = await localAuth.authenticate(
        localizedReason: 'Please authenticate to login to WorkTrack',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (didAuth) {
        final savedEmpId = _employeeIdController.text.trim();
        if (savedEmpId.isNotEmpty) {
          final secureStorage = const FlutterSecureStorage();
          final savedPassword = await secureStorage.read(key: 'biometric_password_$savedEmpId');
          if (savedPassword != null && savedPassword.isNotEmpty) {
            _passwordController.text = savedPassword;
            _handleLogin();
          } else {
            if (mounted) {
              AppNotification.showError(context, 'No saved password found for biometrics. Please use manual login.');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
    }
  }

  Future<void> _promptBiometricEnrollment(String employeeId, String password) async {
    if (kIsWeb) return;
    final authNotifier = ref.read(authProvider.notifier);
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final secureStorage = const FlutterSecureStorage();
    final alreadyEnabled = await secureStorage.read(key: 'biometric_enabled_$employeeId') == 'true';
    if (alreadyEnabled) return;

    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    final isSupported = canCheck || await localAuth.isDeviceSupported();
    if (!isSupported) return;

    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint_rounded, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('Enable Biometrics?'),
          ],
        ),
        content: const Text('Would you like to enable fingerprint or face unlock for faster login next time?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Thanks'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (enable == true) {
      await authNotifier.enableBiometrics(employeeId, password, user.uid);
      _savedEmployeeId = employeeId;
      _isBiometricsAllowedForSaved = true;
      _updateBiometricButtonVisibility();
    }
  }

  void _handleUsePasswordInstead() async {
    await ref.read(authProvider.notifier).logout();
    setState(() {
      _hasCheckedBiometricAuto = false;
    });
  }

  void _handleUseAnotherAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remembered_employee_id');
    await prefs.remove('last_employee_id');

    _employeeIdController.clear();
    _passwordController.clear();

    await ref.read(authProvider.notifier).logout();
    setState(() {
      _hasCheckedBiometricAuto = false;
      _isBiometricButtonVisible = false;
      _isBiometricsAllowedForSaved = false;
      _savedEmployeeId = '';
    });
  }

  @override
  void dispose() {
    _employeeIdController.removeListener(_updateBiometricButtonVisibility);
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final employeeId = _employeeIdController.text.trim();
      final password = _passwordController.text;
      final success = await ref.read(authProvider.notifier).login(
        employeeId,
        password,
        rememberMe: _rememberMe,
      );
      if (success && mounted) {
        if (!kIsWeb) {
          await _promptBiometricEnrollment(employeeId, password);
        }
        if (mounted) {
          context.go('/main');
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final firebaseInitError = ref.watch(firebaseInitErrorProvider);
    final isLocked = authState.user != null && authState.isBiometricLocked;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null && next.isBiometricLocked && !_hasCheckedBiometricAuto && !kIsWeb) {
        _hasCheckedBiometricAuto = true;
        _handleBiometricAuth();
      }
    });

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage == 'suspended') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Company Suspended', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "Your company's WorkTrack account has been suspended.\n\nPlease contact your administrator.",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).clearError();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (next.errorMessage == 'deleted') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Company Deleted', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'This company account no longer exists.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).clearError();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });

    // Stitch Design System Colors
    const backgroundColor = Color(0xFFF8F9FD);
    const surfaceColor = Color(0xFFFFFFFF);
    const surfaceLowColor = Color(0xFFEDEEF2);
    const outlineColor = Color(0xFF777587);
    const outlineVariantColor = Color(0xFFC8C4D8);
    const primaryColor = Color(0xFF5B4CF0);
    const primaryContainerColor = Color(0xFF5B4CF0);
    const secondaryColor = Color(0xFF555F6F);
    const secondaryContainerColor = Color(0xFFD6E0F3);
    const onSurfaceColor = Color(0xFF191C1F);
    const onSurfaceVariantColor = Color(0xFF474555);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. Background dot grid pattern
          Positioned.fill(
            child: CustomPaint(
              painter: DotGridPainter(
                dotColor: const Color(0xFFE5E7EB),
                dotRadius: 1.2,
                spacing: 40.0,
              ),
            ),
          ),
          // 2. Soft background gradient blurs
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.15,
            right: -MediaQuery.of(context).size.width * 0.15,
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC4C0FF).withOpacity(0.2),
                    const Color(0xFFC4C0FF).withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -MediaQuery.of(context).size.height * 0.15,
            left: -MediaQuery.of(context).size.width * 0.15,
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.6,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6FFBBE).withOpacity(0.2),
                    const Color(0xFF6FFBBE).withOpacity(0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // 3. Scrollable content centered on screen
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Card Container
                      Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: outlineVariantColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF111827).withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28.0,
                          vertical: 36.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo Section
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: primaryContainerColor.withOpacity(0.05),
                                        width: 4,
                                      ),
                                    ),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: primaryContainerColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.track_changes_rounded,
                                          size: 36,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'WorkTrack',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: onSurfaceColor,
                                      letterSpacing: -0.01,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Manage Employees, Leads & Orders',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: onSurfaceVariantColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),

                            if (isLocked) ...[
                              // Welcome Back Biometric Lock View
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Center(
                                    child: Text(
                                      'Welcome Back',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: onSurfaceColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(
                                      authState.user?.employeeId ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: onSurfaceVariantColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  Center(
                                    child: InkWell(
                                      onTap: _handleBiometricAuth,
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.08),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: primaryColor.withOpacity(0.15),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.fingerprint_rounded,
                                          size: 72,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: TextButton(
                                      onPressed: _handleBiometricAuth,
                                      style: TextButton.styleFrom(
                                        foregroundColor: primaryColor,
                                      ),
                                      child: const Text(
                                        'Login with Biometrics',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextButton(
                                    onPressed: _handleUsePasswordInstead,
                                    style: TextButton.styleFrom(
                                      foregroundColor: onSurfaceVariantColor,
                                    ),
                                    child: const Text(
                                      'Use Password Instead',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _handleUseAnotherAccount,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text(
                                      'Use Another Account',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Welcome Header
                              const Text(
                                'Welcome back',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: onSurfaceColor,
                                  letterSpacing: -0.01,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sign in to manage your workspace',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: onSurfaceVariantColor,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Firebase Init Error Banner
                              if (firebaseInitError != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded,
                                              color: Color(0xFFEF4444)),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Firebase Initialization Failed!',
                                              style: TextStyle(
                                                  color: Color(0xFFB91C1C),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$firebaseInitError\n\nNote: Please make sure that you download the google-services.json file from your Firebase console, copy it into your project\'s /android/app directory, and verify your Gradle files configure it correctly.',
                                        style: const TextStyle(
                                            color: Color(0xFF991B1B),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                              // Error Message if any
                              if (authState.errorMessage != null &&
                                  authState.errorMessage != 'suspended' &&
                                  authState.errorMessage != 'deleted')
                                Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: Color(0xFFEF4444)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          authState.errorMessage!,
                                          style: const TextStyle(
                                              color: Color(0xFFB91C1C),
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Email or Mobile Number Field
                              const Text(
                                'Email or Mobile Number',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: onSurfaceVariantColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _employeeIdController,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: onSurfaceColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'admin@company.com or 9876543210',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: outlineColor,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: outlineColor,
                                    size: 20,
                                  ),
                                  fillColor: surfaceLowColor,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: outlineVariantColor, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: outlineVariantColor, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: primaryColor, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.red, width: 1),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.red, width: 2),
                                  ),
                                ),
                                validator: (value) => AppValidators.validateLoginIdentifier(value),
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: onSurfaceVariantColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: onSurfaceColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: outlineColor,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: outlineColor,
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: outlineColor,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() =>
                                        _isPasswordVisible = !_isPasswordVisible),
                                  ),
                                  fillColor: surfaceLowColor,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: outlineVariantColor, width: 1),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: outlineVariantColor, width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: primaryColor, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.red, width: 1),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: Colors.red, width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Remember Me Checkbox & Forgot Password Row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: primaryColor,
                                          checkColor: Colors.white,
                                          side: const BorderSide(
                                              color: outlineVariantColor,
                                              width: 2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() => _rememberMe = value);
                                              SharedPreferences.getInstance()
                                                  .then((prefs) {
                                                prefs.setBool(
                                                    'remember_me', value);
                                                _updateBiometricButtonVisibility();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Remember Me',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: onSurfaceVariantColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/forgot-password'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      colors: [
                                        primaryContainerColor,
                                        primaryColor
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryContainerColor
                                            .withOpacity(0.2),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: authState.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Login',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              // Biometric Option (if visible)
                              if (_isBiometricButtonVisible) ...[
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(
                                          color: outlineVariantColor,
                                          thickness: 1),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(
                                        'or login with biometric',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: outlineColor,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(
                                          color: outlineVariantColor,
                                          thickness: 1),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: _loginWithBiometrics,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: outlineVariantColor, width: 1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      backgroundColor: Colors.transparent,
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.fingerprint_rounded,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Face / Fingerprint ID',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: onSurfaceColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 28),
                              // Register Company Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: onSurfaceVariantColor,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push('/register'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: const Text(
                                      'Register Company',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // System Status Mini Card Capsule Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: secondaryContainerColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: secondaryColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: secondaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'System Operational',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF005236),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAE6F4),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: outlineVariantColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'v2.4.0-pro',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: onSurfaceVariantColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DotGridPainter extends CustomPainter {
  final Color dotColor;
  final double dotRadius;
  final double spacing;

  DotGridPainter({
    this.dotColor = const Color(0xFFE5E7EB),
    this.dotRadius = 1.0,
    this.spacing = 40.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.spacing != spacing;
  }
}
