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
      _superAdminCount = await _authRepository.getSuperAdminCount();
      _hasSuperAdminAccount = _superAdminCount > 0;
      if (_hasSuperAdminAccount) {
        _superAdminMaskedEmail = await _authRepository.getSuperAdminMaskedEmail();
      } else {
        _superAdminMaskedEmail = null;
      }
      notifyListeners();
    } catch (_) {
      // In case of network/permission issue, keep default
    }
  }

  /// Checks the current authentication status and loads the user model.
  /// If the user is authenticated but not a super_admin, logs them out.
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

      final UserModel? fetchedUser = await _authRepository.getUserData(fbUser.uid);
      if (fetchedUser == null) {
        _setError("Super Admin account not found.");
        await _authRepository.logout();
        _userModel = null;
        _setLoading(false);
        return false;
      }

      if (fetchedUser.role != UserRoles.superAdmin) {
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
    try {
      final credentials = await _authRepository.login(email, password);
      final fbUser = credentials.user;

      if (fbUser == null) {
        _setError("Authentication failed: No user returned.");
        _setLoading(false);
        return false;
      }

      final UserModel? fetchedUser = await _authRepository.getUserData(fbUser.uid);
      if (fetchedUser == null) {
        _setError("Super Admin account not found.");
        await _authRepository.logout();
        _setLoading(false);
        return false;
      }

      if (fetchedUser.role != UserRoles.superAdmin) {
        _setError("Access Denied: You do not have super admin privileges.");
        await _authRepository.logout();
        _setLoading(false);
        return false;
      }

      _userModel = fetchedUser;
      _setLoading(false);
      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
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
      _setError("An unexpected error occurred: ${e.toString()}");
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

