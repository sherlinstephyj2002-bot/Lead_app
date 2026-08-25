import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'SuperAdmin');
  final _emailController = TextEditingController(text: 'superadmin.worktrack@example.com');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkSuperAdminExists();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.hasSuperAdminAccount) {
      _showErrorSnackBar("Super Admin initial setup is unavailable because a Super Admin account already exists.");
      return;
    }

    final success = await authProvider.registerInitialSuperAdmin(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Super Admin account initialized successfully! Please sign in with your credentials."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    } else {
      if (authProvider.errorMessage != null) {
        _showErrorSnackBar(authProvider.errorMessage!);
        authProvider.clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading;
    final hasExistingAdmin = authProvider.hasSuperAdminAccount;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Pattern
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.scaffoldBackgroundColor,
                  const Color(0xFF131130),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),

          // Glowing Ambient Orbs
          Positioned(
            top: size.height * 0.1,
            right: size.width * 0.15,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Form Container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Logo & Title
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 64,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Initial SuperAdmin Setup',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasExistingAdmin
                          ? 'Setup is disabled because a SuperAdmin account already exists.'
                          : 'Configure the primary platform administrator account.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasExistingAdmin
                            ? theme.colorScheme.error
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Glassmorphism Container Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                          child: hasExistingAdmin
                              ? Column(
                                  children: [
                                    const Icon(
                                      Icons.lock_person_rounded,
                                      size: 56,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'SuperAdmin Exists',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'A SuperAdmin account has already been registered on this system. Public setup is disabled to protect platform security.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                                        },
                                        icon: const Icon(Icons.arrow_back_rounded),
                                        label: const Text('Back to SuperAdmin Login'),
                                      ),
                                    ),
                                  ],
                                )
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Full Name Field
                                      TextFormField(
                                        controller: _nameController,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Full Name',
                                          prefixIcon: Icon(Icons.person_outlined),
                                          hintText: 'e.g. System Administrator',
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your full name';
                                          }
                                          if (value.trim().length < 2) {
                                            return 'Name must be at least 2 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // Email Field
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                          labelText: 'Super Admin Email',
                                          prefixIcon: const Icon(Icons.email_outlined),
                                          hintText: 'superadmin@worktrack.local',
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your email address';
                                          }
                                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,10}$')
                                              .hasMatch(value.trim())) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // Password Field
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(Icons.lock_outlined),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: theme.textTheme.bodyMedium?.color,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // Confirm Password Field
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _handleSetup(),
                                        decoration: InputDecoration(
                                          labelText: 'Confirm Password',
                                          prefixIcon: const Icon(Icons.lock_reset_outlined),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: theme.textTheme.bodyMedium?.color,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword = !_obscureConfirmPassword;
                                              });
                                            },
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please confirm your password';
                                          }
                                          if (value != _passwordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 32),

                                      // Submit Button
                                      SizedBox(
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: isLoading ? null : _handleSetup,
                                          child: isLoading
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : const Text(
                                                  'Initialize Super Admin Account',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // Back to Login Link
                                      Center(
                                        child: TextButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                                          },
                                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                          label: const Text('Return to Login'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
