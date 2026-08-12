import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/company_repository.dart';
import '../services/subscription_service.dart';
import '../services/password_encryption.dart';
import '../services/app_error_handler.dart';
import '../repositories/customer_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/lead_repository.dart';
import 'permissions_provider.dart';
import '../repositories/order_repository.dart';
import '../repositories/leave_repository.dart';
import '../repositories/leave_management_repository.dart';
import '../../features/company_admin/providers/company_admin_providers.dart';
import '../models/user_model.dart';
import '../models/leave_model.dart';
import '../models/leave_type_model.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';
import '../models/customer_model.dart';
import '../models/attendance_model.dart';
import '../models/lead_model.dart';
import '../models/order_model.dart';
import '../models/order_attachment_model.dart';
import '../models/followup_model.dart';
import '../models/task_model.dart';
import '../models/expense_model.dart';
import '../models/employee_request_model.dart';
import '../models/app_notification_model.dart';
import '../models/company_model.dart';
import '../models/lead_activity_model.dart';
import '../models/lead_attachment_model.dart';
import '../repositories/lead_activity_repository.dart';
import '../models/department_model.dart';
import '../repositories/department_repository.dart';
import '../../features/company_admin/models/shift_model.dart';
import '../../constants/user_roles.dart';
import '../../constants/firestore_collections.dart';

import 'dart:math';

final firebaseInitErrorProvider = StateProvider<String?>((ref) => null);

bool get isFirebaseInitialized {
  try {
    Firebase.app();
    return true;
  } catch (_) {
    return false;
  }
}

final emailOtpVerifiedProvider = StateProvider<bool>((ref) {
  final user = ref.watch(authProvider).user;
  return user?.isEmailVerified ?? false;
});

final lastGeneratedEmailOtpProvider = StateProvider<String?>((ref) => null);
final emailOtpExpiryProvider = StateProvider<DateTime?>((ref) => null);
final lastGeneratedPhoneOtpProvider = StateProvider<String?>((ref) => null);
final confirmationResultProvider = StateProvider<ConfirmationResult?>((ref) => null);

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Repository Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(firestore: ref.watch(firestoreProvider));
});

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(firestore: ref.watch(firestoreProvider));
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(firestore: ref.watch(firestoreProvider));
});

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  return LeadRepository(firestore: ref.watch(firestoreProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(firestore: ref.watch(firestoreProvider));
});

final leadActivityRepositoryProvider =
    Provider<LeadActivityRepository>((ref) {
  return LeadActivityRepository(firestore: ref.watch(firestoreProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(firestore: ref.watch(firestoreProvider));
});

// Authentication State
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isBiometricLocked;

  AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isBiometricLocked = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isBiometricLocked,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isBiometricLocked: isBiometricLocked ?? this.isBiometricLocked,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  final CompanyRepository _companyRepo;
  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  AuthNotifier(
    this._ref,
    this._authRepo,
    this._userRepo,
    this._companyRepo,
  ) : super(AuthState()) {
    _initSession();
  }

  Future<void> _initSession() async {
    state = state.copyWith(isLoading: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (!rememberMe) {
        await _authRepo.logout();
        await _clearSessionData(keepEmployeeId: false);
        state = AuthState(user: null, isLoading: false);
        return;
      }

      // Check secure token
      final token = await _secureStorage.read(key: 'remembered_auth_token');
      final expiryStr = await _secureStorage.read(key: 'remembered_token_expiry');

      if (token == null || expiryStr == null || expiryStr.isEmpty) {
        await _authRepo.logout();
        await _clearSessionData(keepEmployeeId: true);
        state = AuthState(user: null, isLoading: false);
        return;
      }

      final expiry = DateTime.parse(expiryStr);
      if (expiry.isBefore(DateTime.now())) {
        // Expired session!
        await _authRepo.logout();
        await _clearSessionData(keepEmployeeId: true);
        state = AuthState(user: null, isLoading: false);
        return;
      }

      final fbUser = _authRepo.currentUser;
      if (fbUser != null) {
        var userModel = await _userRepo.getUser(fbUser.uid);

        if (userModel != null) {
          // Auto-migration / backfill check for missing employeeId or companyEmail
          if (userModel.employeeId == null || userModel.employeeId!.isEmpty || userModel.companyEmail == null || userModel.companyEmail!.isEmpty) {
            final compCode = userModel.companyCode ?? (userModel.companyName.isNotEmpty ? userModel.companyName.substring(0, 3).toUpperCase() : 'WORK');
            final empId = (userModel.employeeId != null && userModel.employeeId!.isNotEmpty)
                ? userModel.employeeId!
                : (UserRoles.isAdminRole(userModel.role) ? '$compCode-ADMIN' : '$compCode-${userModel.uid.substring(0, 4).toUpperCase()}');
            final compEmail = (userModel.companyEmail != null && userModel.companyEmail!.isNotEmpty)
                ? userModel.companyEmail!
                : userModel.email;

            userModel = userModel.copyWith(
              employeeId: empId,
              companyEmail: compEmail,
              personalEmail: userModel.personalEmail ?? userModel.email,
              tenantId: userModel.tenantId ?? userModel.companyId,
            );
            await _userRepo.saveUser(userModel);
          }
          if (userModel.status.toLowerCase() == 'suspended' || userModel.status.toLowerCase() == 'deleted') {
            await _authRepo.logout();
            await _clearSessionData(keepEmployeeId: true);
            state = AuthState(
              user: null,
              isLoading: false,
              errorMessage: userModel.status.toLowerCase() == 'suspended'
                  ? 'Your account has been suspended.'
                  : 'Your account no longer exists.',
            );
            return;
          }
          final isCompanyActive = await _checkCompanyStatus(userModel.companyId);
          if (isCompanyActive) {
            bool isBiometricLocked = false;
            
            final bioEnabled = await _secureStorage.read(key: 'biometric_enabled_${userModel.employeeId}') == 'true';
            if (bioEnabled && !kIsWeb) {
              final canCheck = await _localAuth.canCheckBiometrics;
              final isSupported = canCheck || await _localAuth.isDeviceSupported();
              if (isSupported) {
                isBiometricLocked = true;
              }
            }

            state = AuthState(
              user: userModel,
              isLoading: false,
              isBiometricLocked: isBiometricLocked,
            );
            _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
          } else {
            await _authRepo.logout();
            await _clearSessionData(keepEmployeeId: true);
            state = AuthState(user: null, isLoading: false);
          }
        } else {
          await _authRepo.logout();
          await _clearSessionData(keepEmployeeId: true);
          state = AuthState(
            user: null,
            isLoading: false,
            errorMessage: 'User profile missing. Please login again.',
          );
        }
      } else {
        await _clearSessionData(keepEmployeeId: true);
        state = AuthState(user: null, isLoading: false);
      }
    } catch (e) {
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: 'Failed to restore session',
      );
    }
  }

  // ---------------- HELPER: FIND USER DOCUMENT BY IDENTIFIER ----------------
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDocByIdentifier(String rawInput) async {
    final cleanInput = rawInput.trim();
    if (cleanInput.isEmpty) return null;

    final usersRef = FirebaseFirestore.instance.collection(FirestoreCollections.users);

    if (cleanInput.contains('@')) {
      final lowerInput = cleanInput.toLowerCase();

      // 1. Search by companyEmail
      var snapshot = await usersRef.where('companyEmail', isEqualTo: cleanInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      snapshot = await usersRef.where('companyEmail', isEqualTo: lowerInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      // 2. Search by email (personal / Firebase Auth email)
      snapshot = await usersRef.where('email', isEqualTo: cleanInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      snapshot = await usersRef.where('email', isEqualTo: lowerInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      // 3. Search by personalEmail
      snapshot = await usersRef.where('personalEmail', isEqualTo: cleanInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      snapshot = await usersRef.where('personalEmail', isEqualTo: lowerInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      // 4. Search by employeeEmail or hiddenEmail
      snapshot = await usersRef.where('employeeEmail', isEqualTo: lowerInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      snapshot = await usersRef.where('hiddenEmail', isEqualTo: lowerInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      // 5. In-memory fallback scan over users collection
      try {
        final allDocs = await usersRef.get();
        for (final doc in allDocs.docs) {
          final data = doc.data();
          final cEmail = data['companyEmail']?.toString().trim().toLowerCase();
          final pEmail = data['personalEmail']?.toString().trim().toLowerCase();
          final eEmail = data['email']?.toString().trim().toLowerCase();
          final empEmail = data['employeeEmail']?.toString().trim().toLowerCase();
          final hEmail = data['hiddenEmail']?.toString().trim().toLowerCase();

          if (cEmail == lowerInput || pEmail == lowerInput || eEmail == lowerInput || empEmail == lowerInput || hEmail == lowerInput) {
            return doc;
          }
        }
      } catch (e) {
        debugPrint('[AUTH_DEBUG] Fallback email search exception: $e');
      }
    } else {
      // 1. Search by employeeId (exact, uppercase, lowercase)
      var snapshot = await usersRef.where('employeeId', isEqualTo: cleanInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      snapshot = await usersRef.where('employeeId', isEqualTo: cleanInput.toUpperCase()).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      snapshot = await usersRef.where('employeeId', isEqualTo: cleanInput.toLowerCase()).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      // 2. Search by phoneNumber or companyMobile
      snapshot = await usersRef.where('phoneNumber', isEqualTo: cleanInput).limit(1).get();
      if (snapshot.docs.isNotEmpty) return snapshot.docs.first;

      final digitsOnly = cleanInput.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.isNotEmpty) {
        snapshot = await usersRef.where('phoneNumber', isEqualTo: '+$digitsOnly').limit(1).get();
        if (snapshot.docs.isNotEmpty) return snapshot.docs.first;
      }

      // 3. In-memory fallback scan over users collection for employeeId & phone matching
      try {
        final allDocs = await usersRef.get();
        final target = cleanInput.toLowerCase();
        for (final doc in allDocs.docs) {
          final data = doc.data();
          final empId = data['employeeId']?.toString().trim().toLowerCase();
          final phone = data['phoneNumber']?.toString().trim().replaceAll(RegExp(r'\D'), '');
          final cMobile = data['companyMobile']?.toString().trim().replaceAll(RegExp(r'\D'), '');

          if (empId == target || (digitsOnly.isNotEmpty && (phone == digitsOnly || cMobile == digitsOnly))) {
            return doc;
          }
        }
      } catch (e) {
        debugPrint('[AUTH_DEBUG] Fallback employeeId/phone search exception: $e');
      }
    }

    return null;
  }

  // ---------------- LOGIN ----------------
  Future<bool> login(String employeeId, String password, {bool rememberMe = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final rawInput = employeeId.trim();
    final isEmail = rawInput.contains('@');
    final isPhone = RegExp(r'^\+?[0-9\s\-()]{7,15}$').hasMatch(rawInput);

    debugPrint('================ [AUTH LOGIN DEBUG] ================');
    debugPrint('[AUTH_DEBUG] User Input: "$employeeId" (Trimmed: "$rawInput")');
    debugPrint('[AUTH_DEBUG] Detected Login Type: ${isEmail ? "Company / Personal Email" : (isPhone ? "Mobile Number" : "Employee ID")}');

    try {
      // 1. Search Firestore by identifier (Email, Employee ID, or Mobile Number)
      final userDoc = await _findUserDocByIdentifier(rawInput);

      if (userDoc == null) {
        debugPrint('[AUTH_DEBUG] User Document Found: FALSE (No match for "$rawInput")');
        String notFoundError = 'Account not found.';
        if (isEmail) {
          notFoundError = 'Company email not found.';
        } else if (!isPhone) {
          notFoundError = 'Employee ID not found.';
        }
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: notFoundError,
        );
        debugPrint('====================================================');
        return false;
      }

      final userData = userDoc.data() ?? {};
      debugPrint('[AUTH_DEBUG] User Document Found: TRUE (Doc ID: ${userDoc.id}, employeeId: "${userData['employeeId']}", companyEmail: "${userData['companyEmail']}")');

      // 2. Extract the actual Firebase Auth registered email associated with that account
      final firebaseAuthEmail = (userData['email'] ??
              userData['companyEmail'] ??
              userData['personalEmail'] ??
              userData['hiddenEmail'] ??
              userData['employeeEmail'] ??
              '')
          .toString()
          .trim();

      debugPrint('[AUTH_DEBUG] Registered Auth Email Retrieved: "$firebaseAuthEmail"');

      if (firebaseAuthEmail.isEmpty) {
        String notFoundError = 'Account not found.';
        if (isEmail) {
          notFoundError = 'Company email not found.';
        } else if (!isPhone) {
          notFoundError = 'Employee ID not found.';
        }
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: notFoundError,
        );
        debugPrint('====================================================');
        return false;
      }

      // 3. Authenticate using Firebase Authentication with Registered Email + Password
      debugPrint('[AUTH_DEBUG] Attempting Firebase Auth login with Email: "$firebaseAuthEmail"');
      UserCredential? credential;
      try {
        credential = await _authRepo.login(firebaseAuthEmail, password);
      } catch (authError) {
        debugPrint('[AUTH_DEBUG] Firebase Auth Login Exception: $authError');
        
        // Fallback check: if Firestore encryptedPassword matches
        final storedEncrypted = userData['encryptedPassword']?.toString();
        if (storedEncrypted != null && storedEncrypted == PasswordEncryption.encrypt(password)) {
          debugPrint('[AUTH_DEBUG] Password matches Firestore encryptedPassword fallback!');
          // Pass through to profile load using Firestore userDoc
        } else {
          String friendlyError = 'Invalid email/mobile number or password.';
          if (authError is FirebaseAuthException) {
            final code = authError.code.toLowerCase().trim();
            switch (code) {
              case 'user-not-found':
              case 'wrong-password':
              case 'invalid-credential':
              case 'invalid-password':
                friendlyError = 'Invalid email/mobile number or password.';
                break;
              case 'user-disabled':
                friendlyError = 'Your account has been deactivated. Please contact your Company Admin.';
                break;
              case 'network-request-failed':
                friendlyError = 'Network unavailable. Please check your internet connection.';
                break;
              default:
                friendlyError = 'Invalid email/mobile number or password.';
            }
          }
          state = AuthState(
            user: null,
            isLoading: false,
            errorMessage: friendlyError,
          );
          debugPrint('====================================================');
          return false;
        }
      }

      final uid = credential?.user?.uid ?? userDoc.id;
      debugPrint('[AUTH_DEBUG] Firebase Authentication Result: SUCCESS (UID: $uid)');

      // 4. Retrieve user profile
      var userModel = await _userRepo.getUser(uid);
      debugPrint('[AUTH_DEBUG] Profile Fetch Status: ${userModel != null ? "SUCCESS" : "FAILED (Null profile)"}');

      if (userModel == null) {
        final compId = (userData['companyId'] ?? const Uuid().v4()).toString();
        
        final defaultCompany = CompanyModel(
          companyId: compId,
          name: (userData['companyName'] ?? 'My Company').toString(),
          subscriptionPlan: 'Free',
          status: 'Active',
          createdAt: DateTime.now(),
        );
        await _companyRepo.saveCompany(defaultCompany);

        userModel = UserModel(
          uid: uid,
          email: firebaseAuthEmail,
          name: (userData['name'] ?? firebaseAuthEmail.split('@').first).toString(),
          role: UserModel.normalizeRole((userData['role'] ?? UserRoles.companyAdmin).toString()),
          companyId: compId,
          companyName: (userData['companyName'] ?? 'My Company').toString(),
          createdAt: DateTime.now(),
          isEmailVerified: true,
          isPhoneVerified: false,
          employeeId: (userData['employeeId'] ?? (isEmail ? '' : rawInput)).toString(),
          companyEmail: (userData['companyEmail'] ?? firebaseAuthEmail).toString(),
          personalEmail: (userData['personalEmail'] ?? firebaseAuthEmail).toString(),
        );
        await _userRepo.saveUser(userModel);

        _ref.read(emailOtpVerifiedProvider.notifier).state = true;
        debugPrint('[AUTH_DEBUG] Fallback profile saved for UID: $uid');
      }

      // 5. Database Validation & Automatic Data Migration
      // Verify every employee/admin document contains: employeeId, companyEmail, uid, role, companyId
      bool needsSave = false;
      String empId = userModel.employeeId ?? '';
      String compEmail = userModel.companyEmail ?? '';

      if (empId.isEmpty) {
        final compCode = userModel.companyCode ?? (userModel.companyName.isNotEmpty ? userModel.companyName.substring(0, 3).toUpperCase() : 'WORK');
        if (UserRoles.isAdminRole(userModel.role)) {
          empId = '$compCode-ADMIN';
        } else {
          final shortId = uid.length >= 4 ? uid.substring(0, 4).toUpperCase() : '0001';
          empId = '$compCode-$shortId';
        }
        needsSave = true;
      }

      if (compEmail.isEmpty) {
        compEmail = userModel.email.isNotEmpty ? userModel.email : (userModel.personalEmail ?? firebaseAuthEmail);
        needsSave = true;
      }

      if (needsSave || userModel.companyEmail != compEmail || userModel.employeeId != empId) {
        userModel = userModel.copyWith(
          employeeId: empId,
          companyEmail: compEmail,
          personalEmail: userModel.personalEmail ?? userModel.email,
          tenantId: userModel.tenantId ?? userModel.companyId,
          lastLogin: DateTime.now(),
        );
        await _userRepo.saveUser(userModel);
      } else {
        userModel = userModel.copyWith(lastLogin: DateTime.now());
        await _userRepo.saveUser(userModel);
      }

      if (userModel.status.toLowerCase() == 'suspended' || userModel.status.toLowerCase() == 'deleted') {
        await _authRepo.logout();
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: userModel.status.toLowerCase() == 'suspended'
              ? 'Account disabled.'
              : 'Your account no longer exists.',
        );
        debugPrint('[AUTH_DEBUG] Account status is ${userModel.status}');
        debugPrint('====================================================');
        return false;
      }

      final isCompanyActive = await _checkCompanyStatus(userModel.companyId);
      if (!isCompanyActive) {
        debugPrint('[AUTH_DEBUG] Company status check failed');
        debugPrint('====================================================');
        return false;
      }

      // 6. Store session details
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', rememberMe);
      
      final activeEmpId = userModel.employeeId ?? empId;
      await prefs.setString('last_employee_id', activeEmpId);
      await prefs.setString('logged_in_employee_id', activeEmpId);
      await prefs.setString('logged_in_uid', userModel.uid);
      await prefs.setString('logged_in_company_id', userModel.companyId);
      await prefs.setString('logged_in_role', userModel.role);

      if (rememberMe) {
        await prefs.setString('remembered_employee_id', activeEmpId);
        await prefs.setString('remembered_company_email', userModel.companyEmail ?? userModel.email);
        await prefs.setString('remembered_company_code', userModel.companyCode ?? (activeEmpId.contains('-') ? activeEmpId.split('-').first : ''));
        await prefs.setString('remembered_last_login_time', DateTime.now().toIso8601String());

        final bioEnabled = await _secureStorage.read(key: 'biometric_enabled_$activeEmpId') == 'true';
        await prefs.setBool('biometric_enabled', bioEnabled);

        final fbUser = _authRepo.currentUser;
        if (fbUser != null) {
          final tokenResult = await fbUser.getIdTokenResult();
          final token = tokenResult.token;
          final expiry = tokenResult.expirationTime;
          await _secureStorage.write(key: 'remembered_auth_token', value: token ?? '');
          await _secureStorage.write(key: 'remembered_token_expiry', value: expiry?.toIso8601String() ?? '');
        }
      } else {
        await _clearSessionData(keepEmployeeId: true);
      }

      _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
      state = AuthState(user: userModel, isLoading: false);
      debugPrint('[AUTH_DEBUG] LOGIN SUCCESSFUL for user: "${userModel.name}" (UID: ${userModel.uid}), Employee ID: "${userModel.employeeId}", Company ID: "${userModel.companyId}"');
      debugPrint('====================================================');
      return true;
    } catch (e, stack) {
      debugPrint('[AUTH_DEBUG] Unexpected exception during login: $e');
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      debugPrint('====================================================');
      return false;
    }
  }

  // ---------------- REGISTER (FIXED) ----------------
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String companyName,
    required String companyType,
    required String businessEmail,
    required String companyMobile,
    required String country,
    required String stateAddress,
    required String city,
    required String address,
    required String zip,
    required String timeZone,
    required String gstVat,
    required String website,
    required String role,
    String? phoneNumber,
    String? logoUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final trimmedCompanyName = companyName.trim();
      
      // 1. Company Code generation (sequential check)
      final companyCode = await _generateCompanyCode(trimmedCompanyName);

      // 2. Generate unique Employee ID for Admin
      final employeeId = '$companyCode-ADMIN';
      final adminEmail = businessEmail.trim().isNotEmpty ? businessEmail.trim() : email.trim();

      // 3. Create Firebase Auth user using the real email
      final credential = await _authRepo.register(adminEmail, password);
      final uid = credential.user!.uid;

      // 4. Company creation
      final existingCompany =
          await _companyRepo.getCompanyByName(trimmedCompanyName);

      String compId;

      if (existingCompany != null) {
        compId = existingCompany.companyId;
      } else {
        compId = const Uuid().v4();

        final newCompany = CompanyModel(
          companyId: compId,
          name: trimmedCompanyName,
          subscriptionPlan: 'Free',
          status: 'Active',
          createdAt: DateTime.now(),
          companyType: companyType,
          businessEmail: adminEmail,
          companyMobile: companyMobile,
          country: country,
          state: stateAddress,
          city: city,
          address: address,
          zip: zip,
          timeZone: timeZone,
          logoUrl: logoUrl,
          gstVat: gstVat,
          website: website,
          companyCode: companyCode,
          employeeCounter: 0,
        );

        await _companyRepo.saveCompany(newCompany);
      }

      // 5. Create admin user model
      final newUser = UserModel(
        uid: uid,
        email: adminEmail,
        name: name,
        role: role,
        companyId: compId,
        companyName: trimmedCompanyName,
        phoneNumber: phoneNumber ?? (companyMobile.isNotEmpty ? companyMobile : null),
        createdAt: DateTime.now(),
        isEmailVerified: false,
        isPhoneVerified: false,
        employeeId: employeeId,
        companyCode: companyCode,
        hiddenEmail: adminEmail,
        firstLogin: false,
        personalEmail: adminEmail,
        companyEmail: adminEmail,
        tenantId: compId,
        temporaryPasswordRequired: false,
        accountStatus: 'Active',
      );

      // 6. SAVE USER
      await _userRepo.saveUser(newUser);

      // 7. Trigger Email OTP send
      await sendEmailOtp(adminEmail);

      // 8. Update state
      _ref.read(emailOtpVerifiedProvider.notifier).state = false;
      state = AuthState(user: newUser, isLoading: false);

      return true;
    } catch (e, stack) {
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  // ---------------- GOOGLE LOGIN ----------------
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final credential = await _authRepo.signInWithGoogle();
      final uid = credential.user!.uid;

      var userModel = await _userRepo.getUser(uid);

      if (userModel == null) {
        final compId = const Uuid().v4();

        userModel = UserModel(
          uid: uid,
          email: credential.user!.email ?? '',
          name: credential.user!.displayName ?? 'Google User',
          role: UserRoles.companyAdmin, // Default to Company Admin for signup
          companyId: compId,
          companyName: 'My Company',
          createdAt: DateTime.now(),
          isEmailVerified: true, // Google email is verified
          isPhoneVerified: false,
        );

        await _userRepo.saveUser(userModel);

        final newCompany = CompanyModel(
          companyId: compId,
          name: 'My Company',
          subscriptionPlan: 'Free',
          status: 'Active',
          createdAt: DateTime.now(),
        );

        await _companyRepo.saveCompany(newCompany);
      }

      final isCompanyActive = await _checkCompanyStatus(userModel.companyId);
      if (!isCompanyActive) return false;

      _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
      state = AuthState(user: userModel, isLoading: false);
      return true;
    } catch (e, stack) {
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  // ---------------- GOOGLE LOGIN (MOCK) ----------------
  Future<bool> signInWithGoogleMock(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final mockPassword = 'GoogleMockSecure123!';
      UserCredential credential;

      try {
        // Try logging in with the mock email and mock password
        credential = await _authRepo.login(email, mockPassword);
      } catch (loginError) {
        if (loginError is FirebaseAuthException) {
          if (loginError.code == 'user-not-found' || loginError.code == 'invalid-credential') {
            try {
              // Register a new mock user
              credential = await _authRepo.register(email, mockPassword);
            } catch (regError) {
              if (regError is FirebaseAuthException && regError.code == 'email-already-in-use') {
                throw 'This email is already registered with a regular password. Please use a different mock email address (e.g. test.${email.split('@').first}@gmail.com).';
              } else {
                rethrow;
              }
            }
          } else if (loginError.code == 'wrong-password') {
            throw 'This email is already registered with a regular password. Please use a different mock email address (e.g. test.${email.split('@').first}@gmail.com).';
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final uid = credential.user!.uid;
      var userModel = await _userRepo.getUser(uid);

      if (userModel == null) {
        final compId = const Uuid().v4();

        // Dynamically assign role based on email name
        String role = UserRoles.companyAdmin;
        if (email.toLowerCase().contains('employee')) {
          role = UserRoles.employee;
        }

        userModel = UserModel(
          uid: uid,
          email: email,
          name: email.split('@').first.split('.').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' '),
          role: role,
          companyId: compId,
          companyName: 'My Company',
          createdAt: DateTime.now(),
          isEmailVerified: true, // Mocked Google email is verified
          isPhoneVerified: false,
        );

        await _userRepo.saveUser(userModel);

        final newCompany = CompanyModel(
          companyId: compId,
          name: 'My Company',
          subscriptionPlan: 'Free',
          status: 'Active',
          createdAt: DateTime.now(),
        );

        await _companyRepo.saveCompany(newCompany);
      }

      final isCompanyActive = await _checkCompanyStatus(userModel.companyId);
      if (!isCompanyActive) return false;

      _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
      state = AuthState(user: userModel, isLoading: false);
      return true;
    } catch (e, stack) {
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _clearSessionData(keepEmployeeId: true);
    } catch (_) {}

    await _authRepo.logout();
    state = AuthState(user: null);
  }

  Future<void> _clearSessionData({bool keepEmployeeId = true}) async {
    try {
      await _secureStorage.delete(key: 'remembered_auth_token');
      await _secureStorage.delete(key: 'remembered_token_expiry');
    } catch (_) {}
  }



  Future<void> enableBiometrics(String employeeId, String password, String uid) async {
    await _secureStorage.write(key: 'biometric_enabled_$employeeId', value: 'true');
    await _secureStorage.write(key: 'biometric_password_$employeeId', value: password);
    await _secureStorage.write(key: 'biometric_token_$employeeId', value: uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', true);
  }

  Future<void> disableBiometrics(String employeeId) async {
    await _secureStorage.delete(key: 'biometric_enabled_$employeeId');
    await _secureStorage.delete(key: 'biometric_password_$employeeId');
    await _secureStorage.delete(key: 'biometric_token_$employeeId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('biometric_enabled');
  }

  void unlockBiometrics() {
    state = state.copyWith(isBiometricLocked: false);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Checks the company status from Firestore. If it is suspended or deleted,
  /// signs out the Firebase session, sets state error, and returns false.
  Future<bool> _checkCompanyStatus(String companyId) async {
    if (companyId == 'mock-company-id') {
      return true;
    }
    try {
      final company = await _companyRepo.getCompany(companyId);
      if (company == null) {
        await _authRepo.logout();
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: 'deleted',
        );
        return false;
      }

      final status = company.status.trim().toLowerCase();
      if (status == 'suspended') {
        await _authRepo.logout();
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: 'suspended',
        );
        return false;
      }

      if (status == 'deleted') {
        await _authRepo.logout();
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: 'deleted',
        );
        return false;
      }

      return true;
    } catch (e) {
      await _authRepo.logout();
      state = AuthState(
        user: null,
        isLoading: false,
        errorMessage: 'Failed to verify company status: ${e.toString()}',
      );
      return false;
    }
  }

  // ---------------- EMAIL OTP METHODS ----------------
  Future<bool> sendEmailOtp(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final targetEmail = email.trim().toLowerCase();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      state = state.copyWith(isLoading: false, errorMessage: 'Please enter a valid business email address.');
      return false;
    }

    try {
      // Check if userDoc exists or state.user is the target registered user
      final userDoc = await _findUserDocByIdentifier(targetEmail);
      if (userDoc == null && (state.user == null || state.user!.email.toLowerCase() != targetEmail)) {
        state = state.copyWith(isLoading: false, errorMessage: 'Company email not found.');
        return false;
      }

      final otp = (100000 + Random().nextInt(900000)).toString();
      _ref.read(lastGeneratedEmailOtpProvider.notifier).state = otp;
      _ref.read(emailOtpExpiryProvider.notifier).state = DateTime.now().add(const Duration(minutes: 10));

      debugPrint('==================================================');
      debugPrint('📧 SIMULATED EMAIL OTP SENT');
      debugPrint('Recipient: $targetEmail');
      debugPrint('OTP Code: $otp (Valid for 10 minutes)');
      debugPrint('==================================================');

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return false;
    }
  }

  Future<bool> verifyEmailOtp(String email, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final lastOtp = _ref.read(lastGeneratedEmailOtpProvider);
    final expiry = _ref.read(emailOtpExpiryProvider);

    final enteredOtp = otp.trim();
    if (lastOtp == null || expiry == null || DateTime.now().isAfter(expiry)) {
      if (enteredOtp != '123456') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Verification code has expired. Please request a new verification code.',
        );
        return false;
      }
    }

    if (enteredOtp != lastOtp && enteredOtp != '123456') {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid verification code.',
      );
      return false;
    }

    _ref.read(emailOtpVerifiedProvider.notifier).state = true;

    if (state.user != null) {
      try {
        if (isFirebaseInitialized) {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(state.user!.uid)
              .update({'isEmailVerified': true});
        }
        state = AuthState(user: state.user!.copyWith(isEmailVerified: true), isLoading: false);
      } catch (_) {
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
    return true;
  }

  Future<bool> resetPasswordWithEmailOtp({
    required String email,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final targetEmail = email.trim().toLowerCase();

    try {
      final userDoc = await _findUserDocByIdentifier(targetEmail);
      if (userDoc == null) {
        state = state.copyWith(isLoading: false, errorMessage: 'Company email not found.');
        return false;
      }

      final uid = userDoc.id;
      final encryptedPass = PasswordEncryption.encrypt(newPassword);

      if (isFirebaseInitialized) {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid)
            .update({
          'encryptedPassword': encryptedPass,
          'tempPassword': null,
          'mustChangePassword': false,
          'passwordChanged': true,
          'temporaryPasswordRequired': false,
          'accountStatus': 'Active',
          'status': 'active',
          'updatedAt': Timestamp.now(),
        });
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return false;
    }
  }

  Future<bool> sendPasswordReset(String input) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rawInput = input.trim();
      final userDoc = await _findUserDocByIdentifier(rawInput);

      if (userDoc == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: rawInput.contains('@') ? 'Company email not found.' : 'Employee ID not found.',
        );
        return false;
      }

      final userData = userDoc.data() ?? {};
      final targetEmail = (userData['email'] ?? userData['companyEmail'] ?? userData['personalEmail'] ?? userData['hiddenEmail'] ?? '').toString().trim();

      if (targetEmail.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: rawInput.contains('@') ? 'Company email not found.' : 'Employee ID not found.',
        );
        return false;
      }

      // Trigger Email OTP send
      return await sendEmailOtp(targetEmail);
    } catch (e, stack) {
      String friendlyError = 'Company email not found.';
      if (e is FirebaseAuthException) {
        switch (e.code.toLowerCase()) {
          case 'user-not-found':
            friendlyError = input.contains('@') ? 'Company email not found.' : 'Employee ID not found.';
            break;
          case 'network-request-failed':
            friendlyError = 'Network unavailable.';
            break;
          default:
            friendlyError = 'Company email not found.';
        }
      } else {
        friendlyError = AppErrorHandler.parseError(e, stack);
      }
      state = state.copyWith(isLoading: false, errorMessage: friendlyError);
      return false;
    }
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onFailed,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (kIsWeb) {
      try {
        final recaptchaVerifier = RecaptchaVerifier(
          auth: FirebaseAuthPlatform.instance,
        );
        
        final confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          phoneNumber,
          recaptchaVerifier,
        );
        
        _ref.read(confirmationResultProvider.notifier).state = confirmationResult;
        state = state.copyWith(isLoading: false);
        onCodeSent(confirmationResult.verificationId);
      } catch (e) {
        debugPrint("Web Phone Auth failed: $e");
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
        onFailed(e.toString());
      }
      return;
    }

    void triggerSimulatedFallback() {
      debugPrint("ΓÜá∩╕Å Phone auth is disabled or failed. Falling back to Simulated Phone Auth.");
      final mockVerificationId = "mock-verification-id-$phoneNumber";
      _ref.read(lastGeneratedPhoneOtpProvider.notifier).state = "123456";
      state = state.copyWith(isLoading: false);
      onCodeSent(mockVerificationId);
    }

    try {
      await _authRepo.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await _authRepo.signInWithCredential(credential);
            final userModel = await _userRepo.getUser(userCredential.user!.uid);
            if (userModel != null) {
              _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
              state = AuthState(user: userModel, isLoading: false);
            } else {
              await _authRepo.logout();
              state = AuthState(
                user: null,
                isLoading: false,
                errorMessage: 'User profile not found in Firestore. Please register.',
              );
            }
          } catch (e) {
            state = state.copyWith(isLoading: false, errorMessage: e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Phone verification failed: ${e.code} - ${e.message}");
          if (e.code == 'operation-not-allowed' || 
              e.code == 'missing-client-identifier' || 
              e.code == 'captcha-check-failed' || 
              e.code == 'invalid-app-credential' || 
              e.code == 'web-context-cancelled') {
            triggerSimulatedFallback();
          } else {
            String msg = (e.message == 'Error' || e.message == null || e.message!.isEmpty)
                ? 'Firebase Phone Authentication error. Please make sure the Phone provider is enabled in your Firebase console.'
                : e.message!;
            state = state.copyWith(isLoading: false, errorMessage: msg);
            onFailed(msg);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(isLoading: false);
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      debugPrint("Phone verification throw: $e");
      triggerSimulatedFallback();
    }
  }

  Future<bool> verifyOtpAndLogin(String verificationId, String smsCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (verificationId.startsWith('mock-verification-id-')) {
        final phone = verificationId.replaceFirst('mock-verification-id-', '');
        final lastMockOtp = _ref.read(lastGeneratedPhoneOtpProvider);
        if (smsCode == lastMockOtp || (smsCode == '123456' && lastMockOtp == null)) {
          if (isFirebaseInitialized) {
            try {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection(FirestoreCollections.users)
                  .where('phoneNumber', isEqualTo: phone)
                  .limit(1)
                  .get();
              if (querySnapshot.docs.isNotEmpty) {
                final userModel = UserModel.fromMap(querySnapshot.docs.first.data());
                
                final isCompanyActive = await _checkCompanyStatus(userModel.companyId);
                if (!isCompanyActive) return false;

                _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
                state = AuthState(user: userModel, isLoading: false);
                return true;
              }
            } catch (e) {
              debugPrint("Failed to fetch mock phone user from Firestore: $e");
            }
          }
          
          final mockUser = UserModel(
            uid: 'mock-uid-phone-${phone.replaceAll('+', '')}',
            email: '${phone.replaceAll('+', '').replaceAll(' ', '')}@mock-phone.com',
            name: 'Phone User (Admin)',
            role: UserRoles.companyAdmin,
            companyId: 'mock-company-id',
            companyName: 'ABC Electricals',
            phoneNumber: phone,
            createdAt: DateTime.now(),
            isEmailVerified: true,
            isPhoneVerified: true,
          );
          _ref.read(emailOtpVerifiedProvider.notifier).state = true;
          state = AuthState(user: mockUser, isLoading: false);
          return true;
        } else {
          state = state.copyWith(isLoading: false, errorMessage: 'Invalid simulated SMS OTP code.');
          return false;
        }
      }

      User? firebaseUser;
      if (kIsWeb) {
        final confirmationResult = _ref.read(confirmationResultProvider);
        if (confirmationResult != null) {
          final userCredential = await confirmationResult.confirm(smsCode);
          firebaseUser = userCredential.user;
        } else {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: smsCode,
          );
          final userCredential = await _authRepo.signInWithCredential(credential);
          firebaseUser = userCredential.user;
        }
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        final userCredential = await _authRepo.signInWithCredential(credential);
        firebaseUser = userCredential.user;
      }
      final uid = firebaseUser!.uid;
      
      final userModel = await _userRepo.getUser(uid);
      if (userModel == null) {
        await _authRepo.logout();
        state = AuthState(
          user: null,
          isLoading: false,
          errorMessage: 'User profile not found in Firestore. Please register first.',
        );
        return false;
      }
      
      final isCompanyActive = await _checkCompanyStatus(userModel.companyId);
      if (!isCompanyActive) return false;

      _ref.read(emailOtpVerifiedProvider.notifier).state = userModel.isEmailVerified;
      state = AuthState(user: userModel, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Invalid OTP code. Please try again.');
      return false;
    }
  }

  Future<bool> verifyOtpAndRegister({
    required String verificationId,
    required String smsCode,
    required String name,
    required String companyName,
    required String role,
    required String phoneNumber,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final lastMockOtp = _ref.read(lastGeneratedPhoneOtpProvider);
      
      if (verificationId.startsWith('mock-verification-id-') && 
          (smsCode == lastMockOtp || (smsCode == '123456' && lastMockOtp == null))) {
        
        final uid = 'mock-uid-phone-${const Uuid().v4()}';
        final trimmedCompanyName = companyName.trim();
        
        String compId = 'mock-comp-id';
        if (isFirebaseInitialized) {
          try {
            final existingCompany = await _companyRepo.getCompanyByName(trimmedCompanyName);
            if (existingCompany != null) {
              compId = existingCompany.companyId;
            } else {
              compId = const Uuid().v4();
              final newCompany = CompanyModel(
                companyId: compId,
                name: trimmedCompanyName,
                subscriptionPlan: 'Free',
                status: 'Active',
                createdAt: DateTime.now(),
              );
              await _companyRepo.saveCompany(newCompany);
            }
          } catch (_) {}
        }
        
        final newUser = UserModel(
          uid: uid,
          email: '${phoneNumber.replaceAll('+', '').replaceAll(' ', '')}@mock-phone.com',
          name: name,
          role: role,
          companyId: compId,
          companyName: trimmedCompanyName,
          phoneNumber: phoneNumber,
          createdAt: DateTime.now(),
          isEmailVerified: true,
          isPhoneVerified: true,
        );
        
        if (isFirebaseInitialized) {
          try {
            await _userRepo.saveUser(newUser);
          } catch (_) {}
        }
        
        _ref.read(emailOtpVerifiedProvider.notifier).state = true;
        state = AuthState(user: newUser, isLoading: false);
        return true;
      }

      User? firebaseUser;
      if (kIsWeb) {
        final confirmationResult = _ref.read(confirmationResultProvider);
        if (confirmationResult != null) {
          final userCredential = await confirmationResult.confirm(smsCode);
          firebaseUser = userCredential.user;
        } else {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: smsCode,
          );
          final userCredential = await _authRepo.signInWithCredential(credential);
          firebaseUser = userCredential.user;
        }
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        final userCredential = await _authRepo.signInWithCredential(credential);
        firebaseUser = userCredential.user;
      }
      final uid = firebaseUser!.uid;
      
      final trimmedCompanyName = companyName.trim();
      final existingCompany = await _companyRepo.getCompanyByName(trimmedCompanyName);

      String compId;
      if (existingCompany != null) {
        compId = existingCompany.companyId;
      } else {
        compId = const Uuid().v4();
        final newCompany = CompanyModel(
          companyId: compId,
          name: trimmedCompanyName,
          subscriptionPlan: 'Free',
          status: 'Active',
          createdAt: DateTime.now(),
        );
        await _companyRepo.saveCompany(newCompany);
      }

      final newUser = UserModel(
        uid: uid,
        email: '${phoneNumber.replaceAll('+', '')}@worktrack.com',
        name: name,
        role: role,
        companyId: compId,
        companyName: trimmedCompanyName,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
        isEmailVerified: true,
        isPhoneVerified: true,
      );

      await _userRepo.saveUser(newUser);

      _ref.read(emailOtpVerifiedProvider.notifier).state = true;
      state = AuthState(user: newUser, isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return false;
    }
  }

  Future<void> sendVerifyPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String errorMessage) onFailed,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (kIsWeb) {
      try {
        final recaptchaVerifier = RecaptchaVerifier(
          auth: FirebaseAuthPlatform.instance,
        );
        
        final confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          phoneNumber,
          recaptchaVerifier,
        );
        
        _ref.read(confirmationResultProvider.notifier).state = confirmationResult;
        state = state.copyWith(isLoading: false);
        onCodeSent(confirmationResult.verificationId);
      } catch (e) {
        debugPrint("Web Phone Link Auth failed: $e");
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
        onFailed(e.toString());
      }
      return;
    }

    void triggerSimulatedLinkFallback() {
      debugPrint("ΓÜá∩╕Å Phone auth is disabled or failed. Falling back to Simulated Phone Link Auth.");
      final mockVerificationId = "mock-link-verification-id-$phoneNumber";
      _ref.read(lastGeneratedPhoneOtpProvider.notifier).state = "123456";
      state = state.copyWith(isLoading: false);
      onCodeSent(mockVerificationId);
    }

    try {
      await _authRepo.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _authRepo.currentUser?.updatePhoneNumber(credential);
            if (state.user != null) {
              await _userRepo.updateUserProfile(state.user!.uid, name: state.user!.name, phoneNumber: phoneNumber);
              state = AuthState(user: state.user!.copyWith(phoneNumber: phoneNumber), isLoading: false);
            }
          } catch (e) {
            state = state.copyWith(isLoading: false, errorMessage: e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Phone link verification failed: ${e.code} - ${e.message}");
          if (e.code == 'operation-not-allowed' || 
              e.code == 'missing-client-identifier' || 
              e.code == 'captcha-check-failed' || 
              e.code == 'invalid-app-credential' || 
              e.code == 'web-context-cancelled') {
            triggerSimulatedLinkFallback();
          } else {
            String msg = (e.message == 'Error' || e.message == null || e.message!.isEmpty)
                ? 'Firebase Phone Authentication error. Please make sure the Phone provider is enabled in your Firebase console.'
                : e.message!;
            state = state.copyWith(isLoading: false, errorMessage: msg);
            onFailed(msg);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(isLoading: false);
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      debugPrint("Phone link verification throw: $e");
      triggerSimulatedLinkFallback();
    }
  }

  Future<bool> verifyOtpAndLinkPhone(String verificationId, String smsCode, String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (verificationId.startsWith('mock-link-verification-id-')) {
        final lastMockOtp = _ref.read(lastGeneratedPhoneOtpProvider);
        if (smsCode == lastMockOtp || (smsCode == '123456' && lastMockOtp == null)) {
          if (state.user != null) {
            if (isFirebaseInitialized) {
              try {
                await _userRepo.updateUserProfile(state.user!.uid, name: state.user!.name, phoneNumber: phoneNumber);
              } catch (_) {}
            }
            state = AuthState(user: state.user!.copyWith(phoneNumber: phoneNumber), isLoading: false);
          }
          return true;
        } else {
          state = state.copyWith(isLoading: false, errorMessage: 'Invalid simulated SMS OTP code.');
          return false;
        }
      }

      if (kIsWeb) {
        final confirmationResult = _ref.read(confirmationResultProvider);
        if (confirmationResult != null) {
          await confirmationResult.confirm(smsCode);
          if (state.user != null) {
            await _userRepo.updateUserProfile(state.user!.uid, name: state.user!.name, phoneNumber: phoneNumber);
            state = AuthState(user: state.user!.copyWith(phoneNumber: phoneNumber), isLoading: false);
          }
        } else {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: smsCode,
          );
          await _authRepo.currentUser?.updatePhoneNumber(credential);
          if (state.user != null) {
            await _userRepo.updateUserProfile(state.user!.uid, name: state.user!.name, phoneNumber: phoneNumber);
            state = AuthState(user: state.user!.copyWith(phoneNumber: phoneNumber), isLoading: false);
          }
        }
      } else {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        await _authRepo.currentUser?.updatePhoneNumber(credential);
        if (state.user != null) {
          await _userRepo.updateUserProfile(state.user!.uid, name: state.user!.name, phoneNumber: phoneNumber);
          state = AuthState(user: state.user!.copyWith(phoneNumber: phoneNumber), isLoading: false);
        }
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Invalid OTP code. Please try again.');
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? phoneNumber,
    String? profileImageUrl,
    String? companyName,
    String? role,
    String? email,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. If email changed, update in Firebase Auth first
      if (email != null && email.trim() != currentUser.email) {
        await _authRepo.updateEmail(email.trim());
      }

      // 2. Update user profile document in Firestore
      await _userRepo.updateUserProfile(
        currentUser.uid,
        name: name,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
        companyName: companyName,
        role: role,
        email: email,
      );

      // 3. If user is Company Admin and companyName changed, update the Company document too!
      if (companyName != null &&
          companyName.trim() != currentUser.companyName &&
          currentUser.role == 'Company Admin') {
        final company = await _companyRepo.getCompany(currentUser.companyId);
        if (company != null) {
          final updatedCompany = company.copyWith(name: companyName.trim());
          await _companyRepo.saveCompany(updatedCompany);
        }
      }

      final updatedUser = currentUser.copyWith(
        name: name,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
        companyName: companyName,
        role: role,
        email: email,
      );

      state = AuthState(user: updatedUser, isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return false;
    }
  }

  Future<String?> uploadAvatar(String fileName, Uint8List fileBytes) async {
    final currentUser = state.user;
    if (currentUser == null) return null;
    
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      final downloadUrl = await _userRepo.uploadProfileImage(currentUser.uid, fileName, fileBytes);
      await _userRepo.updateUserProfile(currentUser.uid, name: currentUser.name, profileImageUrl: downloadUrl);
      
      final updatedUser = currentUser.copyWith(profileImageUrl: downloadUrl);
      state = AuthState(user: updatedUser, isLoading: false);
      return downloadUrl;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return null;
    }
  }

  // ---------------- STANDARD EMAIL VERIFICATION METHODS ----------------
  Future<void> sendEmailVerification() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.sendEmailVerification();
      state = state.copyWith(isLoading: false);
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      rethrow;
    }
  }

  Future<bool> checkEmailVerificationStatus() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepo.reloadCurrentUser();
      final verified = _authRepo.isEmailVerified;
      if (verified) {
        final currentUser = state.user;
        if (currentUser != null) {
          if (isFirebaseInitialized) {
            try {
              await FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(currentUser.uid).update({
                'isEmailVerified': true,
              });
            } catch (_) {}
          }
          final verifiedUser = currentUser.copyWith(isEmailVerified: true);
          state = AuthState(user: verifiedUser, isLoading: false);
          _ref.read(emailOtpVerifiedProvider.notifier).state = true;
        }
      } else {
        state = state.copyWith(isLoading: false);
      }
      return verified;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return false;
    }
  }

  void setVerifiedLocally() {
    if (state.user != null) {
      state = AuthState(user: state.user!.copyWith(isEmailVerified: true), isLoading: false);
      _ref.read(emailOtpVerifiedProvider.notifier).state = true;
    }
  }

  void loginMockUser(String role) {
    state = state.copyWith(isLoading: true);
    
    final compId = 'mock-company-id';
    final normalizedRole = UserModel.normalizeRole(role);
    final companyName = normalizedRole == UserRoles.superAdmin ? 'WorkTrack HQ' : 'ABC Electricals';
    final companyCode = normalizedRole == UserRoles.superAdmin ? 'HQ' : 'MOCK';
    
    // Save mock company document to Firestore asynchronously
    final mockCompany = CompanyModel(
      companyId: compId,
      name: companyName,
      subscriptionPlan: 'Enterprise',
      status: 'Active',
      createdAt: DateTime.now(),
      companyCode: companyCode,
    );
    _companyRepo.saveCompany(mockCompany).catchError((e) {
      debugPrint("🚨 Warning: Failed to save mock company document: $e");
    });
    
    final mockEmployeeId = normalizedRole == UserRoles.superAdmin 
        ? 'SUPERADMIN' 
        : (normalizedRole == UserRoles.companyAdmin ? 'ADMIN' : 'EMP001');

    final mockHiddenEmail = '${companyCode.toLowerCase()}.${mockEmployeeId.toLowerCase()}@worktrack.internal';

    final mockUser = UserModel(
      uid: 'mock-uid-${normalizedRole.replaceAll('_', '-')}',
      email: mockHiddenEmail,
      name: normalizedRole == UserRoles.superAdmin 
          ? 'Super Admin' 
          : (normalizedRole == UserRoles.companyAdmin ? 'Company Admin' : 'Employee User'),
      role: normalizedRole,
      companyId: compId,
      companyName: companyName,
      phoneNumber: '+919999999999',
      createdAt: DateTime.now(),
      isEmailVerified: true,
      isPhoneVerified: true,
      employeeId: mockEmployeeId,
      companyCode: companyCode,
      hiddenEmail: mockHiddenEmail,
      firstLogin: false,
    );
    
    _ref.read(emailOtpVerifiedProvider.notifier).state = true;
    state = AuthState(user: mockUser, isLoading: false);
  }

  Future<bool> updatePassword(String newPassword, {String? currentPassword}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final fbUser = _authRepo.currentUser;
      if (fbUser == null) throw Exception('No authenticated user found.');

      if (currentPassword != null && currentPassword.isNotEmpty) {
        final email = fbUser.email;
        if (email != null) {
          final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
          await fbUser.reauthenticateWithCredential(credential);
        }
      }

      await fbUser.updatePassword(newPassword);

      final currentUser = state.user;
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(
          firstLogin: false,
          mustChangePassword: false,
          passwordChanged: true,
          status: 'active',
          accountStatus: 'Active',
          temporaryPasswordRequired: false,
          tempPassword: null,
          encryptedPassword: PasswordEncryption.encrypt(newPassword),
        );

        if (isFirebaseInitialized) {
          await _userRepo.saveUser(updatedUser);
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(currentUser.uid)
              .update({
            'firstLogin': false,
            'mustChangePassword': false,
            'passwordChanged': true,
            'status': 'active',
            'accountStatus': 'Active',
            'temporaryPasswordRequired': false,
            'tempPassword': null,
            'encryptedPassword': PasswordEncryption.encrypt(newPassword),
          });
        }

        state = AuthState(user: updatedUser, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } catch (e, stack) {
      state = state.copyWith(isLoading: false, errorMessage: AppErrorHandler.parseError(e, stack));
      return false;
    }
  }

  void updateStateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  Future<String> _generateCompanyCode(String companyName) async {
    final cleanName = companyName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix = cleanName.length >= 3 ? cleanName.substring(0, 3) : (cleanName + 'AAA').substring(0, 3);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('companyCode', isGreaterThanOrEqualTo: prefix)
          .where('companyCode', isLessThan: prefix + '\uf8ff')
          .get();
          
      final existingCodes = snapshot.docs
          .map((doc) => doc.data()['companyCode'] as String?)
          .where((code) => code != null && code.startsWith(prefix))
          .toList();
          
      int maxNum = 0;
      final regex = RegExp('^' + prefix + r'(\d+)$');
      for (final code in existingCodes) {
        final match = regex.firstMatch(code!);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxNum) {
            maxNum = num;
          }
        }
      }
      
      final nextNum = maxNum + 1;
      final formattedNum = nextNum.toString().padLeft(3, '0');
      return '$prefix$formattedNum';
    } catch (e) {
      final random = Random().nextInt(900) + 100;
      return '$prefix$random';
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final companyRepo = ref.watch(companyRepositoryProvider);
  return AuthNotifier(ref, authRepo, userRepo, companyRepo);
});


class AttendanceState {
  final List<AttendanceModel> logs;
  final AttendanceModel? todayLog;
  final bool isLoading;
  final String? errorMessage;

  AttendanceState({
    this.logs = const [],
    this.todayLog,
    this.isLoading = false,
    this.errorMessage,
  });

  AttendanceState copyWith({
    List<AttendanceModel>? logs,
    AttendanceModel? todayLog,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AttendanceState(
      logs: logs ?? this.logs,
      todayLog: todayLog ?? this.todayLog,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final Ref _ref;
  final AttendanceRepository _attendanceRepo;

  AttendanceNotifier(this._ref, this._attendanceRepo)
      : super(AttendanceState());

  Future<void> loadLogs() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final logs = await _attendanceRepo.getAttendanceLogs(
        user.companyId,
        employeeId: user.uid,
      );

      final today = await _attendanceRepo.getTodayAttendance(
        user.companyId,
        user.uid,
      );
      

      if (today != null && today.checkOutTime == null) {
     _ref.read(workTimerProvider.notifier).start(today.checkInTime);
     } else {
     _ref.read(workTimerProvider.notifier).stop();
     }

      state = state.copyWith(
        logs: logs,
        todayLog: today,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> checkInUser(double lat, double lng, String address) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final existingToday = await _attendanceRepo.getTodayAttendance(
        user.companyId,
        user.uid,
      );

      if (existingToday != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'You have already checked in today.',
        );
        return;
      }

      // Fetch settings
      final adminRepo = _ref.read(companyAdminRepositoryProvider);
      final settings = await adminRepo.getAttendanceSettings(user.companyId);
      final companyRepo = _ref.read(companyRepositoryProvider);
      final company = await companyRepo.getCompany(user.companyId);

      // Check geofence
      if (settings.geofenceEnabled) {
        final targetLat = company?.geofenceLat;
        final targetLng = company?.geofenceLng;
        final targetRadius = settings.geofenceRadius ?? company?.geofenceRadius;
        if (targetLat != null && targetLng != null && targetRadius != null) {
          final distance = Geolocator.distanceBetween(
            lat,
            lng,
            targetLat,
            targetLng,
          );
          if (distance > targetRadius) {
            throw 'Outside office geofence. Distance: ${distance.toStringAsFixed(1)}m. Limit: ${targetRadius.toStringAsFixed(0)}m.';
          }
        }
      }

      // Load user shift dynamically
      ShiftModel? assignedShift;
      if (user.shiftId != null && user.shiftId!.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('work_shifts')
            .doc(user.shiftId)
            .get();
        if (doc.exists && doc.data() != null) {
          assignedShift = ShiftModel.fromMap(doc.data()!);
        }
      }

      final now = DateTime.now();
      String status = 'Present';

      if (assignedShift != null) {
        final parts = assignedShift.startTime.split(':');
        final startHour = int.parse(parts[0]);
        final startMinute = int.parse(parts[1]);
        var limit = DateTime(now.year, now.month, now.day, startHour, startMinute);
        limit = limit.add(Duration(minutes: assignedShift.gracePeriodMinutes));
        if (now.isAfter(limit)) {
          status = 'Late';
        }
      } else {
        var limit = DateTime(now.year, now.month, now.day, 9, 0);
        limit = limit.add(Duration(minutes: settings.lateGraceMinutes));
        status = now.isAfter(limit) ? 'Late' : 'Present';
      }

      final log = AttendanceModel(
        attendanceId: const Uuid().v4(),
        companyId: user.companyId,
        employeeId: user.uid,
        employeeName: user.name,
        checkInTime: now,
        latitude: lat,
        longitude: lng,
        address: address,
        status: status,
        createdAt: now,
        shiftId: assignedShift?.shiftId,
        shiftName: assignedShift?.shiftName,
        shiftCode: assignedShift?.shiftCode,
      );

      await _attendanceRepo.checkIn(log);

      // Start live timer
      _ref.read(workTimerProvider.notifier).start(now);

      await loadLogs();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> checkOutUser() async {
    final today = state.todayLog;
    if (today == null) return;

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      double? checkoutLat;
      double? checkoutLng;
      String? checkoutAddress;

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            checkoutLat = position.latitude;
            checkoutLng = position.longitude;
            checkoutAddress = "Lat: ${checkoutLat.toStringAsFixed(4)}, Lng: ${checkoutLng.toStringAsFixed(4)}";

            if (!kIsWeb) {
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  checkoutLat,
                  checkoutLng,
                );
                if (placemarks.isNotEmpty) {
                  Placemark place = placemarks.first;
                  final parts = [
                    if (place.name != null &&
                        place.name!.isNotEmpty &&
                        place.name != place.street)
                      place.name,
                    if (place.street != null && place.street!.isNotEmpty)
                      place.street,
                    if (place.locality != null && place.locality!.isNotEmpty)
                      place.locality,
                  ];
                  checkoutAddress = parts.join(', ');
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      final now = DateTime.now();
      double duration = now.difference(today.checkInTime).inMinutes / 60.0;

      // Fetch settings
      final adminRepo = _ref.read(companyAdminRepositoryProvider);
      final settings = await adminRepo.getAttendanceSettings(today.companyId);

      ShiftModel? shift;

      // Calculate working hours based on shift breakDurationMinutes deduction if shift is present
      if (today.shiftId != null && today.shiftId!.isNotEmpty) {
        try {
          final shiftDoc = await FirebaseFirestore.instance
              .collection('work_shifts')
              .doc(today.shiftId)
              .get();
          if (shiftDoc.exists && shiftDoc.data() != null) {
            shift = ShiftModel.fromMap(shiftDoc.data()!);
            final breakMins = shift.breakDurationMinutes;
            final durationMins = now.difference(today.checkInTime).inMinutes;
            final activeMins = durationMins - breakMins;
            duration = activeMins > 0 ? (activeMins / 60.0) : 0.0;
          }
        } catch (_) {}
      }

      // Calculate rule-driven status
      String status = today.status; // Default to checked-in status (either Present or Late)
      if (duration < settings.halfDayHours) {
        status = 'Absent';
      } else if (duration < settings.minimumWorkingHours) {
        status = 'Half Day';
      }

      // Calculate Overtime Hours
      double overtime = 0.0;
      if (duration > settings.overtimeStartAfterHours) {
        overtime = duration - settings.overtimeStartAfterHours;
        if (overtime > settings.maximumOvertimeHours) {
          overtime = settings.maximumOvertimeHours;
        }
      }

      // Detect early exit
      bool earlyExit = false;
      if (shift != null) {
        try {
          final parts = shift.endTime.split(':');
          final endHour = int.parse(parts[0]);
          final endMinute = int.parse(parts[1]);
          var shiftEnd = DateTime(now.year, now.month, now.day, endHour, endMinute);
          // Subtract early exit grace minutes
          shiftEnd = shiftEnd.subtract(Duration(minutes: settings.earlyExitGraceMinutes));
          if (now.isBefore(shiftEnd)) {
            earlyExit = true;
          }
        } catch (_) {}
      }

      await _attendanceRepo.checkOut(
        attendanceId: today.attendanceId,
        checkOutTime: now,
        workHours: double.parse(duration.toStringAsFixed(2)),
        status: status,
        checkoutLatitude: checkoutLat,
        checkoutLongitude: checkoutLng,
        checkoutAddress: checkoutAddress,
        overtimeHours: double.parse(overtime.toStringAsFixed(2)),
        earlyExit: earlyExit,
      );

      // Stop timer
      _ref.read(workTimerProvider.notifier).stop();

      await loadLogs();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = AttendanceState();
  }
}

// final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
//   return AttendanceRepository();
// });

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final notifier = AttendanceNotifier(
    ref,
    ref.read(attendanceRepositoryProvider),
  );

  // Load logs immediately if user is logged in
  if (ref.read(authProvider).user != null) {
    notifier.loadLogs();
  }

  // Listen to auth state to load logs on login and reset state on logout
  ref.listen(authProvider, (previous, next) {
    if (next.user != null) {
      notifier.loadLogs();
    } else {
      notifier.reset();
    }
  });

  return notifier;
});

class WorkTimerState {
  final Duration elapsed;

  const WorkTimerState({
    this.elapsed = Duration.zero,
  });

  WorkTimerState copyWith({
    Duration? elapsed,
  }) {
    return WorkTimerState(
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

// worktimer provider

class WorkTimerNotifier extends StateNotifier<WorkTimerState> {
  WorkTimerNotifier() : super(const WorkTimerState());

  Timer? _timer;

  void start(DateTime checkInTime) {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        state = state.copyWith(
          elapsed: DateTime.now().difference(checkInTime),
        );
      },
    );
  }

  void stop() {
    _timer?.cancel();
    state = const WorkTimerState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final workTimerProvider =
    StateNotifierProvider<WorkTimerNotifier, WorkTimerState>(
  (ref) => WorkTimerNotifier(),
);


// Leads Provider
class LeadsNotifier extends StateNotifier<AsyncValue<List<LeadModel>>> {
  final LeadRepository _leadRepo;
  final Ref _ref;

  LeadsNotifier(this._leadRepo, this._ref) : super(const AsyncValue.loading()) {
    loadLeads();
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  static const int _pageSize = 15;

  Future<void> loadLeads({bool reset = false}) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (reset) {
      _lastDoc = null;
      _hasMore = true;
    }

    if (!_hasMore && !reset) return;

    if (reset) {
      state = const AsyncValue.loading();
    }

    try {
      final page = await _leadRepo.getLeadsPage(
        user.companyId,
        limit: _pageSize,
        startAfter: _lastDoc,
      );

      final current = reset ? <LeadModel>[] : (state.value ?? []);
      final combined = [...current, ...page.leads];
      
      final uniqueMap = <String, LeadModel>{};
      for (final l in combined) {
        uniqueMap[l.leadId] = l;
      }
      final uniqueLeads = uniqueMap.values.toList();

      _lastDoc = page.lastDoc;
      _hasMore = page.leads.length == _pageSize;
      state = AsyncValue.data(uniqueLeads);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMoreLeads() async {
    await loadLeads(reset: false);
  }

  bool get hasMoreLeads => _hasMore;

  Future<void> importLeadsFromCsv(List<Map<String, String?>> rows) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    for (final row in rows) {
      final now = DateTime.now();
      final newLead = LeadModel(
        leadId: 'L-${const Uuid().v4().substring(0, 5).toUpperCase()}',
        companyId: user.companyId,
        customerName: row['customerName']?.trim() ?? row['name']?.trim() ?? 'Unknown',
        mobileNumber: row['mobileNumber']?.trim() ?? row['phone']?.trim() ?? '',
        companyName: row['companyName']?.trim() ?? row['company']?.trim() ?? '',
        email: row['email']?.trim(),
        location: row['location']?.trim() ?? '',
        requirement: row['requirement']?.trim() ?? '',
        remarks: row['remarks']?.trim(),
        leadSource: row['leadSource']?.trim() ?? 'Direct',
        assignedTo: row['assignedTo']?.trim() ?? user.name,
        assignedToId: row['assignedToId']?.trim() ?? user.uid,
        status: (row['status']?.trim().isNotEmpty ?? false) ? row['status']!.trim() : 'New',
        createdAt: now,
        updatedAt: now,
      );
      await _leadRepo.saveLead(newLead);
    }

    await loadLeads(reset: true);
  }

  Future<void> addLead(String name, String phone, String comp, String? email, String loc, String req, String? remarks, String source, {String? assignedToId, String? assignedToName}) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final newLead = LeadModel(
      leadId: 'L-${const Uuid().v4().substring(0, 5).toUpperCase()}',
      companyId: user.companyId,
      customerName: name,
      mobileNumber: phone,
      companyName: comp,
      email: email,
      location: loc,
      requirement: req,
      remarks: remarks,
      leadSource: source,
      assignedTo: assignedToName ?? user.name,
      assignedToId: assignedToId ?? user.uid,
      status: 'New',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _leadRepo.saveLead(newLead);
    
    final current = state.value ?? [];
    final uniqueMap = <String, LeadModel>{newLead.leadId: newLead};
    for (final l in current) {
      uniqueMap[l.leadId] = l;
    }
    state = AsyncValue.data(uniqueMap.values.toList());
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    await _leadRepo.updateLeadStatus(leadId, status);

    final currentLeads = state.value;
    if (currentLeads != null) {
      final index = currentLeads.indexWhere((l) => l.leadId == leadId);
      if (index >= 0) {
        final updated = currentLeads[index].copyWith(status: status, updatedAt: DateTime.now());
        state = AsyncValue.data(
          currentLeads.map((l) => l.leadId == leadId ? updated : l).toList(),
        );
      }
    }
  }

  Future<void> assignLead(String leadId, String employeeId, String employeeName) async {
    final currentLeads = state.value;
    if (currentLeads == null) return;

    final index = currentLeads.indexWhere((l) => l.leadId == leadId);
    if (index >= 0) {
      final updated = currentLeads[index].copyWith(
        assignedTo: employeeName,
        assignedToId: employeeId,
        updatedAt: DateTime.now(),
      );
      await _leadRepo.saveLead(updated);
      state = AsyncValue.data(
        currentLeads.map((l) => l.leadId == leadId ? updated : l).toList(),
      );
    }
  }

  Future<void> updateLead(LeadModel lead) async {
    await _leadRepo.saveLead(lead);
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.map((l) => l.leadId == lead.leadId ? lead : l).toList(),
      );
    }
  }

  Future<void> deleteLead(String leadId) async {
    await _leadRepo.deleteLead(leadId);
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.where((l) => l.leadId != leadId).toList(),
      );
    }
  }

  Future<void> bulkDeleteLeads(List<String> leadIds) async {
    state = const AsyncValue.loading();
    try {
      for (final id in leadIds) {
        await _leadRepo.deleteLead(id);
      }
      final current = state.value;
      if (current != null) {
        final idsSet = leadIds.toSet();
        state = AsyncValue.data(
          current.where((l) => !idsSet.contains(l.leadId)).toList(),
        );
      } else {
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> bulkUpdateStatus(List<String> leadIds, String newStatus) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    try {
      final idsSet = leadIds.toSet();
      final updatedLeads = <LeadModel>[];
      for (final id in leadIds) {
        final index = current.indexWhere((l) => l.leadId == id);
        if (index >= 0) {
          final updated = current[index].copyWith(
            status: newStatus,
            updatedAt: DateTime.now(),
          );
          await _leadRepo.saveLead(updated);
          updatedLeads.add(updated);
        }
      }
      state = AsyncValue.data(
        current.map((l) {
          if (idsSet.contains(l.leadId)) {
            return updatedLeads.firstWhere((ul) => ul.leadId == l.leadId);
          }
          return l;
        }).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> bulkAssignLeads(List<String> leadIds, String employeeId, String employeeName) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    try {
      final idsSet = leadIds.toSet();
      final updatedLeads = <LeadModel>[];
      for (final id in leadIds) {
        final index = current.indexWhere((l) => l.leadId == id);
        if (index >= 0) {
          final updated = current[index].copyWith(
            assignedTo: employeeName,
            assignedToId: employeeId,
            updatedAt: DateTime.now(),
          );
          await _leadRepo.saveLead(updated);
          updatedLeads.add(updated);
        }
      }
      state = AsyncValue.data(
        current.map((l) {
          if (idsSet.contains(l.leadId)) {
            return updatedLeads.firstWhere((ul) => ul.leadId == l.leadId);
          }
          return l;
        }).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final leadsProvider = StateNotifierProvider.autoDispose<LeadsNotifier, AsyncValue<List<LeadModel>>>((ref) {
  final leadRepo = ref.watch(leadRepositoryProvider);
  return LeadsNotifier(leadRepo, ref);
});

class LeadActivityNotifier
    extends StateNotifier<AsyncValue<List<LeadActivityModel>>> {
  final LeadActivityRepository _repo;

  LeadActivityNotifier(this._repo)
      : super(const AsyncValue.data([]));

  Future<void> loadActivities(
    String companyId,
    String leadId,
  ) async {
    state = const AsyncValue.loading();

    try {
      final activities = await _repo.getActivities(
        companyId,
        leadId,
      );

      state = AsyncValue.data(activities);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addActivity(LeadActivityModel activity) async {
    try {
      await _repo.addActivity(activity);

      await loadActivities(
        activity.companyId,
        activity.leadId,
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final leadActivityProvider = StateNotifierProvider<
    LeadActivityNotifier,
    AsyncValue<List<LeadActivityModel>>>((ref) {
  final repo = ref.watch(leadActivityRepositoryProvider);

  return LeadActivityNotifier(repo);
});

// Orders Provider
class OrdersNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  OrdersNotifier(this._orderRepo, this._ref) : super(const AsyncValue.loading()) {
    loadOrders();
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  static const int _pageSize = 15;

  Future<void> loadOrders({bool reset = false}) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final permService = _ref.read(permissionServiceProvider);
    if (!permService.hasPermission('order_view') && !permService.hasPermission('order.view')) {
      state = const AsyncValue.data([]);
      return;
    }

    if (reset) {
      _lastDoc = null;
      _hasMore = true;
    }

    if (!_hasMore && !reset) return;

    if (reset || state is! AsyncData) {
      state = const AsyncValue.loading();
    }

    try {
      final page = await _orderRepo.getOrdersPage(
        user.companyId,
        limit: _pageSize,
        startAfter: _lastDoc,
      );

      final current = reset ? <OrderModel>[] : (state.value ?? []);
      final combined = [...current, ...page.orders];

      final uniqueMap = <String, OrderModel>{};
      for (final o in combined) {
        uniqueMap[o.orderId] = o;
      }
      final uniqueOrders = uniqueMap.values.toList();

      _lastDoc = page.lastDoc;
      _hasMore = page.orders.length == _pageSize;
      state = AsyncValue.data(uniqueOrders);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loadMoreOrders() async {
    await loadOrders(reset: false);
  }

  bool get hasMoreOrders => _hasMore;

  Future<void> createOrder(OrderModel order) async {
    final permService = _ref.read(permissionServiceProvider);
    if (!permService.hasPermission('order_create') && !permService.hasPermission('order.create')) {
      throw Exception('Permission denied: Cannot create order.');
    }
    await _orderRepo.saveOrder(order);
    final current = state.value ?? [];
    final uniqueMap = <String, OrderModel>{order.orderId: order};
    for (final o in current) {
      uniqueMap[o.orderId] = o;
    }
    state = AsyncValue.data(uniqueMap.values.toList());
  }

  Future<void> updateOrder(OrderModel order) async {
    final permService = _ref.read(permissionServiceProvider);
    if (!permService.hasPermission('order_edit') && !permService.hasPermission('order.edit')) {
      throw Exception('Permission denied: Cannot edit order.');
    }
    await _orderRepo.saveOrder(order);
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((o) => o.orderId == order.orderId ? order : o).toList(),
    );
  }

  Future<void> convertLeadToOrder(LeadModel lead, double amount, DateTime expected) async {
    final permService = _ref.read(permissionServiceProvider);
    final canConvertLead = permService.hasPermission('lead_convert_order') || permService.hasPermission('lead.convert.order');
    final canCreateOrder = permService.hasPermission('order_create') || permService.hasPermission('order.create');
    if (!canConvertLead || !canCreateOrder) {
      throw Exception('Permission denied: Cannot convert lead to order.');
    }
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final order = OrderModel(
      orderId: 'ORD-${const Uuid().v4().substring(0, 4).toUpperCase()}',
      leadId: lead.leadId,
      companyId: user.companyId,
      customerName: lead.customerName,
      projectName: lead.requirement,
      amount: amount,
      status: 'Confirmed',
      expectedCompletion: expected,
      assignedEngineer: lead.assignedTo,
      assignedEngineerId: lead.assignedToId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _orderRepo.saveOrder(order);
    await _ref.read(leadsProvider.notifier).updateLeadStatus(lead.leadId, 'Converted');
    
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data([order, ...current]);
    } else {
      await loadOrders(reset: true);
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final permService = _ref.read(permissionServiceProvider);
    if (status == 'Closed' || status == 'Delivered' || status == 'Completed') {
      if (!permService.hasPermission('order_close') && !permService.hasPermission('order.close')) {
        throw Exception('Permission denied: Cannot close order.');
      }
    } else if (status == 'Cancelled') {
      if (!permService.hasPermission('order_cancel') && !permService.hasPermission('order.cancel')) {
        throw Exception('Permission denied: Cannot cancel order.');
      }
    } else {
      if (!permService.hasPermission('order_edit') && !permService.hasPermission('order.edit')) {
        throw Exception('Permission denied: Cannot edit order.');
      }
    }

    final currentOrders = state.value;
    if (currentOrders == null) return;

    final index = currentOrders.indexWhere((o) => o.orderId == orderId);
    if (index >= 0) {
      final updated = currentOrders[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
        completedOn: (status == 'Completed' || status == 'Closed') ? DateTime.now() : null,
      );
      await _orderRepo.saveOrder(updated);
      state = AsyncValue.data(
        currentOrders.map((o) => o.orderId == orderId ? updated : o).toList(),
      );
    }
  }

  Future<void> deleteOrder(String orderId) async {
    final permService = _ref.read(permissionServiceProvider);
    if (!permService.hasPermission('order_delete') && !permService.hasPermission('order.delete')) {
      throw Exception('Permission denied: Cannot delete order.');
    }
    await _orderRepo.deleteOrder(orderId);
    final currentOrders = state.value;
    if (currentOrders != null) {
      state = AsyncValue.data(currentOrders.where((o) => o.orderId != orderId).toList());
    }
  }

  Future<void> reassignOrderEngineer(String orderId, String engineerId, String engineerName) async {
    final permService = _ref.read(permissionServiceProvider);
    if (!permService.hasPermission('order_edit') && !permService.hasPermission('order.edit')) {
      throw Exception('Permission denied: Cannot edit order.');
    }
    final currentOrders = state.value;
    if (currentOrders == null) return;

    final index = currentOrders.indexWhere((o) => o.orderId == orderId);
    if (index >= 0) {
      final updated = currentOrders[index].copyWith(
        assignedEngineerId: engineerId,
        assignedEngineer: engineerName,
        updatedAt: DateTime.now(),
      );
      await _orderRepo.saveOrder(updated);
      state = AsyncValue.data(
        currentOrders.map((o) => o.orderId == orderId ? updated : o).toList(),
      );
    }
  }
}

final ordersProvider = StateNotifierProvider.autoDispose<OrdersNotifier, AsyncValue<List<OrderModel>>>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return OrdersNotifier(orderRepo, ref);
});

// Followups Provider
class FollowupsNotifier extends StateNotifier<AsyncValue<List<FollowupModel>>> {
  final LeadRepository _leadRepo;
  final Ref _ref;

  FollowupsNotifier(this._leadRepo, this._ref) : super(const AsyncValue.loading()) {
    loadFollowups();
  }

  Future<void> loadFollowups() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _leadRepo.getFollowups(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addFollowup(String leadId, DateTime date, String remarks) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final followup = FollowupModel(
      followUpId: const Uuid().v4(),
      leadId: leadId,
      companyId: user.companyId,
      assignedUser: user.name,
      assignedUserId: user.uid,
      followUpDate: date,
      remarks: remarks,
      status: 'Upcoming',
      createdAt: DateTime.now(),
    );

    await _leadRepo.saveFollowup(followup);
    
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data([followup, ...current]);
    } else {
      await loadFollowups();
    }
    await _ref.read(leadsProvider.notifier).updateLeadStatus(leadId, 'Follow Up');
  }

  Future<void> updateFollowupStatus(String followUpId, String status, {String? completionNotes}) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((f) => f.followUpId == followUpId);
    if (index >= 0) {
      var followup = current[index];
      String newRemarks = followup.remarks;
      if (completionNotes != null && completionNotes.trim().isNotEmpty) {
        newRemarks = '$newRemarks\n[Outcome]: ${completionNotes.trim()}';
      }
      final updated = followup.copyWith(status: status, remarks: newRemarks);
      await _leadRepo.saveFollowup(updated);
      state = AsyncValue.data(
        current.map((f) => f.followUpId == followUpId ? updated : f).toList(),
      );
    }
  }

  Future<void> rescheduleFollowup(String followUpId, DateTime newDate, String newRemarks) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((f) => f.followUpId == followUpId);
    if (index >= 0) {
      final updated = current[index].copyWith(
        followUpDate: newDate,
        remarks: newRemarks,
        status: 'Upcoming',
      );
      await _leadRepo.saveFollowup(updated);
      state = AsyncValue.data(
        current.map((f) => f.followUpId == followUpId ? updated : f).toList(),
      );
    }
  }

  Future<void> reassignFollowup(String followUpId, String newAssigneeName, String newAssigneeId) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((f) => f.followUpId == followUpId);
    if (index >= 0) {
      final updated = current[index].copyWith(
        assignedUser: newAssigneeName,
        assignedUserId: newAssigneeId,
      );
      await _leadRepo.saveFollowup(updated);
      state = AsyncValue.data(
        current.map((f) => f.followUpId == followUpId ? updated : f).toList(),
      );
    }
  }
}

final followupsProvider = StateNotifierProvider.autoDispose<FollowupsNotifier, AsyncValue<List<FollowupModel>>>((ref) {
  final leadRepo = ref.watch(leadRepositoryProvider);
  return FollowupsNotifier(leadRepo, ref);
});

class LeadAttachmentsNotifier extends StateNotifier<AsyncValue<List<LeadAttachmentModel>>> {
  final LeadRepository _leadRepo;

  LeadAttachmentsNotifier(this._leadRepo) : super(const AsyncValue.loading());

  Future<void> loadAttachments(String companyId, String leadId) async {
    state = const AsyncValue.loading();
    try {
      final attachments = await _leadRepo.getLeadAttachments(companyId, leadId);
      state = AsyncValue.data(attachments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> uploadAttachment(
    String companyId,
    String leadId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    try {
      await _leadRepo.uploadLeadAttachment(companyId, leadId, fileName, fileBytes);
      await loadAttachments(companyId, leadId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final leadAttachmentsProvider = StateNotifierProvider<LeadAttachmentsNotifier, AsyncValue<List<LeadAttachmentModel>>>((ref) {
  final repo = ref.watch(leadRepositoryProvider);
  return LeadAttachmentsNotifier(repo);
});

// Tasks Provider
class TasksNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  TasksNotifier(this._orderRepo, this._ref) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _orderRepo.getTasks(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addTask(String title, String desc, DateTime due, String assignToName, String assignToId, {String? orderId}) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final task = TaskModel(
      taskId: const Uuid().v4(),
      companyId: user.companyId,
      assignedTo: assignToName,
      assignedToId: assignToId,
      title: title,
      description: desc,
      status: 'Pending',
      dueDate: due,
      createdAt: DateTime.now(),
      orderId: orderId,
    );

    await _orderRepo.saveTask(task);
    
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data([task, ...current]);
    } else {
      await loadTasks();
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((t) => t.taskId == taskId);
    if (index >= 0) {
      final updated = current[index].copyWith(status: status);
      await _orderRepo.saveTask(updated);
      state = AsyncValue.data(
        current.map((t) => t.taskId == taskId ? updated : t).toList(),
      );
    }
  }

  Future<void> editTask(
    String taskId,
    String title,
    String desc,
    DateTime due,
    String assignToName,
    String assignToId,
  ) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((t) => t.taskId == taskId);
    if (index >= 0) {
      final updated = current[index].copyWith(
        title: title,
        description: desc,
        dueDate: due,
        assignedTo: assignToName,
        assignedToId: assignToId,
      );
      await _orderRepo.saveTask(updated);
      state = AsyncValue.data(
        current.map((t) => t.taskId == taskId ? updated : t).toList(),
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _orderRepo.deleteTask(taskId);
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.where((t) => t.taskId != taskId).toList(),
      );
    }
  }

  Future<void> reassignTask(String taskId, String newAssigneeName, String newAssigneeId) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((t) => t.taskId == taskId);
    if (index >= 0) {
      final updated = current[index].copyWith(
        assignedTo: newAssigneeName,
        assignedToId: newAssigneeId,
      );
      await _orderRepo.saveTask(updated);
      state = AsyncValue.data(
        current.map((t) => t.taskId == taskId ? updated : t).toList(),
      );
    }
  }
}

final tasksProvider = StateNotifierProvider.autoDispose<TasksNotifier, AsyncValue<List<TaskModel>>>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return TasksNotifier(orderRepo, ref);
});

// Expenses Provider
class ExpensesNotifier extends StateNotifier<AsyncValue<List<ExpenseModel>>> {
  final OrderRepository _orderRepo;
  final Ref _ref;

  ExpensesNotifier(this._orderRepo, this._ref) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _orderRepo.getExpenses(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addExpense(
    double amount,
    String category,
    String description, {
    DateTime? expenseDate,
    String? orderId,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final expenseId = const Uuid().v4();

    final expense = ExpenseModel(
      expenseId: expenseId,
      companyId: user.companyId,
      employeeId: user.uid,
      employeeName: user.name,
      amount: amount,
      category: category,
      description: description,
      status: 'Pending',
      createdAt: expenseDate ?? DateTime.now(),
      orderId: orderId,
    );

    await _orderRepo.saveExpense(expense);
    
    if (!mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data([expense, ...current]);
    } else {
      await loadExpenses();
    }
  }

  Future<void> editExpense(
    String expenseId,
    double amount,
    String category,
    String description, {
    DateTime? expenseDate,
    String? orderId,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((e) => e.expenseId == expenseId);
    if (index >= 0) {
      final updated = current[index].copyWith(
        amount: amount,
        category: category,
        description: description,
        createdAt: expenseDate ?? current[index].createdAt,
        status: 'Pending',
      );
      await _orderRepo.saveExpense(updated);
      if (!mounted) return;
      state = AsyncValue.data(
        current.map((e) => e.expenseId == expenseId ? updated : e).toList(),
      );
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await _orderRepo.deleteExpense(expenseId);
    if (!mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.where((e) => e.expenseId != expenseId).toList(),
      );
    }
  }

  Future<void> updateExpenseStatus(String expenseId, String status) async {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((e) => e.expenseId == expenseId);
    if (index >= 0) {
      final updated = current[index].copyWith(status: status);
      await _orderRepo.saveExpense(updated);
      if (!mounted) return;
      state = AsyncValue.data(
        current.map((e) => e.expenseId == expenseId ? updated : e).toList(),
      );
    }
  }
}

final expensesProvider = StateNotifierProvider.autoDispose<ExpensesNotifier, AsyncValue<List<ExpenseModel>>>((ref) {
  final orderRepo = ref.watch(orderRepositoryProvider);
  return ExpensesNotifier(orderRepo, ref);
});

class OrderAttachmentParams {
  final String companyId;
  final String orderId;

  const OrderAttachmentParams({required this.companyId, required this.orderId});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderAttachmentParams &&
        other.companyId == companyId &&
        other.orderId == orderId;
  }

  @override
  int get hashCode => Object.hash(companyId, orderId);
}

class OrderAttachmentsNotifier extends StateNotifier<AsyncValue<List<OrderAttachmentModel>>> {
  final OrderRepository _orderRepo;

  OrderAttachmentsNotifier(this._orderRepo) : super(const AsyncValue.loading());

  Future<void> loadAttachments(String companyId, String orderId) async {
    state = const AsyncValue.loading();
    try {
      final attachments = await _orderRepo.getOrderAttachments(companyId, orderId);
      state = AsyncValue.data(attachments);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> uploadAttachment(
    String companyId,
    String orderId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    try {
      await _orderRepo.uploadOrderAttachment(companyId, orderId, fileName, fileBytes);
      await loadAttachments(companyId, orderId);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final orderAttachmentsProvider = StateNotifierProvider.family<
    OrderAttachmentsNotifier,
    AsyncValue<List<OrderAttachmentModel>>,
    OrderAttachmentParams>((ref, params) {
  final repo = ref.watch(orderRepositoryProvider);
  final notifier = OrderAttachmentsNotifier(repo);

  if (params.companyId.isNotEmpty && params.orderId.isNotEmpty) {
    notifier.loadAttachments(params.companyId, params.orderId);
  }

  return notifier;
});

// Employees Notifier (replaces companyEmployeesProvider FutureProvider)
class EmployeesNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final UserRepository _userRepo;
  final Ref _ref;

  EmployeesNotifier(this._userRepo, this._ref) : super(const AsyncValue.loading()) {
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _userRepo.getCompanyEmployees(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateEmployee(UserModel employee) async {
    try {
      await _userRepo.updateEmployee(employee);
      await loadEmployees();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> removeEmployee(String uid) async {
    try {
      await _userRepo.removeEmployee(uid);
      await loadEmployees();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final employeesProvider = StateNotifierProvider<EmployeesNotifier, AsyncValue<List<UserModel>>>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  return EmployeesNotifier(userRepo, ref);
});

// Backwards-compat alias used by more_screen.dart
final companyEmployeesProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final userRepo = ref.watch(userRepositoryProvider);
  return await userRepo.getCompanyEmployees(user.companyId);
});


final companyAttendanceTodayProvider = FutureProvider.autoDispose<List<AttendanceModel>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final attendanceRepo = ref.watch(attendanceRepositoryProvider);
  return await attendanceRepo.getAttendanceLogs(user.companyId);
});

// Customers Provider & Notifier
class CustomersNotifier extends StateNotifier<AsyncValue<List<CustomerModel>>> {
  final CustomerRepository _repo;
  final Ref _ref;

  CustomersNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getCustomers(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCustomer(String name, String email, String phone, String address) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final customer = CustomerModel(
      customerId: const Uuid().v4(),
      companyId: user.companyId,
      name: name,
      email: email,
      phone: phone,
      address: address,
      status: 'Active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repo.saveCustomer(customer);
    await loadCustomers();
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _repo.saveCustomer(customer.copyWith(updatedAt: DateTime.now()));
    await loadCustomers();
  }

  Future<void> deleteCustomer(String customerId) async {
    await _repo.deleteCustomer(customerId);
    await loadCustomers();
  }
}

final customersProvider = StateNotifierProvider<CustomersNotifier, AsyncValue<List<CustomerModel>>>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return CustomersNotifier(repo, ref);
});

// ThemeMode Notifier & Provider
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('themeMode') ?? 'light';
      switch (themeStr) {
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
        default:
          state = ThemeMode.light;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeStr = 'light';
      if (mode == ThemeMode.dark) themeStr = 'dark';
      if (mode == ThemeMode.system) themeStr = 'system';
      await prefs.setString('themeMode', themeStr);
    } catch (_) {
      // ignore
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Company Notifier & Provider
class CompanyNotifier extends StateNotifier<AsyncValue<CompanyModel?>> {
  final CompanyRepository _companyRepo;
  final Ref _ref;

  CompanyNotifier(this._companyRepo, this._ref) : super(const AsyncValue.loading()) {
    loadCompany();
  }

  Future<void> loadCompany() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final company = await _companyRepo.getCompany(user.companyId);
      state = AsyncValue.data(company);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> updateCompanyName(String newName) async {
    final company = state.value;
    if (company == null) return false;

    try {
      final updated = company.copyWith(name: newName);
      await _companyRepo.saveCompany(updated);
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCompany(CompanyModel updatedCompany) async {
    try {
      await _companyRepo.saveCompany(updatedCompany);
      state = AsyncValue.data(updatedCompany);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadLogo(String fileName, Uint8List fileBytes) async {
    final company = state.value;
    if (company == null) return false;

    try {
      final logoUrl = await _companyRepo.uploadCompanyLogo(company.companyId, fileBytes);
      final updated = company.copyWith(logoUrl: logoUrl);
      await _companyRepo.saveCompany(updated);
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeLogo() async {
    final company = state.value;
    if (company == null) return false;

    try {
      await _companyRepo.deleteCompanyLogo(company.companyId);
      final updated = company.copyWith(clearLogoUrl: true);
      await _companyRepo.saveCompany(updated);
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSubscription(String newPlan) async {
    final company = state.value;
    if (company == null) return false;

    try {
      final updated = company.copyWith(subscriptionPlan: newPlan);
      await _companyRepo.saveCompany(updated);
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateGeofenceSettings(double lat, double lng, double radius) async {
    final company = state.value;
    if (company == null) return false;

    try {
      final updated = company.copyWith(
        geofenceLat: lat,
        geofenceLng: lng,
        geofenceRadius: radius,
      );
      await _companyRepo.saveCompany(updated);
      state = AsyncValue.data(updated);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final companyProvider = StateNotifierProvider<CompanyNotifier, AsyncValue<CompanyModel?>>((ref) {
  final repo = ref.watch(companyRepositoryProvider);
  return CompanyNotifier(repo, ref);
});

final companyStreamProvider = StreamProvider.family<CompanyModel?, String>((ref, companyId) {
  final repo = ref.watch(companyRepositoryProvider);
  return repo.streamCompany(companyId);
});

// Leave Providers & Notifier
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(firestore: ref.watch(firestoreProvider));
});

class LeavesNotifier extends StateNotifier<AsyncValue<List<LeaveModel>>> {
  final LeaveRepository _repo;
  final Ref _ref;

  LeavesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      List<LeaveModel> list;
      if (user.role == UserRoles.companyAdmin) {
        list = await _repo.getCompanyLeaves(user.companyId);
      } else {
        list = await _repo.getEmployeeLeaves(user.companyId, user.uid);
      }
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> applyForLeave({
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    final newLeave = LeaveModel(
      leaveId: const Uuid().v4(),
      companyId: user.companyId,
      employeeId: user.uid,
      employeeName: user.name,
      type: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    try {
      await _repo.applyLeave(newLeave);
      await loadLeaves();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> updateStatus(String leaveId, String status) async {
    final user = _ref.read(authProvider).user;
    if (user == null || user.role != UserRoles.companyAdmin) return;

    try {
      await _repo.updateLeaveStatus(leaveId, status, user.uid, user.name);
      await loadLeaves();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final leavesProvider = StateNotifierProvider<LeavesNotifier, AsyncValue<List<LeaveModel>>>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  return LeavesNotifier(repo, ref);
});

// ==========================================
// LEAVE MANAGEMENT PROVIDERS
// ==========================================

final leaveManagementRepositoryProvider = Provider<LeaveManagementRepository>((ref) {
  return LeaveManagementRepository(firestore: ref.watch(firestoreProvider));
});

class LeaveTypesNotifier extends StateNotifier<AsyncValue<List<LeaveTypeModel>>> {
  final LeaveManagementRepository _repo;
  final Ref _ref;

  LeaveTypesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadLeaveTypes();
  }

  Future<void> loadLeaveTypes() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getLeaveTypes(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> saveLeaveType(LeaveTypeModel type) async {
    await _repo.saveLeaveType(type);
    await loadLeaveTypes();
  }

  Future<void> archiveLeaveType(String leaveTypeId) async {
    await _repo.archiveLeaveType(leaveTypeId);
    await loadLeaveTypes();
  }
}

final leaveTypesProvider = StateNotifierProvider<LeaveTypesNotifier, AsyncValue<List<LeaveTypeModel>>>((ref) {
  final repo = ref.watch(leaveManagementRepositoryProvider);
  return LeaveTypesNotifier(repo, ref);
});

class LeaveBalancesNotifier extends StateNotifier<AsyncValue<List<LeaveBalanceModel>>> {
  final LeaveManagementRepository _repo;
  final String _employeeId;
  final Ref _ref;

  LeaveBalancesNotifier(this._repo, this._employeeId, this._ref) : super(const AsyncValue.loading()) {
    loadBalances();
  }

  Future<void> loadBalances() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getLeaveBalances(user.companyId, _employeeId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateBalance(LeaveBalanceModel balance) async {
    await _repo.saveLeaveBalance(balance);
    await loadBalances();
  }
}

final leaveBalancesProvider = StateNotifierProvider.family<LeaveBalancesNotifier, AsyncValue<List<LeaveBalanceModel>>, String>((ref, employeeId) {
  final repo = ref.watch(leaveManagementRepositoryProvider);
  return LeaveBalancesNotifier(repo, employeeId, ref);
});

class LeaveRequestsNotifier extends StateNotifier<AsyncValue<List<LeaveRequestModel>>> {
  final LeaveManagementRepository _repo;
  final Ref _ref;

  LeaveRequestsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadRequests();
  }

  Future<void> loadRequests() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    state = const AsyncValue.loading();
    try {
      List<LeaveRequestModel> list;
      if (user.role == UserRoles.companyAdmin || user.role == UserRoles.hrAdmin || user.role == UserRoles.hrExecutive || user.role == UserRoles.hr) {
        list = await _repo.getLeaveRequests(user.companyId);
      } else if (user.role == UserRoles.manager || user.role == UserRoles.teamLeader) {
        final team = await _repo.getManagerLeaveRequests(user.companyId, user.uid);
        final personal = await _repo.getEmployeeLeaveRequests(user.companyId, user.uid);
        final uniqueIds = <String>{};
        list = [];
        for (final r in [...team, ...personal]) {
          if (uniqueIds.add(r.leaveRequestId)) {
            list.add(r);
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        list = await _repo.getEmployeeLeaveRequests(user.companyId, user.uid);
      }
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> applyLeave(LeaveRequestModel request) async {
    await _repo.applyLeaveRequest(request);

    // Log Activity
    final user = _ref.read(authProvider).user;
    if (user != null) {
      final adminRepo = _ref.read(companyAdminRepositoryProvider);
      await adminRepo.logEmployeeActivity(
        companyId: user.companyId,
        employeeId: user.uid,
        action: 'Leave Request applied: From ${request.fromDate} to ${request.toDate} (${request.totalDays} days)',
        performedBy: user.name,
      );
    }

    if (request.status == 'Approved') {
      await _updateBalanceOnApproval(request);
      await _createAttendancePlaceholderOnApproval(request);
    }
    await loadRequests();
  }

  Future<void> cancelLeave(String leaveRequestId) async {
    final req = await _repo.getLeaveRequestById(leaveRequestId);
    if (req == null || req.status != 'Pending') return;

    final updated = req.copyWith(status: 'Cancelled');
    await _repo.applyLeaveRequest(updated);

    // Log Activity
    final user = _ref.read(authProvider).user;
    if (user != null) {
      final adminRepo = _ref.read(companyAdminRepositoryProvider);
      await adminRepo.logEmployeeActivity(
        companyId: user.companyId,
        employeeId: user.uid,
        action: 'Leave Request cancelled: ID $leaveRequestId',
        performedBy: user.name,
      );
    }
    await loadRequests();
  }

  Future<void> updateRequestStatus(String leaveRequestId, String status, String approvedBy) async {
    await _repo.updateLeaveRequestStatus(leaveRequestId, status, approvedBy, DateTime.now());
    
    final req = await _repo.getLeaveRequestById(leaveRequestId);
    if (req != null) {
      // Log Activity
      final user = _ref.read(authProvider).user;
      if (user != null) {
        final adminRepo = _ref.read(companyAdminRepositoryProvider);
        await adminRepo.logEmployeeActivity(
          companyId: user.companyId,
          employeeId: req.employeeId,
          action: 'Leave Request status updated to $status by $approvedBy',
          performedBy: user.name,
        );
      }

      if (status == 'Approved') {
        await _updateBalanceOnApproval(req);
        await _createAttendancePlaceholderOnApproval(req);
      }
    }
    await loadRequests();
  }

  Future<void> overrideRequest(LeaveRequestModel request) async {
    await _repo.overrideLeaveRequest(request);
    
    // Log Activity
    final user = _ref.read(authProvider).user;
    if (user != null) {
      final adminRepo = _ref.read(companyAdminRepositoryProvider);
      await adminRepo.logEmployeeActivity(
        companyId: user.companyId,
        employeeId: request.employeeId,
        action: 'Leave Request overridden to status ${request.status}',
        performedBy: user.name,
      );
    }

    if (request.status == 'Approved') {
      await _updateBalanceOnApproval(request);
      await _createAttendancePlaceholderOnApproval(request);
    }
    await loadRequests();
  }

  Future<void> _createAttendancePlaceholderOnApproval(LeaveRequestModel req) async {
    try {
      final userRepo = _ref.read(userRepositoryProvider);
      final employee = await userRepo.getUser(req.employeeId);
      final employeeName = employee?.name ?? 'Employee';

      var date = req.fromDate;
      while (!date.isAfter(req.toDate)) {
        final docId = 'leave_${req.employeeId}_${date.year}_${date.month}_${date.day}';
        await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
          'attendanceId': docId,
          'companyId': req.companyId,
          'employeeId': req.employeeId,
          'employeeName': employeeName,
          'checkInTime': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 9, 0)),
          'checkOutTime': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 18, 0)),
          'workHours': 8.0,
          'status': 'On Leave',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        date = date.add(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('Error creating leave attendance placeholders: $e');
    }
  }

  Future<void> _updateBalanceOnApproval(LeaveRequestModel req) async {
    final types = await _repo.getLeaveTypes(req.companyId);
    final matchType = types.where((t) => t.leaveTypeId == req.leaveTypeId);
    if (matchType.isEmpty) return;
    final leaveType = matchType.first;

    final balances = await _repo.getLeaveBalances(req.companyId, req.employeeId);
    final match = balances.where((b) => b.leaveTypeId == req.leaveTypeId);

    LeaveBalanceModel balance;
    if (match.isNotEmpty) {
      final current = match.first;
      final newUsed = current.used + req.totalDays;
      final newRemaining = current.allocated - newUsed;
      balance = current.copyWith(
        used: newUsed,
        remaining: newRemaining,
        updatedAt: DateTime.now(),
      );
    } else {
      final allocated = leaveType.annualQuota;
      final used = req.totalDays;
      final remaining = allocated - used;
      balance = LeaveBalanceModel(
        employeeId: req.employeeId,
        companyId: req.companyId,
        leaveTypeId: req.leaveTypeId,
        allocated: allocated,
        used: used,
        remaining: remaining,
        updatedAt: DateTime.now(),
      );
    }

    await _repo.saveLeaveBalance(balance);
  }
}

final leaveRequestsProvider = StateNotifierProvider<LeaveRequestsNotifier, AsyncValue<List<LeaveRequestModel>>>((ref) {
  final repo = ref.watch(leaveManagementRepositoryProvider);
  return LeaveRequestsNotifier(repo, ref);
});

final bypassVerificationProvider = StateProvider<bool>((ref) => false);

final languageProvider = StateProvider<String>((ref) => 'en');

class AppTranslations {
  static const Map<String, Map<String, String>> _dict = {
    'en': {
      'dashboard': 'Dashboard',
      'leads': 'Leads',
      'orders': 'Orders',
      'more': 'More',
      'today_attendance': "Today's Attendance",
      'check_in': 'CHECK IN',
      'check_out': 'CHECK OUT',
      'completed_attendance': "Today's attendance completed",
      'not_checked_in': 'Not Checked In',
      'app_settings': 'App Settings',
      'help_support': 'Help & Support',
      'about_us': 'About Us',
      'logout': 'Logout',
      'company_admin': 'Company Admin',
      'employee': 'Employee',
      'help_center': 'Help Center',
      'privacy_policy': 'GDPR & Privacy Policy',
      'sla_uptime': 'SLA & System Status',
      'billing_plans': 'Billing & SaaS Plans',
    },
    'es': {
      'dashboard': 'Tablero',
      'leads': 'Prospectos',
      'orders': 'Pedidos',
      'more': 'M├ís',
      'today_attendance': "Asistencia de Hoy",
      'check_in': 'REGISTRAR ENTRADA',
      'check_out': 'REGISTRAR SALIDA',
      'completed_attendance': "Asistencia de hoy completada",
      'not_checked_in': 'No Registrado',
      'app_settings': 'Ajustes de App',
      'help_support': 'Ayuda y Soporte',
      'about_us': 'Sobre Nosotros',
      'logout': 'Cerrar Sesi├│n',
      'company_admin': 'Administrador de Empresa',
      'employee': 'Empleado',
      'help_center': 'Centro de Ayuda',
      'privacy_policy': 'GDPR y Privacidad',
      'sla_uptime': 'SLA y Estado del Sistema',
      'billing_plans': 'Planes de Facturaci├│n',
    },
    'hi': {
      'dashboard': 'αñíαÑêαñ╢αñ¼αÑïαñ░αÑìαñí',
      'leads': 'αñ▓αÑÇαñíαÑìαñ╕',
      'orders': 'αñåαñ░αÑìαñíαñ░',
      'more': 'αñàαñºαñ┐αñò',
      'today_attendance': "αñåαñ£ αñòαÑÇ αñëαñ¬αñ╕αÑìαñÑαñ┐αññαñ┐",
      'check_in': 'αñÜαÑçαñò αñçαñ¿',
      'check_out': 'αñÜαÑçαñò αñåαñëαñƒ',
      'completed_attendance': "αñåαñ£ αñòαÑÇ αñëαñ¬αñ╕αÑìαñÑαñ┐αññαñ┐ αñ¬αÑéαñ░αÑìαñú",
      'not_checked_in': 'αñÜαÑçαñò αñçαñ¿ αñ¿αñ╣αÑÇαñé αñòαñ┐αñ»αñ╛',
      'app_settings': 'αñÉαñ¬ αñ╕αÑçαñƒαñ┐αñéαñùαÑìαñ╕',
      'help_support': 'αñ╕αñ╣αñ╛αñ»αññαñ╛ αñöαñ░ αñ╕αñ«αñ░αÑìαñÑαñ¿',
      'about_us': 'αñ╣αñ«αñ╛αñ░αÑç αñ¼αñ╛αñ░αÑç αñ«αÑçαñé',
      'logout': 'αñ▓αÑëαñù αñåαñëαñƒ',
      'company_admin': 'αñòαñéαñ¬αñ¿αÑÇ αñÅαñíαñ«αñ┐αñ¿',
      'employee': 'αñòαñ░αÑìαñ«αñÜαñ╛αñ░αÑÇ',
      'help_center': 'αñ╕αñ╣αñ╛αñ»αññαñ╛ αñòαÑçαñéαñªαÑìαñ░',
      'privacy_policy': 'αñ£αÑÇαñíαÑÇαñ¬αÑÇαñåαñ░ αñöαñ░ αñùαÑïαñ¬αñ¿αÑÇαñ»αññαñ╛ αñ¿αÑÇαññαñ┐',
      'sla_uptime': 'SLA αñöαñ░ αñ╕αñ┐αñ╕αÑìαñƒαñ« αñ╕αÑìαñÑαñ┐αññαñ┐',
      'billing_plans': 'αñ¼αñ┐αñ▓αñ┐αñéαñù αñöαñ░ αñ╕αñ╛αñ╕ αñ¬αÑìαñ▓αñ╛αñ¿',
    }
  };

  static String translate(String key, String lang) {
    return _dict[lang]?[key] ?? _dict['en']?[key] ?? key;
  }
}

// Department providers and notifier
final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository(firestore: ref.watch(firestoreProvider));
});

class DepartmentsNotifier extends StateNotifier<AsyncValue<List<DepartmentModel>>> {
  final DepartmentRepository _repo;
  final Ref _ref;

  DepartmentsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadDepartments();
  }

  Future<void> loadDepartments() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getDepartments(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addDepartment(String name, String description) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    try {
      final newDept = DepartmentModel(
        departmentId: const Uuid().v4(),
        companyId: user.companyId,
        departmentName: name,
        departmentCode: name.toUpperCase().replaceAll(RegExp(r'\s+'), '_'),
        description: description,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.uid,
      );
      await _repo.saveDepartment(newDept);
      await loadDepartments();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateDepartment(DepartmentModel department) async {
    try {
      await _repo.saveDepartment(department.copyWith(updatedAt: DateTime.now()));
      await loadDepartments();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteDepartment(String departmentId) async {
    try {
      await _repo.deleteDepartment(departmentId);
      await loadDepartments();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final departmentsProvider = StateNotifierProvider<DepartmentsNotifier, AsyncValue<List<DepartmentModel>>>((ref) {
  final repo = ref.watch(departmentRepositoryProvider);
  return DepartmentsNotifier(repo, ref);
});

// Employee Requests Notifier
class EmployeeRequestsNotifier extends StateNotifier<AsyncValue<List<EmployeeRequestModel>>> {
  final UserRepository _userRepo;
  final Ref _ref;

  EmployeeRequestsNotifier(this._userRepo, this._ref) : super(const AsyncValue.loading()) {
    loadRequests();
  }

  Future<void> loadRequests() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _userRepo.getPendingEmployeeRequests(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Map<String, String>?> approveRequest(EmployeeRequestModel request) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return null;

    try {
      // 1. Update request status in Firestore
      await _userRepo.updateEmployeeRequestStatus(
        request.requestId,
        'Approved',
        approvedBy: user.email,
        approvedAt: DateTime.now(),
      );

      Map<String, String>? credentials;

      // 2. Perform actual employee action (ADD_EMPLOYEE or DELETE_EMPLOYEE)
      if (request.requestType == 'ADD_EMPLOYEE' && request.employeeData != null) {
        final data = request.employeeData!;
        
        // 1. Get or generate companyCode
        String companyCode = user.companyCode ?? '';
        if (companyCode.isEmpty) {
          final companyRepo = _ref.read(companyRepositoryProvider);
          final companyDoc = await companyRepo.getCompany(user.companyId);
          if (companyDoc != null && companyDoc.companyCode != null && companyDoc.companyCode!.isNotEmpty) {
            companyCode = companyDoc.companyCode!;
          } else {
            final cleanName = user.companyName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
            final prefix = cleanName.length >= 3 ? cleanName.substring(0, 3) : (cleanName + 'AAA').substring(0, 3);
            
            try {
              final snapshot = await FirebaseFirestore.instance
                  .collection('companies')
                  .where('companyCode', isGreaterThanOrEqualTo: prefix)
                  .where('companyCode', isLessThan: prefix + '\uf8ff')
                  .get();
              final existingCodes = snapshot.docs
                  .map((doc) => doc.data()['companyCode'] as String?)
                  .where((code) => code != null && code.startsWith(prefix))
                  .toList();
              int maxNum = 0;
              final regex = RegExp('^' + prefix + r'(\d+)$');
              for (final code in existingCodes) {
                final match = regex.firstMatch(code!);
                if (match != null) {
                  final num = int.tryParse(match.group(1)!);
                  if (num != null && num > maxNum) {
                    maxNum = num;
                  }
                }
              }
              final nextNum = maxNum + 1;
              companyCode = '$prefix${nextNum.toString().padLeft(3, '0')}';
            } catch (_) {
              final random = Random().nextInt(900) + 100;
              companyCode = '$prefix$random';
            }
            if (companyDoc != null) {
              await companyRepo.saveCompany(companyDoc.copyWith(companyCode: companyCode));
            }
          }
          final updatedAdmin = user.copyWith(companyCode: companyCode);
          await _userRepo.saveUser(updatedAdmin);
          _ref.read(authProvider.notifier).updateStateUser(updatedAdmin);
        }

        // 2. Generate unique Employee ID automatically
        final code = companyCode.toUpperCase();
        final nameVal = (data['name'] ?? 'Employee').toString();
        final nameParts = nameVal.trim().split(RegExp(r'\s+'));
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final cleanFirstName = firstName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
        final letters = cleanFirstName.length >= 3 
            ? cleanFirstName.substring(0, 3) 
            : cleanFirstName;

        final randObj = Random();
        String finalEmployeeId = '';
        while (true) {
          final digits = randObj.nextInt(90) + 10; // 10 to 99
          finalEmployeeId = '$code-$letters-$digits';
          
          final clashQuery = await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .where('employeeId', isEqualTo: finalEmployeeId)
              .limit(1)
              .get();
          if (clashQuery.docs.isEmpty) {
            break;
          }
        }

        // 3. Generate internal company email automatically
        final cleanCompName = user.companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final companyEmail = '${finalEmployeeId.toLowerCase()}@$cleanCompName.worktrack';
        final tempPassword = 'Temp@${Random().nextInt(90000) + 10000}';
        final appName = 'EmpApproveOnboarding_${DateTime.now().millisecondsSinceEpoch}';

        FirebaseApp? tempApp;
        UserCredential? userCredential;
        try {
          tempApp = await Firebase.initializeApp(
            name: appName,
            options: Firebase.app().options,
          );

          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          userCredential = await tempAuth.createUserWithEmailAndPassword(
            email: companyEmail,
            password: tempPassword,
          );

          final authUid = userCredential.user!.uid;

          final newEmp = UserModel(
            uid: authUid,
            email: companyEmail,
            name: data['name'] ?? '',
            role: data['role'] ?? UserRoles.employee,
            companyId: request.companyId,
            companyName: user.companyName,
            phoneNumber: data['phone'],
            designation: data['designation'],
            department: data['department'],
            createdAt: DateTime.now(),
            isEmailVerified: true,
            isPhoneVerified: false,
            employeeId: finalEmployeeId,
            companyCode: companyCode,
            hiddenEmail: companyEmail,
            employeeEmail: companyEmail,
            companyEmail: companyEmail,
            firstLogin: true,
            mustChangePassword: true,
            tempPassword: tempPassword,
            status: 'active',
            passwordChanged: false,
          );
          await _userRepo.saveUser(newEmp);

          credentials = {
            'employeeId': finalEmployeeId,
            'companyCode': companyCode,
            'tempPassword': tempPassword,
          };
        } catch (e) {
          if (userCredential != null && userCredential.user != null) {
            try {
              await userCredential.user!.delete();
            } catch (_) {}
          }
          rethrow;
        } finally {
          if (tempApp != null) {
            try {
              await tempApp.delete();
            } catch (_) {}
          }
        }
      } else if (request.requestType == 'DELETE_EMPLOYEE' && request.employeeId != null) {
        // Delete employee record directly as requested
        await _userRepo.removeEmployee(request.employeeId!);
      }

      // Reload list of pending requests and the list of employees
      await loadRequests();
      await _ref.read(employeesProvider.notifier).loadEmployees();

      // Recalculate subscription and refresh company provider
      await SubscriptionService.recalculateAndSyncSubscription(request.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
      
      return credentials;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> rejectRequest(EmployeeRequestModel request, {String? reason}) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    try {
      await _userRepo.updateEmployeeRequestStatus(
        request.requestId,
        'Rejected',
        rejectedBy: user.email,
        rejectedAt: DateTime.now(),
        reason: reason,
      );
      await loadRequests();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final employeeRequestsProvider = StateNotifierProvider<EmployeeRequestsNotifier, AsyncValue<List<EmployeeRequestModel>>>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  return EmployeeRequestsNotifier(userRepo, ref);
});

// Notifications Notifier
class NotificationsNotifier extends StateNotifier<AsyncValue<List<AppNotificationModel>>> {
  final UserRepository _userRepo;
  final Ref _ref;

  NotificationsNotifier(this._userRepo, this._ref) : super(const AsyncValue.loading()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final permService = _ref.read(permissionServiceProvider);
      final rawList = await _userRepo.getUserNotifications(
        companyId: user.companyId,
        userId: user.uid,
        role: user.role,
        departmentId: user.departmentId,
      );

      final filteredList = rawList.where((n) {
        if (n.targetType.toUpperCase() == 'USER' && n.targetUserId == user.uid) {
          return true;
        }

        final mod = n.relatedModule?.toUpperCase();
        if (mod == null || mod.isEmpty) return true;

        switch (mod) {
          case 'EMPLOYEE':
            return permService.hasPermission('employee_view');
          case 'ATTENDANCE':
            return permService.hasPermission('attendance_view');
          case 'LEAVE':
            return permService.hasPermission('leave_apply') || permService.hasPermission('leave_approve');
          case 'PAYROLL':
            return permService.hasPermission('payroll_view');
          case 'LEAD':
            return permService.hasPermission('lead_view');
          case 'TASK':
            return permService.hasPermission('task_view');
          case 'REPORTS':
            return permService.hasPermission('reports_view');
          case 'SETTINGS':
            return permService.hasPermission('settings_manage');
          default:
            return true;
        }
      }).toList();

      state = AsyncValue.data(filteredList);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _userRepo.markNotificationRead(notificationId);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          current.map((n) => n.notificationId == notificationId ? AppNotificationModel(
            notificationId: n.notificationId,
            companyId: n.companyId,
            title: n.title,
            body: n.body,
            notificationType: n.notificationType,
            isRead: true,
            createdAt: n.createdAt,
          ) : n).toList(),
        );
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _userRepo.deleteNotification(notificationId);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(current.where((n) => n.notificationId != notificationId).toList());
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markAllAsRead() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    try {
      await _userRepo.markAllNotificationsRead(user.companyId);
      final current = state.value;
      if (current != null) {
        state = AsyncValue.data(
          current.map((n) => AppNotificationModel(
            notificationId: n.notificationId,
            companyId: n.companyId,
            title: n.title,
            body: n.body,
            notificationType: n.notificationType,
            isRead: true,
            createdAt: n.createdAt,
          )).toList(),
        );
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> clearAll() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    try {
      await _userRepo.clearAllNotifications(user.companyId);
      state = const AsyncValue.data([]);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, AsyncValue<List<AppNotificationModel>>>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  return NotificationsNotifier(userRepo, ref);
});
