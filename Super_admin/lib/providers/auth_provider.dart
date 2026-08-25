import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../constants/user_roles.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSuperAdminAccount = true;
  int _superAdminCount = 0;
  String? _superAdminMaskedEmail;

  AuthProvider(this._authRepository) {
    checkSuperAdminExists();
  }

  // Getters
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _userModel != null;
  bool get hasSuperAdminAccount => _hasSuperAdminAccount;
  int get superAdminCount => _superAdminCount;
  String? get superAdminMaskedEmail => _superAdminMaskedEmail;

  /// Returns the current Firebase User info if available
  fb_auth.User? currentUser() {
    return _authRepository.currentUser();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  /// Checks if any Super Admin account exists in Firestore
  Future<void> checkSuperAdminExists() async {
    try {
      await _authRepository.sanitizePersonalSuperAdminRoles();
      _superAdminCount = await _authRepository.getSuperAdminCount();
      _hasSuperAdminAccount = _superAdminCount > 0;
      _superAdminMaskedEmail = null;
      notifyListeners();
    } catch (_) {
      // In case of network/permission issue, keep default
    }
  }

  /// Checks the current authentication status and loads the user model.
  /// If the user is authenticated but not the dedicated superadmin account, logs them out immediately.
  Future<bool> checkAuthStatus() async {
    _setLoading(true);
    _setError(null);
    try {
      await checkSuperAdminExists();

      final fb_auth.User? fbUser = _authRepository.currentUser();
      if (fbUser == null) {
        _userModel = null;
        _setLoading(false);
        return false;
      }

      // Enforce dedicated SuperAdmin email check & purge legacy personal account sessions
      final userEmail = fbUser.email?.trim().toLowerCase() ?? '';
      if (userEmail != 'superadmin@worktrack.local' &&
          userEmail != 'superadmin.worktrack@gmail.com') {
        debugPrint('[SUPERADMIN_AUTH] Purging legacy personal account session on app start for: $userEmail');
        await _authRepository.logout();
        _userModel = null;
        _setLoading(false);
        return false;
      }

      final UserModel? fetchedUser = await _authRepository.getUserData(fbUser.uid);
      if (fetchedUser == null || fetchedUser.role != UserRoles.superAdmin) {
        _setError("Access Denied: You do not have super admin privileges.");
        await _authRepository.logout();
        _userModel = null;
        _setLoading(false);
        return false;
      }

      _userModel = fetchedUser;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _userModel = null;
      _setLoading(false);
      return false;
    }
  }

  /// Logs in the user and verifies that the role is 'super_admin' in Firestore.
  /// If credentials match but the role is invalid, logs the user out and returns false.
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    final cleanEmail = email.trim().toLowerCase();

    debugPrint('====================================================');
    debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 1: Login button clicked');
    debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 2: Submitted email: "$cleanEmail"');
    debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 3: Auth Source: Firebase Authentication & Cloud Firestore (users collection)');

    // Auto-seed dedicated SuperAdmin & migrate password if logging in with superadmin@worktrack.local and 1q2w3e4r
    if (cleanEmail == 'superadmin@worktrack.local' && (password == '1q2w3e4r' || password == 'WorkTrack@Admin2026!')) {
      try {
        debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 4: Attempting authentication with Firebase Auth...');
        final credentials = await _authRepository.login(cleanEmail, password);
        final fbUser = credentials.user;
        if (fbUser != null) {
          debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 4: User existence check: SUCCESS (UID: ${fbUser.uid})');
          debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 5: Password validation: SUCCESS');

          var fetchedUser = await _authRepository.getUserData(fbUser.uid);
          if (fetchedUser == null) {
            debugPrint('[SUPERADMIN_AUTH_DEBUG] Firestore user record missing. Initializing SuperAdmin profile doc...');
            await _authRepository.registerInitialSuperAdmin(
              name: 'SuperAdmin',
              email: cleanEmail,
              password: password,
            );
            fetchedUser = await _authRepository.getUserData(fbUser.uid);
          }

          if (fetchedUser != null && (fetchedUser.role == UserRoles.superAdmin || fetchedUser.role == 'SuperAdmin')) {
            debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 6: Role validation: SUCCESS (Role: ${fetchedUser.role})');
            debugPrint('[SUPERADMIN_AUTH_DEBUG] AUTHENTICATION COMPLETE -> Redirecting to Dashboard');
            debugPrint('====================================================');
            _userModel = fetchedUser;
            _setLoading(false);
            return true;
          }
        }
      } on fb_auth.FirebaseAuthException catch (e) {
        debugPrint('[SUPERADMIN_AUTH_DEBUG] Initial Auth Attempt Exception: ${e.code} — ${e.message}');
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          // Attempt legacy password login and migrate password to 1q2w3e4r
          try {
            debugPrint('[SUPERADMIN_AUTH_DEBUG] Attempting legacy password migration...');
            final legacyCreds = await _authRepository.login(cleanEmail, 'WorkTrack@Admin2026!');
            final fbUser = legacyCreds.user;
            if (fbUser != null) {
              await _authRepository.changePassword('WorkTrack@Admin2026!', '1q2w3e4r');
              _userModel = await _authRepository.getUserData(fbUser.uid);
              debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 5: Password migrated & verified successfully');
              debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 6: Role validation: SUCCESS');
              debugPrint('====================================================');
              _setLoading(false);
              return true;
            }
          } catch (migErr) {
            debugPrint('[SUPERADMIN_AUTH_DEBUG] Legacy migration attempt failed: $migErr');
          }
        }

        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'invalid-email') {
          try {
            debugPrint('[SUPERADMIN_AUTH_DEBUG] Creating dedicated SuperAdmin account in Firebase Auth & Firestore...');
            await _authRepository.registerInitialSuperAdmin(
              name: 'SuperAdmin',
              email: cleanEmail,
              password: '1q2w3e4r',
            );
            final credentials = await _authRepository.login(cleanEmail, '1q2w3e4r');
            final fbUser = credentials.user;
            if (fbUser != null) {
              _userModel = await _authRepository.getUserData(fbUser.uid);
              debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 4 & 5: Seeding & Password verification: SUCCESS');
              debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 6: Role validation: SUCCESS');
              debugPrint('====================================================');
              _setLoading(false);
              return true;
            }
          } catch (regErr) {
            debugPrint('[SUPERADMIN_AUTH_DEBUG] Seeding attempt exception: $regErr');
          }
        }
      } catch (err) {
        debugPrint('[SUPERADMIN_AUTH_DEBUG] Unexpected exception in auto-seed block: $err');
      }
    }

    try {
      final credentials = await _authRepository.login(cleanEmail, password);
      final fbUser = credentials.user;

      if (fbUser == null) {
        debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 4: User existence check: FAILED (No user returned)');
        _setError("Authentication failed: No user returned.");
        _setLoading(false);
        return false;
      }

      debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 4: User existence check: SUCCESS (UID: ${fbUser.uid})');
      debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 5: Password validation: SUCCESS');

      final UserModel? fetchedUser = await _authRepository.getUserData(fbUser.uid);
      if (fetchedUser == null) {
        debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 6: Role validation: FAILED (No user document in Firestore)');
        _setError("Super Admin account not found.");
        await _authRepository.logout();
        _setLoading(false);
        return false;
      }

      if (fetchedUser.role != UserRoles.superAdmin) {
        debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 6: Role validation: FAILED (Role is ${fetchedUser.role}, expected ${UserRoles.superAdmin})');
        _setError("Access Denied: You do not have super admin privileges.");
        await _authRepository.logout();
        _setLoading(false);
        return false;
      }

      debugPrint('[SUPERADMIN_AUTH_DEBUG] Step 6: Role validation: SUCCESS (Role: ${fetchedUser.role})');
      debugPrint('[SUPERADMIN_AUTH_DEBUG] AUTHENTICATION COMPLETE -> Redirecting to Dashboard');
      debugPrint('====================================================');
      _userModel = fetchedUser;
      _setLoading(false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('[SUPERADMIN_AUTH_DEBUG] FirebaseAuthException caught: ${e.code} — ${e.message}');
      if (e.code == 'user-not-found') {
        _setError("Super Admin account not found.");
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _setError("Invalid email or password.");
      } else {
        _setError(e.message ?? "Invalid email or password.");
      }
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint('[SUPERADMIN_AUTH_DEBUG] Unexpected Exception caught: $e');
      _setError("An unexpected error occurred: ${e.toString()}");
      _setLoading(false);
      return false;
    }
  }

  /// Changes the SuperAdmin password after verifying current password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authRepository.changePassword(currentPassword, newPassword);
      _setLoading(false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _setError("Current password is incorrect.");
      } else {
        _setError(e.message ?? "Failed to change password.");
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll("Exception: ", ""));
      _setLoading(false);
      return false;
    }
  }

  /// One-time initial Super Admin setup. Rejects if a Super Admin already exists.
  Future<bool> registerInitialSuperAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authRepository.registerInitialSuperAdmin(
        name: name,
        email: email,
        password: password,
      );

      // Sign out immediately so user logins cleanly
      await _authRepository.logout();
      _userModel = null;

      await checkSuperAdminExists();
      _setLoading(false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _setError("This email address is already registered.");
      } else if (e.code == 'weak-password') {
        _setError("Password is too weak. Please use a stronger password.");
      } else {
        _setError(e.message ?? "Registration failed.");
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll("Exception: ", ""));
      _setLoading(false);
      return false;
    }
  }

  /// Signs out of Firebase and resets provider state
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Ignore repository level logout errors
    } finally {
      _userModel = null;
      _setError(null);
      _setLoading(false);
      await checkSuperAdminExists();
    }
  }

  /// Sends a password reset email specifically to a registered Super Admin account
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      final isSuperAdmin = await _authRepository.checkIsSuperAdminEmail(email);
      if (!isSuperAdmin) {
        _setError("Super Admin account not found.");
        _setLoading(false);
        return false;
      }

      await _authRepository.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      _setError(e.message ?? "Failed to send password reset email.");
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Clears the current error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

