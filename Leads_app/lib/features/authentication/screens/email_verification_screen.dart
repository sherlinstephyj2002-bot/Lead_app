import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/providers.dart';
import '../../../constants/feature_flags.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _timer;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendVerificationSilent();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _sendVerificationSilent() async {
    try {
      final user = ref.read(authProvider).user;
      if (user != null && user.email.isNotEmpty) {
        await ref.read(authProvider.notifier).sendEmailVerification();
      }
    } catch (_) {
      // Fail silently for auto-trigger
    }
  }

  Future<void> _handleResend() async {
    if (_cooldownSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _message = null;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).sendEmailVerification();
      if (mounted) {
        setState(() {
          _message = 'Verification link sent to your email! Please check your inbox.';
          _error = null;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to send verification email. Please try again later.';
          _message = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _handleCheckStatus() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _message = null;
      _error = null;
    });

    try {
      final isVerified = await ref.read(authProvider.notifier).checkEmailVerificationStatus();
      if (mounted) {
        if (isVerified) {
          context.go('/main');
        } else {
          setState(() {
            _error = 'Your email has not been verified yet. Please check your inbox and click the verification link.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to check verification status. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _handleDevBypass() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _message = null;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).bypassEmailVerificationDevMode();
      if (mounted) {
        context.go('/main');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to bypass verification: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withBlue(220)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Verify Your Email',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We've sent a verification link to:",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'your email address',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Card Body
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text(
                        'Please check your inbox and click the verification link to continue.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Status Alert Banners
                      if (_message != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _message!,
                                  style: const TextStyle(color: Color(0xFF166534), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_error != null)
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
                                  _error!,
                                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isChecking ? null : _handleCheckStatus,
                          icon: _isChecking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.verified_user_rounded),
                          label: Text(_isChecking ? 'Checking Verification...' : "I've Verified My Email"),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: (_cooldownSeconds > 0 || _isResending) ? null : _handleResend,
                          icon: _isResending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.grey, strokeWidth: 2),
                                )
                              : const Icon(Icons.mark_email_read_rounded),
                          label: Text(
                            _cooldownSeconds > 0
                                ? 'Resend Link in ${_cooldownSeconds}s'
                                : 'Resend Verification Email',
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      if (FeatureFlags.enableDevModeBypass) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isChecking ? null : _handleDevBypass,
                            icon: const Icon(Icons.developer_mode_rounded, color: Color(0xFFD97706)),
                            label: const Text(
                              '⚡ Dev Mode: Bypass Verification & Login',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEF3C7),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),

                      TextButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                        label: const Text(
                          'Log Out / Cancel',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
