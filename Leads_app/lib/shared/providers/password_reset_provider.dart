import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/password_reset_request_model.dart';
import '../models/password_reset_audit_log_model.dart';
import '../models/user_model.dart';
import '../models/app_notification_model.dart';
import '../repositories/password_reset_repository.dart';
import '../services/password_encryption.dart';
import '../services/recovery_code_service.dart';
import '../services/security_pin_service.dart';
import '../services/audit_log_service.dart';
import '../services/app_error_handler.dart';
import '../providers/providers.dart';
import '../../constants/firestore_collections.dart';
import '../../constants/user_roles.dart';

final passwordResetRepositoryProvider = Provider<PasswordResetRepository>((ref) {
  return PasswordResetRepository(firestore: ref.watch(firestoreProvider));
});

class PasswordResetState {
  final List<PasswordResetRequestModel> requests;
  final List<PasswordResetAuditLogModel> auditLogs;
  final bool isLoading;
  final String? errorMessage;

  PasswordResetState({
    this.requests = const [],
    this.auditLogs = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PasswordResetState copyWith({
    List<PasswordResetRequestModel>? requests,
    List<PasswordResetAuditLogModel>? auditLogs,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PasswordResetState(
      requests: requests ?? this.requests,
      auditLogs: auditLogs ?? this.auditLogs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PasswordResetNotifier extends StateNotifier<PasswordResetState> {
  final PasswordResetRepository _repo;
  final Ref _ref;

  PasswordResetNotifier(this._repo, this._ref) : super(PasswordResetState());

  /// Load requests for company
  Future<void> loadRequests() async {
    final currentUser = _ref.read(authProvider).user;
    if (currentUser == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repo.getCompanyRequests(currentUser.companyId);
      final logs = await _repo.getAuditLogs(currentUser.companyId);
      state = PasswordResetState(requests: list, auditLogs: logs, isLoading: false);
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
    }
  }

  /// Helper to generate a secure random password (e.g., WT@X7k92!P)
  String _generateSecureTemporaryPassword() {
    const uppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lowercase = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = r'!@#$%^&*';
    final rand = Random.secure();

    final passChars = [
      'W',
      'T',
      '@',
      uppercase[rand.nextInt(uppercase.length)],
      lowercase[rand.nextInt(lowercase.length)],
      digits[rand.nextInt(digits.length)],
      digits[rand.nextInt(digits.length)],
      symbols[rand.nextInt(symbols.length)],
      uppercase[rand.nextInt(uppercase.length)],
    ];

    passChars.shuffle(rand);
    return passChars.join();
  }

  /// ---------------- 0. EMPLOYEE SELF-SERVICE RECOVERY VERIFICATION ----------------
  Future<UserModel?> verifyEmployeeSelfServiceRecovery({
    required String employeeId,
    required String registeredMobile,
    required String securityPin,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final cleanEmpId = employeeId.trim();
    final cleanMobile = registeredMobile.trim().replaceAll(RegExp(r'\D'), '');
    final cleanPin = securityPin.trim();

    const genericError = 'Unable to verify your account details. Please check your information and try again.';

    try {
      if (cleanEmpId.isEmpty || cleanMobile.isEmpty || cleanPin.length != 6) {
        state = state.copyWith(isLoading: false, errorMessage: genericError);
        return null;
      }

      final usersRef = FirebaseFirestore.instance.collection(FirestoreCollections.users);
      var query = await usersRef.where('employeeId', isEqualTo: cleanEmpId).limit(1).get();
      if (query.docs.isEmpty) {
        query = await usersRef.where('employeeId', isEqualTo: cleanEmpId.toUpperCase()).limit(1).get();
      }
      if (query.docs.isEmpty) {
        query = await usersRef.where('employeeId', isEqualTo: cleanEmpId.toLowerCase()).limit(1).get();
      }

      if (query.docs.isEmpty) {
        state = state.copyWith(isLoading: false, errorMessage: genericError);
        return null;
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data();
      final empUser = UserModel.fromMap(userData);

      // Log recovery attempt
      await AuditLogService.logEvent(
        companyId: empUser.companyId,
        employeeId: empUser.employeeId ?? cleanEmpId,
        action: 'PASSWORD_RECOVERY_ATTEMPTED',
        triggeredBy: 'Employee',
      );

      // Verify account active
      if (empUser.status.toLowerCase() == 'suspended' || empUser.status.toLowerCase() == 'deleted') {
        state = state.copyWith(isLoading: false, errorMessage: genericError);
        return null;
      }

      // Verify registered mobile number
      final phone = (empUser.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
      final emergencyPhone = (empUser.emergencyContactPhone ?? '').replaceAll(RegExp(r'\D'), '');
      final companyMobile = (userData['companyMobile'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

      bool mobileMatches = false;
      if (cleanMobile.isNotEmpty) {
        if (phone.isNotEmpty && phone.endsWith(cleanMobile)) mobileMatches = true;
        if (emergencyPhone.isNotEmpty && emergencyPhone.endsWith(cleanMobile)) mobileMatches = true;
        if (companyMobile.isNotEmpty && companyMobile.endsWith(cleanMobile)) mobileMatches = true;
      }

      if (!mobileMatches) {
        state = state.copyWith(isLoading: false, errorMessage: genericError);
        return null;
      }

      // Verify Security PIN
      final isPinValid = SecurityPinService.verifyPin(cleanPin, empUser.securityPinHash);
      if (!isPinValid) {
        state = state.copyWith(isLoading: false, errorMessage: genericError);
        return null;
      }

      state = state.copyWith(isLoading: false);
      return empUser;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: genericError,
      );
      return null;
    }
  }

  /// ---------------- 1. EMPLOYEE REQUEST PASSWORD RESET ----------------
  Future<bool> submitEmployeeRequest({
    required String employeeId,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final cleanEmpId = employeeId.trim();
    final cleanReason = reason.trim().isNotEmpty
        ? reason.trim()
        : 'I forgot my password and need access to my WorkTrack account.';

    try {
      if (cleanEmpId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Please enter your Employee ID.',
        );
        return false;
      }

      // Find user document in Firestore by employeeId
      final usersRef = FirebaseFirestore.instance.collection(FirestoreCollections.users);
      var query = await usersRef.where('employeeId', isEqualTo: cleanEmpId).limit(1).get();
      if (query.docs.isEmpty) {
        query = await usersRef.where('employeeId', isEqualTo: cleanEmpId.toUpperCase()).limit(1).get();
      }
      if (query.docs.isEmpty) {
        query = await usersRef.where('employeeId', isEqualTo: cleanEmpId.toLowerCase()).limit(1).get();
      }

      if (query.docs.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Employee ID not found. Please check your Employee ID and try again.',
        );
        return false;
      }

      final userDoc = query.docs.first;
      final userData = userDoc.data();
      final empUser = UserModel.fromMap(userData);

      // Verify account active
      if (empUser.status.toLowerCase() == 'suspended' || empUser.status.toLowerCase() == 'deleted') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Account is inactive or suspended. Please contact your administrator.',
        );
        return false;
      }

      // Check if employee already has a Pending/In Review request that is not expired
      final existingPending = await _repo.getPendingRequestForEmployee(empUser.companyId, empUser.uid);
      if (existingPending != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'You already have a pending password reset request. Please contact your Company Admin.',
        );
        return false;
      }

      // Create new request
      final requestId = 'PRR-${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final request = PasswordResetRequestModel(
        requestId: requestId,
        companyId: empUser.companyId,
        employeeUid: empUser.uid,
        employeeId: empUser.displayEmployeeId,
        employeeName: empUser.name,
        department: empUser.department,
        registeredMobile: empUser.phoneNumber ?? empUser.emergencyContactPhone ?? '',
        reason: cleanReason,
        status: 'Pending',
        createdAt: now,
        expiresAt: expiresAt,
      );

      await _repo.createRequest(request);

      // Route request notification specifically to Company Admin(s) for the employee's company
      final targetUids = <String>{};

      final companyUsersSnap = await usersRef
          .where('companyId', isEqualTo: empUser.companyId)
          .get();

      for (final doc in companyUsersSnap.docs) {
        final uData = doc.data();
        final uModel = UserModel.fromMap(uData);
        if (uModel.uid == empUser.uid) continue; // Don't notify self

        final r = uModel.role.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_').trim();
        if (r == 'company_admin' || r == 'admin' || r == 'hr_admin' || uModel.role == UserRoles.companyAdmin) {
          targetUids.add(uModel.uid);
        }
      }

      // Create in-app notifications targeting Company Admins
      if (targetUids.isNotEmpty) {
        for (final recipientUid in targetUids) {
          final notif = AppNotificationModel(
            notificationId: const Uuid().v4(),
            companyId: empUser.companyId,
            title: 'Password Reset Request',
            body: 'Employee ${empUser.name} (${empUser.displayEmployeeId}) has requested a password reset.',
            notificationType: 'PASSWORD_RESET_REQUEST',
            isRead: false,
            createdAt: now,
            targetType: 'USER',
            targetUserId: recipientUid,
            actorUserId: empUser.uid,
            actorName: empUser.name,
            relatedModule: 'PASSWORD_RESET',
            relatedEntityId: requestId,
          );
          await _ref.read(userRepositoryProvider).createNotification(notif);
        }
      } else {
        // Fallback: Create company-wide targeted notification for company admins
        final notif = AppNotificationModel(
          notificationId: const Uuid().v4(),
          companyId: empUser.companyId,
          title: 'Password Reset Request',
          body: 'Employee ${empUser.name} (${empUser.displayEmployeeId}) has requested a password reset.',
          notificationType: 'PASSWORD_RESET_REQUEST',
          isRead: false,
          createdAt: now,
          targetType: 'COMPANY',
          actorUserId: empUser.uid,
          actorName: empUser.name,
          relatedModule: 'PASSWORD_RESET',
          relatedEntityId: requestId,
        );
        await _ref.read(userRepositoryProvider).createNotification(notif);
      }

      // Log Audit Entry
      final auditLog = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: empUser.companyId,
        requestId: requestId,
        employeeId: empUser.displayEmployeeId,
        employeeName: empUser.name,
        action: 'REQUESTED',
        triggeredBy: 'Employee',
        triggeredByUid: empUser.uid,
        triggeredByName: empUser.name,
        timestamp: now,
        details: 'Password reset request created for employee ${empUser.name} (${empUser.displayEmployeeId}).',
      );
      await _repo.createAuditLog(auditLog);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  /// ---------------- 2. APPROVE PASSWORD RESET ----------------
  Future<String?> approveResetRequest(
    PasswordResetRequestModel request,
    UserModel reviewer,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(request.employeeUid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Employee profile record not found.');
      }

      final targetUser = UserModel.fromMap(userDoc.data()!);
      final targetEmail = targetUser.companyEmail ?? targetUser.hiddenEmail ?? targetUser.email;

      // Generate secure temporary password
      final tempPassword = _generateSecureTemporaryPassword();

      // Retrieve old password to update Firebase Auth if available
      final encryptedPass = targetUser.encryptedPassword ?? (targetUser.tempPassword != null ? PasswordEncryption.encrypt(targetUser.tempPassword!) : null);
      if (encryptedPass != null && encryptedPass.isNotEmpty) {
        try {
          final oldPassword = PasswordEncryption.decrypt(encryptedPass);
          final appName = 'ApproveReset_${DateTime.now().millisecondsSinceEpoch}';
          final tempApp = await Firebase.initializeApp(
            name: appName,
            options: Firebase.app().options,
          );
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          final credential = await tempAuth.signInWithEmailAndPassword(
            email: targetEmail,
            password: oldPassword,
          );
          await credential.user!.updatePassword(tempPassword);
          await tempApp.delete();
        } catch (authErr) {
          debugPrint('[PASSWORD_RESET] Warning: Direct Firebase Auth update exception: $authErr');
        }
      }

      final now = DateTime.now();

      // Update employee document in Firestore
      final updatedEmp = targetUser.copyWith(
        mustChangePassword: true,
        temporaryPasswordRequired: true,
        firstLogin: true,
        passwordChanged: false,
        tempPassword: null, // DO NOT store plaintext password
        encryptedPassword: PasswordEncryption.encrypt(tempPassword),
        updatedAt: now,
      );

      await _ref.read(userRepositoryProvider).saveUser(updatedEmp);

      // Update request status
      final updatedReq = request.copyWith(
        status: 'Approved',
        reviewedByUid: reviewer.uid,
        reviewedByName: reviewer.name,
        reviewedByRole: UserModel.denormalizeRole(reviewer.role),
        reviewedAt: now,
        tempPasswordGeneratedAt: now,
      );
      await _repo.updateRequest(updatedReq);

      // Create notification for employee
      final notif = AppNotificationModel(
        notificationId: const Uuid().v4(),
        companyId: request.companyId,
        title: 'Password Reset Approved',
        body: 'Your password reset request has been approved. Please contact your authorized administrator to receive your temporary login password.',
        notificationType: 'PASSWORD_RESET_APPROVED',
        isRead: false,
        createdAt: now,
        targetType: 'USER',
        targetUserId: request.employeeUid,
        actorUserId: reviewer.uid,
        actorName: reviewer.name,
        relatedModule: 'EMPLOYEE',
        relatedEntityId: request.requestId,
      );
      await _ref.read(userRepositoryProvider).createNotification(notif);

      // Create Audit Log
      final audit1 = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: request.companyId,
        requestId: request.requestId,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        action: 'APPROVED',
        triggeredBy: UserModel.denormalizeRole(reviewer.role),
        triggeredByUid: reviewer.uid,
        triggeredByName: reviewer.name,
        timestamp: now,
        details: 'Password reset request approved by ${reviewer.name} (${UserModel.denormalizeRole(reviewer.role)}).',
      );
      await _repo.createAuditLog(audit1);

      await AuditLogService.logEvent(
        companyId: request.companyId,
        employeeId: request.employeeId,
        userId: request.employeeUid,
        action: 'ADMIN_RESET_APPROVED',
        triggeredBy: 'Company Admin',
        details: {'approvedBy': reviewer.name},
      );

      await AuditLogService.logEvent(
        companyId: request.companyId,
        employeeId: request.employeeId,
        userId: request.employeeUid,
        action: 'TEMP_PASSWORD_ISSUED',
        triggeredBy: 'Company Admin',
      );

      await loadRequests();
      return tempPassword;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return null;
    }
  }

  /// ---------------- 2b. REGENERATE RECOVERY CODE ----------------
  Future<String?> regenerateRecoveryCode(
    PasswordResetRequestModel request,
    UserModel reviewer,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(request.employeeUid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Employee profile record not found.');
      }

      final targetUser = UserModel.fromMap(userDoc.data()!);
      final newCode = RecoveryCodeService.generateCode();
      final codeHash = RecoveryCodeService.hashRecoveryCode(newCode);
      final encryptedCode = RecoveryCodeService.encryptCode(newCode);
      final now = DateTime.now();

      final updatedUser = targetUser.copyWith(
        recoveryCodeHash: codeHash,
        encryptedRecoveryCode: encryptedCode,
        updatedAt: now,
      );

      await _ref.read(userRepositoryProvider).saveUser(updatedUser);

      // Update request status to Approved
      final updatedReq = request.copyWith(
        status: 'Approved',
        reviewedByUid: reviewer.uid,
        reviewedByName: reviewer.name,
        reviewedByRole: UserModel.denormalizeRole(reviewer.role),
        reviewedAt: now,
        updatedAt: now,
      );
      await _repo.updateRequest(updatedReq);

      // Create Audit Log
      final audit = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: request.companyId,
        requestId: request.requestId,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        action: 'APPROVED',
        triggeredBy: UserModel.denormalizeRole(reviewer.role),
        triggeredByUid: reviewer.uid,
        triggeredByName: reviewer.name,
        timestamp: now,
        details: 'Recovery Code regenerated by ${reviewer.name} for employee ${request.employeeName}.',
      );
      await _repo.createAuditLog(audit);

      await loadRequests();
      return newCode;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return null;
    }
  }

  /// ---------------- 3. REJECT PASSWORD RESET ----------------
  Future<bool> rejectResetRequest(
    PasswordResetRequestModel request,
    UserModel reviewer, {
    String? rejectionReason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final cleanReason = (rejectionReason ?? '').trim().isNotEmpty
        ? rejectionReason!.trim()
        : 'Please contact HR directly for identity verification.';

    try {
      final now = DateTime.now();
      final updatedReq = request.copyWith(
        status: 'Rejected',
        reviewedByUid: reviewer.uid,
        reviewedByName: reviewer.name,
        reviewedByRole: UserModel.denormalizeRole(reviewer.role),
        reviewedAt: now,
        rejectionReason: cleanReason,
      );
      await _repo.updateRequest(updatedReq);

      // Send in-app notification to employee
      final notif = AppNotificationModel(
        notificationId: const Uuid().v4(),
        companyId: request.companyId,
        title: 'Password Reset Request Rejected',
        body: 'Your password reset request was not approved. $cleanReason',
        notificationType: 'PASSWORD_RESET_REJECTED',
        isRead: false,
        createdAt: now,
        targetType: 'USER',
        targetUserId: request.employeeUid,
        actorUserId: reviewer.uid,
        actorName: reviewer.name,
        relatedModule: 'EMPLOYEE',
        relatedEntityId: request.requestId,
      );
      await _ref.read(userRepositoryProvider).createNotification(notif);

      // Create Audit Log
      final audit = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: request.companyId,
        requestId: request.requestId,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        action: 'REJECTED',
        triggeredBy: UserModel.denormalizeRole(reviewer.role),
        triggeredByUid: reviewer.uid,
        triggeredByName: reviewer.name,
        timestamp: now,
        details: 'Password reset request rejected by ${reviewer.name}. Reason: $cleanReason',
      );
      await _repo.createAuditLog(audit);

      await loadRequests();
      return true;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  /// ---------------- 3b. MARK REQUEST IN REVIEW ----------------
  Future<bool> markRequestInReview(
    PasswordResetRequestModel request,
    UserModel reviewer,
  ) async {
    try {
      if (request.status.toUpperCase() == 'IN REVIEW' || request.status.toUpperCase() == 'IN_REVIEW') {
        return true;
      }
      final now = DateTime.now();
      final updatedReq = request.copyWith(
        status: 'In Review',
        reviewedByUid: reviewer.uid,
        reviewedByName: reviewer.name,
        reviewedByRole: UserModel.denormalizeRole(reviewer.role),
        reviewedAt: now,
      );
      await _repo.updateRequest(updatedReq);

      final audit = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: request.companyId,
        requestId: request.requestId,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        action: 'IN_REVIEW',
        triggeredBy: UserModel.denormalizeRole(reviewer.role),
        triggeredByUid: reviewer.uid,
        triggeredByName: reviewer.name,
        timestamp: now,
        details: 'Password reset request marked as In Review by ${reviewer.name}.',
      );
      await _repo.createAuditLog(audit);
      await loadRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ---------------- 3c. MARK REQUEST CONTACTED ----------------
  Future<bool> markRequestContacted(
    PasswordResetRequestModel request,
    UserModel reviewer,
  ) async {
    try {
      final now = DateTime.now();
      final updatedReq = request.copyWith(
        status: 'Contacted',
        reviewedByUid: reviewer.uid,
        reviewedByName: reviewer.name,
        reviewedByRole: UserModel.denormalizeRole(reviewer.role),
        reviewedAt: now,
      );
      await _repo.updateRequest(updatedReq);

      final audit = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: request.companyId,
        requestId: request.requestId,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        action: 'CONTACTED',
        triggeredBy: UserModel.denormalizeRole(reviewer.role),
        triggeredByUid: reviewer.uid,
        triggeredByName: reviewer.name,
        timestamp: now,
        details: 'Employee contacted via phone/messaging by ${reviewer.name}.',
      );
      await _repo.createAuditLog(audit);
      await loadRequests();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// ---------------- 3d. MARK REQUEST RESOLVED ----------------
  Future<bool> resolveResetRequest(
    PasswordResetRequestModel request,
    UserModel reviewer,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final now = DateTime.now();
      final updatedReq = request.copyWith(
        status: 'RESOLVED',
        reviewedByUid: reviewer.uid,
        reviewedByName: reviewer.name,
        reviewedByRole: UserModel.denormalizeRole(reviewer.role),
        reviewedAt: now,
        completedAt: now,
        updatedAt: now,
      );
      await _repo.updateRequest(updatedReq);

      final audit = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: request.companyId,
        requestId: request.requestId,
        employeeId: request.employeeId,
        employeeName: request.employeeName,
        action: 'RESOLVED',
        triggeredBy: UserModel.denormalizeRole(reviewer.role),
        triggeredByUid: reviewer.uid,
        triggeredByName: reviewer.name,
        timestamp: now,
        details: 'Password reset request marked as RESOLVED by ${reviewer.name}.',
      );
      await _repo.createAuditLog(audit);
      await loadRequests();
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  /// ---------------- Helper: Lookup employee by ID ----------------
  Future<UserModel?> findUserByEmployeeId(String employeeId) async {
    final cleanEmpId = employeeId.trim();
    if (cleanEmpId.isEmpty) return null;
    try {
      final usersRef = FirebaseFirestore.instance.collection(FirestoreCollections.users);
      var query = await usersRef.where('employeeId', isEqualTo: cleanEmpId).limit(1).get();
      if (query.docs.isEmpty) {
        query = await usersRef.where('employeeId', isEqualTo: cleanEmpId.toUpperCase()).limit(1).get();
      }
      if (query.docs.isEmpty) {
        query = await usersRef.where('employeeId', isEqualTo: cleanEmpId.toLowerCase()).limit(1).get();
      }
      if (query.docs.isEmpty) return null;
      return UserModel.fromMap(query.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  /// ---------------- 4. COMPLETE FORCED PASSWORD CHANGE ----------------
  Future<bool> completePasswordChange({
    required UserModel employeeUser,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final fbUser = _ref.read(authRepositoryProvider).currentUser;
      if (fbUser != null) {
        await fbUser.updatePassword(newPassword);
      }

      final now = DateTime.now();
      final updatedUser = employeeUser.copyWith(
        mustChangePassword: false,
        temporaryPasswordRequired: false,
        firstLogin: false,
        passwordChanged: true,
        status: 'active',
        accountStatus: 'Active',
        tempPassword: null,
        encryptedPassword: PasswordEncryption.encrypt(newPassword),
        updatedAt: now,
      );

      await _ref.read(userRepositoryProvider).saveUser(updatedUser);
      _ref.read(authProvider.notifier).updateStateUser(updatedUser);

      // Mark any approved request for this employee as Completed
      final requestsSnap = await FirebaseFirestore.instance
          .collection('password_reset_requests')
          .where('companyId', isEqualTo: employeeUser.companyId)
          .where('employeeUid', isEqualTo: employeeUser.uid)
          .where('status', isEqualTo: 'Approved')
          .get();

      for (final doc in requestsSnap.docs) {
        final req = PasswordResetRequestModel.fromMap(doc.data());
        final completedReq = req.copyWith(
          status: 'Completed',
          completedAt: now,
        );
        await _repo.updateRequest(completedReq);
      }

      // Log Audit Entry
      final audit = PasswordResetAuditLogModel(
        logId: 'AUD-${const Uuid().v4()}',
        companyId: employeeUser.companyId,
        requestId: requestsSnap.docs.isNotEmpty ? requestsSnap.docs.first.id : 'N/A',
        employeeId: employeeUser.displayEmployeeId,
        employeeName: employeeUser.name,
        action: 'EMPLOYEE_CHANGED_PASSWORD',
        triggeredBy: 'Employee',
        triggeredByUid: employeeUser.uid,
        triggeredByName: employeeUser.name,
        timestamp: now,
        details: 'Employee ${employeeUser.name} (${employeeUser.displayEmployeeId}) completed forced password change.',
      );
      await _repo.createAuditLog(audit);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }

  /// ---------------- 5. COMPLETE FIRST-TIME ACCOUNT SETUP (Password + Security PIN) ----------------
  Future<bool> completeAccountSetup({
    required UserModel employeeUser,
    required String newPassword,
    required String securityPin,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final fbUser = _ref.read(authRepositoryProvider).currentUser;
      if (fbUser != null) {
        await fbUser.updatePassword(newPassword);
      }

      final now = DateTime.now();
      final pinHash = SecurityPinService.hashPin(securityPin);

      final updatedUser = employeeUser.copyWith(
        mustChangePassword: false,
        temporaryPasswordRequired: false,
        firstLogin: false,
        passwordChanged: true,
        securityPinConfigured: true,
        securityPinHash: pinHash,
        status: 'active',
        accountStatus: 'Active',
        tempPassword: null,
        encryptedPassword: PasswordEncryption.encrypt(newPassword),
        updatedAt: now,
      );

      await _ref.read(userRepositoryProvider).saveUser(updatedUser);
      _ref.read(authProvider.notifier).updateStateUser(updatedUser);

      // Audit logs
      await AuditLogService.logEvent(
        companyId: employeeUser.companyId,
        employeeId: employeeUser.displayEmployeeId,
        userId: employeeUser.uid,
        action: 'FIRST_TIME_PASSWORD_CHANGED',
        triggeredBy: 'Employee',
      );
      await AuditLogService.logEvent(
        companyId: employeeUser.companyId,
        employeeId: employeeUser.displayEmployeeId,
        userId: employeeUser.uid,
        action: 'SECURITY_PIN_CONFIGURED',
        triggeredBy: 'Employee',
      );
      await AuditLogService.logEvent(
        companyId: employeeUser.companyId,
        employeeId: employeeUser.displayEmployeeId,
        userId: employeeUser.uid,
        action: 'ACCOUNT_SETUP_COMPLETED',
        triggeredBy: 'Employee',
      );

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e, stack) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: AppErrorHandler.parseError(e, stack),
      );
      return false;
    }
  }
}

final passwordResetProvider = StateNotifierProvider<PasswordResetNotifier, PasswordResetState>((ref) {
  final repo = ref.watch(passwordResetRepositoryProvider);
  final notifier = PasswordResetNotifier(repo, ref);

  if (ref.read(authProvider).user != null) {
    notifier.loadRequests();
  }

  ref.listen(authProvider, (previous, next) {
    if (next.user != null) {
      notifier.loadRequests();
    }
  });

  return notifier;
});

final pendingPasswordResetRequestsProvider = Provider<AsyncValue<List<PasswordResetRequestModel>>>((ref) {
  final state = ref.watch(passwordResetProvider);
  if (state.isLoading) {
    return const AsyncValue.loading();
  }
  if (state.errorMessage != null) {
    return AsyncValue.error(state.errorMessage!, StackTrace.current);
  }
  final pending = state.requests.where((r) => r.status == 'Pending' && !r.isExpired).toList();
  return AsyncValue.data(pending);
});
