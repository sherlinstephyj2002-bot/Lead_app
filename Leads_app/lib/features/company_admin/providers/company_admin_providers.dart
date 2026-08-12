import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/user_roles.dart';
import '../../../constants/firestore_collections.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/utils/employee_id_generator.dart';
import '../../../shared/utils/app_validators.dart';
import '../../../shared/services/email_service.dart';
import '../../../shared/services/password_encryption.dart';
import '../../../shared/services/app_error_handler.dart';
import '../../../shared/models/department_model.dart';
import '../../../shared/models/leave_request_model.dart';
import '../../../shared/models/expense_model.dart';
import '../../../shared/models/attendance_model.dart';
import '../../../shared/models/employee_request_model.dart';
import '../../../shared/models/app_notification_model.dart';
import '../models/designation_model.dart';
import '../models/holiday_model.dart';
import '../models/shift_model.dart';
import '../models/attendance_settings_model.dart';
import '../models/overtime_settings_model.dart';
import '../models/leave_policy_model.dart';
import '../models/salary_component_model.dart';
import '../models/salary_component_audit_log_model.dart';
import '../models/branch_model.dart';
import '../../../shared/services/subscription_service.dart';
import '../models/pf_esi_tax_settings_model.dart';
import '../models/employee_document_model.dart';
import '../models/salary_structure_model.dart';
import '../models/payroll_settings_model.dart';
import '../models/salary_revision_model.dart';
import '../models/payroll_model.dart';
import '../repositories/company_admin_repository.dart';

final companyAdminRepositoryProvider = Provider<CompanyAdminRepository>((ref) {
  return CompanyAdminRepository(firestore: ref.watch(firestoreProvider));
});

// ==========================================
// HR MANAGEMENT NOTIFIER
// ==========================================
class HRUsersNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  HRUsersNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadHRUsers();
  }

  Future<void> loadHRUsers() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getCompanyUsersByRoles(user.companyId, [
        UserRoles.hrAdmin,
        UserRoles.hrExecutive,
        UserRoles.hr,
        UserRoles.recruiter,
        UserRoles.payrollExecutive,
        UserRoles.manager,
      ]);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  String _generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^*';
    final rand = Random.secure();
    return List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Map<String, String>> createUser({
    required String name,
    required String email,
    required String phoneNumber,
    required String role,
  }) async {
    throw Exception('HR Management does not create new employees. Please create employees in Employee Management.');
  }

  Future<void> assignHRRole(String uid, String newRole) async {
    final targetUser = await _repo.getUser(uid);
    if (targetUser == null) {
      throw Exception('Employee not found.');
    }
    final updatedUser = targetUser.copyWith(role: UserModel.normalizeRole(newRole), updatedAt: DateTime.now());
    await _repo.saveUser(updatedUser);
    await loadHRUsers();
    await _ref.read(adminEmployeesProvider.notifier).loadEmployees();

    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<void> removeHRRole(String uid) async {
    await assignHRRole(uid, UserRoles.employee);
  }

  Future<void> editUser(UserModel updatedUser) async {
    await _repo.saveUser(updatedUser);
    await loadHRUsers();

    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<void> toggleUserStatus(String uid, String currentStatus) async {
    final newStatus = currentStatus.toLowerCase() == 'active' ? 'suspended' : 'active';
    await _repo.updateUserStatus(uid, newStatus);
    await loadHRUsers();

    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<void> deleteUser(String uid) async {
    final targetUser = await _repo.getUser(uid);
    if (targetUser != null && targetUser.tempPassword != null && targetUser.tempPassword!.isNotEmpty) {
      final appName = 'DeleteApp_${DateTime.now().millisecondsSinceEpoch}';
      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: appName,
          options: Firebase.app().options,
        );

        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final credential = await tempAuth.signInWithEmailAndPassword(
          email: targetUser.email,
          password: targetUser.tempPassword!,
        );

        await credential.user?.delete();
      } catch (e) {
        debugPrint("Warning: Failed to delete user from Firebase Auth: $e");
      } finally {
        if (tempApp != null) {
          try {
            await tempApp.delete();
          } catch (_) {}
        }
      }
    }

    await _repo.deleteUser(uid);
    await loadHRUsers();

    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<Map<String, String>> resetPassword(String uid) async {
    final targetUser = await _repo.getUser(uid);
    if (targetUser == null) {
      throw Exception('User profile not found.');
    }
    
    final encryptedPass = targetUser.encryptedPassword ?? (targetUser.tempPassword != null ? PasswordEncryption.encrypt(targetUser.tempPassword!) : null);
    if (encryptedPass == null || encryptedPass.isEmpty) {
      throw Exception('Credentials not found on this profile. Cannot reset password.');
    }

    final oldPassword = PasswordEncryption.decrypt(encryptedPass);
    final newTempPassword = _generateSecurePassword();
    final appName = 'ResetPasswordApp_${DateTime.now().millisecondsSinceEpoch}';

    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // Authenticate with current temp password
      final credential = await tempAuth.signInWithEmailAndPassword(
        email: targetUser.email,
        password: oldPassword,
      );

      // Update password
      await credential.user!.updatePassword(newTempPassword);

      // Update Firestore document
      final updatedUser = targetUser.copyWith(
        tempPassword: newTempPassword,
        encryptedPassword: PasswordEncryption.encrypt(newTempPassword),
        mustChangePassword: true,
        firstLogin: true,
        passwordChanged: false,
        temporaryPasswordRequired: true,
      );
      await _repo.saveUser(updatedUser);
      await loadHRUsers();

      return {
        'email': targetUser.email,
        'tempPassword': newTempPassword,
      };
    } catch (e) {
      rethrow;
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
    }
  }
}

final hrUsersProvider = StateNotifierProvider<HRUsersNotifier, AsyncValue<List<UserModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return HRUsersNotifier(repo, ref);
});

// ==========================================
// EMPLOYEE MANAGEMENT NOTIFIER
// ==========================================
class AdminEmployeesNotifier extends StateNotifier<AsyncValue<List<UserModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminEmployeesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getCompanyEmployees(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }


  Future<Map<String, String>> createEmployee({
    required String name,
    required String personalEmail,
    required String phoneNumber,
    required String? departmentId,
    required String? department,
    required String? designationId,
    required String? designation,
    required String? managerId,
    required DateTime? joiningDate,
    required String? employmentType,
    String? profileImageUrl,
    String? shiftId,
    String? branchId,
    String? branchName,
    String? salaryStructureId,
    String? salaryStructureName,
  }) async {
    final adminUser = _ref.read(authProvider).user;
    if (adminUser == null) {
      throw Exception('Admin user session not found.');
    }

    // Backend Validations
    if (phoneNumber.isNotEmpty) {
      final phoneErr = AppValidators.validateMobileNumber(phoneNumber, isRequired: false);
      if (phoneErr != null) throw Exception(phoneErr);
    }

    final pEmailErr = AppValidators.validatePersonalEmail(personalEmail, isRequired: true);
    if (pEmailErr != null) throw Exception(pEmailErr);

    final trimmedPersonalEmail = personalEmail.trim().toLowerCase();
    if (trimmedPersonalEmail.isNotEmpty) {
      final dupPersonalSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .where('companyId', isEqualTo: adminUser.companyId)
          .where('personalEmail', isEqualTo: trimmedPersonalEmail)
          .limit(1)
          .get();
      if (dupPersonalSnap.docs.isNotEmpty) {
        throw Exception('This personal email is already registered.');
      }
    }

    // 1. Get or generate companyCode
    String companyCode = adminUser.companyCode ?? '';
    if (companyCode.isEmpty) {
      final companyDoc = await _ref.read(companyRepositoryProvider).getCompany(adminUser.companyId);
      if (companyDoc != null && companyDoc.companyCode != null && companyDoc.companyCode!.isNotEmpty) {
        companyCode = companyDoc.companyCode!;
      } else {
        // Generate a new company code
        final cleanName = adminUser.companyName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
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
          await _ref.read(companyRepositoryProvider).saveCompany(companyDoc.copyWith(companyCode: companyCode));
        }
      }
      // Update admin user model locally and in Firestore
      final updatedAdmin = adminUser.copyWith(companyCode: companyCode);
      await _ref.read(userRepositoryProvider).saveUser(updatedAdmin);
      _ref.read(authProvider.notifier).updateStateUser(updatedAdmin);
    }

    // 1.5. Check subscription employee limits
    final canAdd = await SubscriptionService.canAddOrActivateActiveEmployee(adminUser.companyId);
    if (!canAdd) {
      throw Exception('Free Plan employee limit reached. Upgrade your subscription to add more employees.');
    }

    // 2. Generate unique Employee ID & Company Email (e.g. SHER42 / sher42@jazzcreative.com)
    final companyObj = await _ref.read(companyRepositoryProvider).getCompany(adminUser.companyId);
    final activeCompanyName = companyObj?.name ?? adminUser.companyName;

    final empListSnap = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .where('companyId', isEqualTo: adminUser.companyId)
        .get();
    final existingEmployees = empListSnap.docs.map((doc) => UserModel.fromMap(doc.data())).toList();

    final generated = EmployeeIdGenerator.generateCredentials(
      employeeName: name,
      existingEmployees: existingEmployees,
      companyName: activeCompanyName,
      company: companyObj,
    );

    final finalEmployeeId = generated.employeeId;
    final companyEmail = generated.companyEmail;

    // 4. Generate temporary password (format Wt@ + 5 random digits)
    final rand = Random();
    final digits = List.generate(5, (_) => rand.nextInt(10).toString()).join();
    final tempPassword = 'Wt@$digits';

    final appName = 'EmpOnboarding_${DateTime.now().millisecondsSinceEpoch}';

    FirebaseApp? tempApp;
    UserCredential? credential;
    try {
      // Create a secondary Firebase App to prevent logging out the current admin
      tempApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // Create the user in Auth using companyEmail
      credential = await tempAuth.createUserWithEmailAndPassword(
        email: companyEmail,
        password: tempPassword,
      );

      final authUid = credential.user!.uid;

      // Create employee record in Firestore
      final newEmp = UserModel(
        uid: authUid,
        email: companyEmail,
        name: name,
        role: UserRoles.employee,
        companyId: adminUser.companyId,
        companyName: adminUser.companyName,
        phoneNumber: phoneNumber,
        createdAt: DateTime.now(),
        isEmailVerified: true,
        departmentId: departmentId,
        department: department,
        designationId: designationId,
        designation: designation,
        managerId: managerId,
        joiningDate: joiningDate,
        employmentType: employmentType,
        status: 'Pending Activation',
        mustChangePassword: true,
        tempPassword: tempPassword,
        encryptedPassword: PasswordEncryption.encrypt(tempPassword),
        profileImageUrl: profileImageUrl,
        shiftId: shiftId,
        branchId: branchId,
        branchName: branchName,
        salaryStructureId: salaryStructureId,
        salaryStructureName: salaryStructureName,
        employeeId: finalEmployeeId,
        companyCode: companyCode,
        employeeEmail: personalEmail.trim(),
        firstLogin: true,
        passwordChanged: false,
        personalEmail: personalEmail.trim(),
        companyEmail: companyEmail,
        tenantId: adminUser.companyId,
        temporaryPasswordRequired: true,
        accountStatus: 'Pending Activation',
      );

      await _repo.saveUser(newEmp);

      // Trigger simulated welcome email
      try {
        await _ref.read(emailServiceProvider).sendWelcomeEmail(
          recipientEmail: personalEmail.trim(),
          employeeName: name,
          companyName: adminUser.companyName,
          employeeId: finalEmployeeId,
          companyEmail: companyEmail,
          tempPassword: tempPassword,
        );
      } catch (e) {
        debugPrint('Failed to send welcome email: $e');
      }

      await loadEmployees();

      try {
        final notif = AppNotificationModel(
          notificationId: DateTime.now().millisecondsSinceEpoch.toString(),
          companyId: adminUser.companyId,
          title: 'New Employee Added',
          body: '$name has been onboarded to ${adminUser.companyName}.',
          notificationType: 'EMPLOYEE_CREATED',
          isRead: false,
          createdAt: DateTime.now(),
          targetType: 'ROLE',
          targetRole: UserRoles.companyAdmin,
          actorUserId: adminUser.uid,
          actorName: adminUser.name,
          relatedModule: 'EMPLOYEE',
          relatedEntityId: finalEmployeeId,
        );
        await _ref.read(userRepositoryProvider).createNotification(notif);
        _ref.read(notificationsProvider.notifier).loadNotifications();
      } catch (_) {}

      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();

      return {
        'employeeId': finalEmployeeId,
        'companyCode': companyCode,
        'companyEmail': companyEmail,
        'tempPassword': tempPassword,
      };
    } catch (e) {
      // Rollback Auth user if Firestore save fails
      if (credential != null && credential.user != null) {
        try {
          await credential.user!.delete();
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
  }

  Future<void> editEmployee(UserModel employee) async {
    // Backend Validation for editEmployee
    if (employee.phoneNumber != null && employee.phoneNumber!.isNotEmpty) {
      final phoneErr = AppValidators.validateMobileNumber(employee.phoneNumber, isRequired: false);
      if (phoneErr != null) throw Exception(phoneErr);
    }

    final pEmail = employee.personalEmail ?? employee.employeeEmail;
    if (pEmail != null && pEmail.isNotEmpty) {
      final pErr = AppValidators.validatePersonalEmail(pEmail, isRequired: false);
      if (pErr != null) throw Exception(pErr);
    }

    final updated = employee.copyWith(updatedAt: DateTime.now());
    await _repo.saveUser(updated);
    
    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await _repo.logEmployeeActivity(
        companyId: adminUser.companyId,
        employeeId: employee.uid,
        action: 'Profile details updated',
        performedBy: adminUser.name,
      );
    }
    await loadEmployees();

    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<void> toggleEmployeeStatus(String uid, String currentStatus) async {
    final newStatus = currentStatus.toLowerCase() == 'active' ? 'suspended' : 'active';
    final adminUser = _ref.read(authProvider).user;
    
    if (newStatus == 'active' && adminUser != null) {
      final canActivate = await SubscriptionService.canAddOrActivateActiveEmployee(adminUser.companyId);
      if (!canActivate) {
        throw Exception('Free Plan employee limit reached. Upgrade your subscription to activate another employee.');
      }
    }

    await _repo.updateUserStatus(uid, newStatus);
    
    if (adminUser != null) {
      await _repo.logEmployeeActivity(
        companyId: adminUser.companyId,
        employeeId: uid,
        action: 'Employee status changed to ${newStatus.toUpperCase()}',
        performedBy: adminUser.name,
      );
    }
    await loadEmployees();

    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<void> deleteEmployee(String uid) async {
    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await _repo.logEmployeeActivity(
        companyId: adminUser.companyId,
        employeeId: uid,
        action: 'Employee profile deleted',
        performedBy: adminUser.name,
      );
    }

    final targetUser = await _repo.getUser(uid);
    if (targetUser != null && targetUser.tempPassword != null && targetUser.tempPassword!.isNotEmpty) {
      final appName = 'EmpDelete_${DateTime.now().millisecondsSinceEpoch}';
      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: appName,
          options: Firebase.app().options,
        );

        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final credential = await tempAuth.signInWithEmailAndPassword(
          email: targetUser.hiddenEmail ?? targetUser.email,
          password: targetUser.tempPassword!,
        );

        await credential.user?.delete();
      } catch (e) {
        debugPrint("Warning: Failed to delete employee from Firebase Auth: $e");
      } finally {
        if (tempApp != null) {
          try {
            await tempApp.delete();
          } catch (_) {}
        }
      }
    }

    await _repo.deleteUser(uid);
    await loadEmployees();

    if (adminUser != null) {
      await SubscriptionService.recalculateAndSyncSubscription(adminUser.companyId);
      _ref.read(companyProvider.notifier).loadCompany();
    }
  }

  Future<Map<String, String>> createCredentialsForEmployee(UserModel employee) async {
    final adminUser = _ref.read(authProvider).user;
    if (adminUser == null) {
      throw Exception('Admin user session not found.');
    }

    String companyCode = adminUser.companyCode ?? '';
    if (companyCode.isEmpty) {
      companyCode = 'WT';
    }

    final empId = (employee.employeeId != null && employee.employeeId!.isNotEmpty)
        ? employee.employeeId!
        : '$companyCode-${employee.name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase().substring(0, employee.name.length >= 3 ? 3 : employee.name.length)}-${Random().nextInt(90) + 10}';

    final cleanCompName = adminUser.companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final companyEmail = (employee.companyEmail != null && employee.companyEmail!.isNotEmpty)
        ? employee.companyEmail!
        : (employee.email.contains('@') ? employee.email : '${empId.toLowerCase()}@$cleanCompName.worktrack');

    final rand = Random();
    final digits = List.generate(5, (_) => rand.nextInt(10).toString()).join();
    final tempPassword = 'Wt@$digits';

    final appName = 'EmpCreateAuth_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: companyEmail,
        password: tempPassword,
      );

      final authUid = credential.user!.uid;

      final updatedEmployee = employee.copyWith(
        uid: authUid,
        email: companyEmail,
        companyEmail: companyEmail,
        employeeId: empId,
        mustChangePassword: true,
        tempPassword: tempPassword,
        encryptedPassword: PasswordEncryption.encrypt(tempPassword),
        status: 'Active',
      );

      await _repo.saveUser(updatedEmployee);
      await loadEmployees();

      return {
        'companyEmail': companyEmail,
        'tempPassword': tempPassword,
        'employeeId': empId,
      };
    } catch (e) {
      rethrow;
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
    }
  }

  Future<Map<String, String>> resetPassword(String uid) async {
    final targetUser = await _repo.getUser(uid);
    if (targetUser == null) {
      throw Exception('User profile not found.');
    }
    
    final targetEmail = targetUser.companyEmail ?? targetUser.hiddenEmail ?? (targetUser.email.contains('@') ? targetUser.email : null);
    if (targetEmail == null || targetEmail.isEmpty) {
      throw Exception('NO_CREDENTIALS');
    }

    final newTempPassword = _generateSecurePassword();
    final encryptedPass = targetUser.encryptedPassword ?? (targetUser.tempPassword != null ? PasswordEncryption.encrypt(targetUser.tempPassword!) : null);

    if (encryptedPass != null && encryptedPass.isNotEmpty) {
      final oldPassword = PasswordEncryption.decrypt(encryptedPass);
      final appName = 'ResetPasswordApp_${DateTime.now().millisecondsSinceEpoch}';

      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
          name: appName,
          options: Firebase.app().options,
        );

        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

        final credential = await tempAuth.signInWithEmailAndPassword(
          email: targetEmail,
          password: oldPassword,
        );

        await credential.user!.updatePassword(newTempPassword);
      } catch (e) {
        debugPrint("Warning: Could not update Firebase Auth password directly: $e");
      } finally {
        if (tempApp != null) {
          try {
            await tempApp.delete();
          } catch (_) {}
        }
      }
    }

    final updatedUser = targetUser.copyWith(
      tempPassword: newTempPassword,
      encryptedPassword: PasswordEncryption.encrypt(newTempPassword),
      mustChangePassword: true,
      firstLogin: true,
      passwordChanged: false,
      temporaryPasswordRequired: true,
    );
    await _repo.saveUser(updatedUser);
    await loadEmployees();

    return {
      'email': targetEmail,
      'tempPassword': newTempPassword,
    };
  }

  Future<void> updateEmployeePassword(String uid, String newPassword) async {
    final targetUser = await _repo.getUser(uid);
    if (targetUser == null) {
      throw Exception('User profile not found.');
    }
    
    final encryptedPass = PasswordEncryption.encrypt(newPassword);
    
    final updated = targetUser.copyWith(
      encryptedPassword: encryptedPass,
      tempPassword: null,
      mustChangePassword: false,
      passwordChanged: true,
      updatedAt: DateTime.now(),
    );

    await _repo.saveUser(updated);

    final targetEmail = targetUser.companyEmail ?? targetUser.hiddenEmail ?? (targetUser.email.contains('@') ? targetUser.email : null);
    if (targetEmail != null && targetEmail.isNotEmpty) {
      final oldEncrypted = targetUser.encryptedPassword;
      if (oldEncrypted != null && oldEncrypted.isNotEmpty) {
        try {
          final oldPassword = PasswordEncryption.decrypt(oldEncrypted);
          final appName = 'ResetPasswordApp_${DateTime.now().millisecondsSinceEpoch}';
          final tempApp = await Firebase.initializeApp(
            name: appName,
            options: Firebase.app().options,
          );
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          final credential = await tempAuth.signInWithEmailAndPassword(
            email: targetEmail,
            password: oldPassword,
          );
          await credential.user!.updatePassword(newPassword);
          await tempApp.delete();
        } catch (e) {
          debugPrint("Warning: Could not update Firebase Auth password directly: $e");
        }
      }
    }

    await loadEmployees();
  }

  String _generateSecurePassword() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> transferEmployee(String uid, String departmentId, String departmentName) async {
    final employee = state.value?.firstWhere((u) => u.uid == uid);
    if (employee != null) {
      final updated = employee.copyWith(
        departmentId: departmentId,
        department: departmentName,
        updatedAt: DateTime.now(),
      );
      await _repo.saveUser(updated);

      final adminUser = _ref.read(authProvider).user;
      if (adminUser != null) {
        await _repo.logEmployeeActivity(
          companyId: adminUser.companyId,
          employeeId: uid,
          action: 'Transferred department to $departmentName',
          performedBy: adminUser.name,
        );
      }

      await loadEmployees();
    }
  }

  Future<void> transferManager(String uid, String? managerId) async {
    final employee = state.value?.firstWhere((u) => u.uid == uid);
    if (employee != null) {
      final updated = employee.copyWith(
        managerId: managerId,
        updatedAt: DateTime.now(),
      );
      await _repo.saveUser(updated);

      final adminUser = _ref.read(authProvider).user;
      if (adminUser != null) {
        await _repo.logEmployeeActivity(
          companyId: adminUser.companyId,
          employeeId: uid,
          action: managerId != null ? 'Reporting manager updated' : 'Unassigned reporting manager',
          performedBy: adminUser.name,
        );
      }

      await loadEmployees();
    }
  }

  Future<void> assignSalaryStructure(String uid, String? structureId, String? structureName) async {
    await _repo.assignSalaryStructure(uid, structureId, structureName);

    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await _repo.logEmployeeActivity(
        companyId: adminUser.companyId,
        employeeId: uid,
        action: structureId != null ? 'Salary structure assigned: $structureName' : 'Unassigned salary structure',
        performedBy: adminUser.name,
      );
    }
    await loadEmployees();
  }

  Future<void> assignShift(String uid, String? shiftId) async {
    await _repo.assignShiftToEmployee(uid, shiftId);

    final adminUser = _ref.read(authProvider).user;
    if (adminUser != null) {
      await _repo.logEmployeeActivity(
        companyId: adminUser.companyId,
        employeeId: uid,
        action: shiftId != null ? 'Work shift updated' : 'Unassigned work shift',
        performedBy: adminUser.name,
      );
      
      // Also update the local cached user's updatedAt field
      final employee = state.value?.firstWhere((u) => u.uid == uid);
      if (employee != null) {
        final updated = employee.copyWith(updatedAt: DateTime.now());
        await _repo.saveUser(updated);
      }
    }

    await loadEmployees();
  }
}

final adminEmployeesProvider = StateNotifierProvider<AdminEmployeesNotifier, AsyncValue<List<UserModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminEmployeesNotifier(repo, ref);
});

// ==========================================
// DEPARTMENT MANAGEMENT NOTIFIER
// ==========================================
class AdminDepartmentsNotifier extends StateNotifier<AsyncValue<List<DepartmentModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminDepartmentsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadDepartments();
  }

  Future<void> loadDepartments() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getDepartments(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<bool> saveDepartment(DepartmentModel department) async {
    final isDuplicate = await _repo.isDepartmentNameDuplicate(
      department.companyId,
      department.departmentName,
      excludeId: department.departmentId.isNotEmpty ? department.departmentId : null,
    );

    if (isDuplicate) return false;

    await _repo.saveDepartment(department);
    await loadDepartments();
    return true;
  }

  Future<void> deleteDepartment(String departmentId) async {
    await _repo.deleteDepartment(departmentId);
    await loadDepartments();
  }

  Future<void> restoreDepartment(String departmentId) async {
    await _repo.restoreDepartment(departmentId);
    await loadDepartments();
  }

  Future<void> permanentlyDeleteDepartment(String departmentId) async {
    await _repo.permanentlyDeleteDepartment(departmentId);
    await loadDepartments();
  }
}

final adminDepartmentsProvider = StateNotifierProvider<AdminDepartmentsNotifier, AsyncValue<List<DepartmentModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminDepartmentsNotifier(repo, ref);
});

// ==========================================
// DESIGNATION MANAGEMENT NOTIFIER
// ==========================================
class AdminDesignationsNotifier extends StateNotifier<AsyncValue<List<DesignationModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminDesignationsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadDesignations();
  }

  Future<void> loadDesignations() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getDesignations(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<bool> saveDesignation(DesignationModel designation) async {
    final isDuplicate = await _repo.isDesignationNameDuplicate(
      designation.companyId,
      designation.designationName,
      excludeId: designation.designationId.isNotEmpty ? designation.designationId : null,
    );

    if (isDuplicate) return false;

    await _repo.saveDesignation(designation);
    await loadDesignations();
    return true;
  }

  Future<void> deleteDesignation(String designationId) async {
    await _repo.deleteDesignation(designationId);
    await loadDesignations();
  }

  Future<void> restoreDesignation(String designationId) async {
    await _repo.restoreDesignation(designationId);
    await loadDesignations();
  }

  Future<void> permanentlyDeleteDesignation(String designationId) async {
    await _repo.permanentlyDeleteDesignation(designationId);
    await loadDesignations();
  }
}

final adminDesignationsProvider = StateNotifierProvider<AdminDesignationsNotifier, AsyncValue<List<DesignationModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminDesignationsNotifier(repo, ref);
});

// ==========================================
// HOLIDAY MANAGEMENT NOTIFIER
// ==========================================
class AdminHolidaysNotifier extends StateNotifier<AsyncValue<List<HolidayModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminHolidaysNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadHolidays();
  }

  Future<void> loadHolidays() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getHolidays(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveHoliday(HolidayModel holiday) async {
    final user = _ref.read(authProvider).user;
    var targetHoliday = holiday;
    if (targetHoliday.companyId.isEmpty && user != null) {
      targetHoliday = HolidayModel(
        holidayId: targetHoliday.holidayId,
        companyId: user.companyId,
        branchId: targetHoliday.branchId,
        holidayName: targetHoliday.holidayName,
        holidayDate: targetHoliday.holidayDate,
        holidayType: targetHoliday.holidayType,
        description: targetHoliday.description,
        isRecurring: targetHoliday.isRecurring,
        status: targetHoliday.status,
        createdAt: targetHoliday.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    await _repo.saveHoliday(targetHoliday);
    await loadHolidays();
  }

  Future<void> deleteHoliday(String holidayId) async {
    await _repo.deleteHoliday(holidayId);
    await loadHolidays();
  }

  Future<void> restoreHoliday(String holidayId) async {
    await _repo.restoreHoliday(holidayId);
    await loadHolidays();
  }
}

final adminHolidaysProvider = StateNotifierProvider<AdminHolidaysNotifier, AsyncValue<List<HolidayModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminHolidaysNotifier(repo, ref);
});

// ==========================================
// WORK SHIFT NOTIFIER
// ==========================================
class AdminShiftsNotifier extends StateNotifier<AsyncValue<List<ShiftModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminShiftsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadShifts();
  }

  Future<void> loadShifts() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getShifts(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<String> saveShift(ShiftModel shift) async {
    final isNameDuplicate = await _repo.isShiftNameDuplicate(
      shift.companyId,
      shift.shiftName,
      excludeId: shift.shiftId.isNotEmpty ? shift.shiftId : null,
    );
    if (isNameDuplicate) return 'Shift name already exists.';

    final isCodeDuplicate = await _repo.isShiftCodeDuplicate(
      shift.companyId,
      shift.shiftCode,
      excludeId: shift.shiftId.isNotEmpty ? shift.shiftId : null,
    );
    if (isCodeDuplicate) return 'Shift code already exists.';

    await _repo.saveShift(shift);
    await loadShifts();
    return 'success';
  }

  Future<void> deleteShift(String shiftId) async {
    await _repo.deleteShift(shiftId);
    await loadShifts();
  }

  Future<void> restoreShift(String shiftId) async {
    await _repo.restoreShift(shiftId);
    await loadShifts();
  }
}

final adminShiftsProvider = StateNotifierProvider<AdminShiftsNotifier, AsyncValue<List<ShiftModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminShiftsNotifier(repo, ref);
});

// ==========================================
// ATTENDANCE SETTINGS NOTIFIER
// ==========================================
class AdminAttendanceSettingsNotifier extends StateNotifier<AsyncValue<AttendanceSettingsModel>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminAttendanceSettingsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final settings = await _repo.getAttendanceSettings(user.companyId);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveSettings(AttendanceSettingsModel settings) async {
    state = const AsyncValue.loading();
    try {
      await _repo.saveAttendanceSettings(settings);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final adminAttendanceSettingsProvider = StateNotifierProvider<AdminAttendanceSettingsNotifier, AsyncValue<AttendanceSettingsModel>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminAttendanceSettingsNotifier(repo, ref);
});

// ==========================================
// OVERTIME SETTINGS NOTIFIER
// ==========================================
class AdminOvertimeSettingsNotifier extends StateNotifier<AsyncValue<OvertimeSettingsModel>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminOvertimeSettingsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final settings = await _repo.getOvertimeSettings(user.companyId);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveSettings(OvertimeSettingsModel settings) async {
    state = const AsyncValue.loading();
    try {
      await _repo.saveOvertimeSettings(settings);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final adminOvertimeSettingsProvider = StateNotifierProvider<AdminOvertimeSettingsNotifier, AsyncValue<OvertimeSettingsModel>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminOvertimeSettingsNotifier(repo, ref);
});

// ==========================================
// LEAVE POLICY NOTIFIER
// ==========================================
class AdminLeavePolicyNotifier extends StateNotifier<AsyncValue<LeavePolicyModel>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminLeavePolicyNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadPolicy();
  }

  Future<void> loadPolicy() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final policy = await _repo.getLeavePolicy(user.companyId);
      state = AsyncValue.data(policy);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> savePolicy(LeavePolicyModel policy) async {
    state = const AsyncValue.loading();
    try {
      await _repo.saveLeavePolicy(policy);
      state = AsyncValue.data(policy);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final adminLeavePolicyProvider = StateNotifierProvider<AdminLeavePolicyNotifier, AsyncValue<LeavePolicyModel>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminLeavePolicyNotifier(repo, ref);
});

// ==========================================
// SALARY COMPONENTS NOTIFIER
// ==========================================
class AdminSalaryComponentsNotifier
    extends StateNotifier<AsyncValue<List<SalaryComponentModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminSalaryComponentsNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    loadComponents();
  }

  Future<void> loadComponents() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getSalaryComponents(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveComponent(SalaryComponentModel component) async {
    final user = _ref.read(authProvider).user;
    final isNew = state.value?.any((c) => c.componentId == component.componentId) == false;

    await _repo.saveSalaryComponent(component);

    if (user != null) {
      await _repo.logSalaryComponentActivity(
        companyId: user.companyId,
        componentId: component.componentId,
        componentName: component.componentName,
        action: isNew ? 'Create' : 'Edit',
        performedBy: user.name,
        details: isNew
            ? 'Component "${component.componentName}" created (${component.componentType}, ${component.calculationType}, value: ${component.defaultValue})'
            : 'Component "${component.componentName}" updated (${component.componentType}, ${component.calculationType}, value: ${component.defaultValue})',
      );
    }

    await loadComponents();
    // Refresh audit logs
    _ref.read(adminSalaryAuditLogsProvider.notifier).loadLogs();
  }

  Future<void> archiveComponent(String componentId, String componentName) async {
    final user = _ref.read(authProvider).user;

    await _repo.archiveSalaryComponent(componentId);

    if (user != null) {
      await _repo.logSalaryComponentActivity(
        companyId: user.companyId,
        componentId: componentId,
        componentName: componentName,
        action: 'Archive',
        performedBy: user.name,
        details: 'Component "$componentName" archived (soft deleted)',
      );
    }

    await loadComponents();
    _ref.read(adminSalaryAuditLogsProvider.notifier).loadLogs();
  }

  Future<void> restoreComponent(String componentId, String componentName) async {
    final user = _ref.read(authProvider).user;

    await _repo.restoreSalaryComponent(componentId);

    if (user != null) {
      await _repo.logSalaryComponentActivity(
        companyId: user.companyId,
        componentId: componentId,
        componentName: componentName,
        action: 'Restore',
        performedBy: user.name,
        details: 'Component "$componentName" restored to active status',
      );
    }

    await loadComponents();
    _ref.read(adminSalaryAuditLogsProvider.notifier).loadLogs();
  }

  Future<void> deleteComponent(String componentId) async {
    await _repo.deleteSalaryComponent(componentId);
    await loadComponents();
  }
}

final adminSalaryComponentsProvider = StateNotifierProvider<
    AdminSalaryComponentsNotifier,
    AsyncValue<List<SalaryComponentModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminSalaryComponentsNotifier(repo, ref);
});

// ==========================================
// SALARY COMPONENT AUDIT LOGS NOTIFIER
// ==========================================
class AdminSalaryAuditLogsNotifier
    extends StateNotifier<AsyncValue<List<SalaryComponentAuditLogModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminSalaryAuditLogsNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    loadLogs();
  }

  Future<void> loadLogs() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getSalaryComponentAuditLogs(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final adminSalaryAuditLogsProvider = StateNotifierProvider<
    AdminSalaryAuditLogsNotifier,
    AsyncValue<List<SalaryComponentAuditLogModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminSalaryAuditLogsNotifier(repo, ref);
});


// ==========================================
// SALARY STRUCTURES NOTIFIER
// ==========================================
class AdminSalaryStructuresNotifier extends StateNotifier<AsyncValue<List<SalaryStructureModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminSalaryStructuresNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadStructures();
  }

  Future<void> loadStructures() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getSalaryStructures(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveStructure(SalaryStructureModel structure) async {
    await _repo.saveSalaryStructure(structure);
    
    // Log Activity
    final user = _ref.read(authProvider).user;
    if (user != null) {
      await _repo.logEmployeeActivity(
        companyId: user.companyId,
        employeeId: user.uid,
        action: 'Salary Structure template saved: ${structure.name}',
        performedBy: user.name,
      );
    }
    await loadStructures();
  }

  Future<void> deleteStructure(String structureId) async {
    await _repo.softDeleteSalaryStructure(structureId);
    
    // Log Activity
    final user = _ref.read(authProvider).user;
    if (user != null) {
      await _repo.logEmployeeActivity(
        companyId: user.companyId,
        employeeId: user.uid,
        action: 'Salary Structure template archived: ID $structureId',
        performedBy: user.name,
      );
    }
    await loadStructures();
  }
}

final adminSalaryStructuresProvider = StateNotifierProvider<AdminSalaryStructuresNotifier, AsyncValue<List<SalaryStructureModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminSalaryStructuresNotifier(repo, ref);
});

// ==========================================
// STATUTORY COMPLIANCE SETTINGS NOTIFIER
// ==========================================
class AdminComplianceSettingsNotifier extends StateNotifier<AsyncValue<PfEsiTaxSettingsModel>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminComplianceSettingsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final settings = await _repo.getPfEsiTaxSettings(user.companyId);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveSettings(PfEsiTaxSettingsModel settings) async {
    state = const AsyncValue.loading();
    try {
      await _repo.savePfEsiTaxSettings(settings);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final adminComplianceSettingsProvider = StateNotifierProvider<AdminComplianceSettingsNotifier, AsyncValue<PfEsiTaxSettingsModel>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminComplianceSettingsNotifier(repo, ref);
});

// ==========================================
// PAYROLL SETTINGS NOTIFIER
// ==========================================
class AdminPayrollSettingsNotifier extends StateNotifier<AsyncValue<PayrollSettingsModel>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminPayrollSettingsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final settings = await _repo.getPayrollSettings(user.companyId);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveSettings(PayrollSettingsModel settings) async {
    state = const AsyncValue.loading();
    try {
      await _repo.savePayrollSettings(settings);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final adminPayrollSettingsProvider = StateNotifierProvider<AdminPayrollSettingsNotifier, AsyncValue<PayrollSettingsModel>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminPayrollSettingsNotifier(repo, ref);
});

// ==========================================
// OVERRIDE REQUESTS NOTIFIER
// ==========================================
class OverrideRequestsState {
  final List<LeaveRequestModel> pendingLeaves;
  final List<ExpenseModel> pendingExpenses;
  final List<AttendanceModel> pendingCorrections;
  final List<EmployeeRequestModel> pendingEmployeeRequests;
  final bool isLoading;
  final String? errorMessage;

  OverrideRequestsState({
    this.pendingLeaves = const [],
    this.pendingExpenses = const [],
    this.pendingCorrections = const [],
    this.pendingEmployeeRequests = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  OverrideRequestsState copyWith({
    List<LeaveRequestModel>? pendingLeaves,
    List<ExpenseModel>? pendingExpenses,
    List<AttendanceModel>? pendingCorrections,
    List<EmployeeRequestModel>? pendingEmployeeRequests,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OverrideRequestsState(
      pendingLeaves: pendingLeaves ?? this.pendingLeaves,
      pendingExpenses: pendingExpenses ?? this.pendingExpenses,
      pendingCorrections: pendingCorrections ?? this.pendingCorrections,
      pendingEmployeeRequests: pendingEmployeeRequests ?? this.pendingEmployeeRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  void clearErrorMessage() {}
}

class OverrideRequestsNotifier extends StateNotifier<OverrideRequestsState> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  OverrideRequestsNotifier(this._repo, this._ref) : super(OverrideRequestsState()) {
    loadAllRequests();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> loadAllRequests() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final leaves = await _repo.getPendingLeaves(user.companyId);
      final expenses = await _repo.getPendingExpenses(user.companyId);
      final corrections = await _repo.getPendingAttendanceCorrections(user.companyId);
      final reqs = await _repo.getPendingEmployeeRequests(user.companyId);

      state = OverrideRequestsState(
        pendingLeaves: leaves,
        pendingExpenses: expenses,
        pendingCorrections: corrections,
        pendingEmployeeRequests: reqs,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[OVERRIDE] loadAllRequests error: $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to load requests: ${e.toString()}');
    }
  }

  Future<void> approveLeave(String leaveId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      debugPrint('[OVERRIDE] approveLeave: user is null');
      return;
    }
    try {
      debugPrint('[OVERRIDE] approveLeave: leaveId=$leaveId approvedBy=${user.uid}');
      // Call repo directly to avoid leaveRequestsProvider lifecycle issues
      await _repo.approveLeave(leaveId, user.uid, user.name);
      debugPrint('[OVERRIDE] approveLeave: SUCCESS');
      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[OVERRIDE] approveLeave ERROR: $e');
      state = state.copyWith(errorMessage: 'Failed to approve leave: ${e.toString()}');
    }
    await loadAllRequests();
  }

  Future<void> rejectLeave(String leaveId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      debugPrint('[OVERRIDE] rejectLeave: user is null');
      return;
    }
    try {
      debugPrint('[OVERRIDE] rejectLeave: leaveId=$leaveId rejectedBy=${user.uid}');
      await _repo.rejectLeave(leaveId, user.uid, user.name);
      debugPrint('[OVERRIDE] rejectLeave: SUCCESS');
      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[OVERRIDE] rejectLeave ERROR: $e');
      state = state.copyWith(errorMessage: 'Failed to reject leave: ${e.toString()}');
    }
    await loadAllRequests();
  }

  Future<void> approveExpense(String expenseId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      debugPrint('[OVERRIDE] approveExpense: user is null');
      return;
    }
    try {
      debugPrint('[OVERRIDE] approveExpense: expenseId=$expenseId approvedBy=${user.uid}');
      await _repo.approveExpense(expenseId, user.uid, user.name);
      debugPrint('[OVERRIDE] approveExpense: SUCCESS');
      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[OVERRIDE] approveExpense ERROR: $e');
      state = state.copyWith(errorMessage: 'Failed to approve expense: ${e.toString()}');
    }
    await loadAllRequests();
  }

  Future<void> rejectExpense(String expenseId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      debugPrint('[OVERRIDE] rejectExpense: user is null');
      return;
    }
    try {
      debugPrint('[OVERRIDE] rejectExpense: expenseId=$expenseId rejectedBy=${user.uid}');
      await _repo.rejectExpense(expenseId, user.uid, user.name);
      debugPrint('[OVERRIDE] rejectExpense: SUCCESS');
      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[OVERRIDE] rejectExpense ERROR: $e');
      state = state.copyWith(errorMessage: 'Failed to reject expense: ${e.toString()}');
    }
    await loadAllRequests();
  }

  Future<void> resolveAttendanceCorrection(String attendanceId, String status) async {
    final user = _ref.read(authProvider).user;
    try {
      debugPrint('[OVERRIDE] resolveAttendanceCorrection: attendanceId=$attendanceId status=$status');
      await _repo.updateAttendanceCorrection(attendanceId, status);
      debugPrint('[OVERRIDE] resolveAttendanceCorrection: SUCCESS');
      if (user != null) {
        await _repo.logEmployeeActivity(
          companyId: user.companyId,
          employeeId: user.uid,
          action: 'Attendance Correction resolved to status $status for log $attendanceId',
          performedBy: user.name,
        );
      }
      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[OVERRIDE] resolveAttendanceCorrection ERROR: $e');
      state = state.copyWith(errorMessage: 'Failed to resolve attendance correction: ${e.toString()}');
    }
    await loadAllRequests();
  }

  Future<void> resolveEmployeeRequest(EmployeeRequestModel request, bool approve) async {
    final user = _ref.read(authProvider).user;
    if (user == null) {
      debugPrint('[OVERRIDE] resolveEmployeeRequest: user is null');
      return;
    }
    try {
      debugPrint('[OVERRIDE] resolveEmployeeRequest: requestId=${request.requestId} approve=$approve');
      if (approve) {
        await _ref.read(employeeRequestsProvider.notifier).approveRequest(request);
      } else {
        await _ref.read(employeeRequestsProvider.notifier).rejectRequest(request);
      }
      debugPrint('[OVERRIDE] resolveEmployeeRequest: SUCCESS');
      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[OVERRIDE] resolveEmployeeRequest ERROR: $e');
      state = state.copyWith(errorMessage: 'Failed to process request: ${e.toString()}');
    }
    await loadAllRequests();
  }
}

final overrideRequestsProvider = StateNotifierProvider<OverrideRequestsNotifier, OverrideRequestsState>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return OverrideRequestsNotifier(repo, ref);
});

// ==========================================
// BRANCH MANAGEMENT NOTIFIER
// ==========================================
class AdminBranchesNotifier extends StateNotifier<AsyncValue<List<BranchModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminBranchesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadBranches();
  }

  Future<void> loadBranches() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repo.getBranches(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<String?> saveBranch(BranchModel branch) async {
    // 1. Validation for unique branchName
    final isNameDup = await _repo.isBranchNameDuplicate(
      branch.companyId,
      branch.branchName,
      excludeId: branch.branchId.isNotEmpty ? branch.branchId : null,
    );
    if (isNameDup) return 'Branch name must be unique within the same company.';

    // 2. Validation for unique branchCode
    final isCodeDup = await _repo.isBranchCodeDuplicate(
      branch.companyId,
      branch.branchCode,
      excludeId: branch.branchId.isNotEmpty ? branch.branchId : null,
    );
    if (isCodeDup) return 'Branch code must be unique within the same company.';

    await _repo.saveBranch(branch);
    await loadBranches();
    return null;
  }

  Future<void> archiveBranch(String branchId) async {
    await _repo.archiveBranch(branchId);
    await loadBranches();
  }

  Future<void> restoreBranch(String branchId) async {
    await _repo.restoreBranch(branchId);
    await loadBranches();
  }
}

final adminBranchesProvider = StateNotifierProvider<AdminBranchesNotifier, AsyncValue<List<BranchModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminBranchesNotifier(repo, ref);
});

// ==========================================
// EMPLOYEE DOCUMENT MANAGEMENT NOTIFIER
// ==========================================
class AdminEmployeeDocumentsNotifier extends StateNotifier<AsyncValue<List<EmployeeDocumentModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;
  final String _employeeId;

  AdminEmployeeDocumentsNotifier(this._repo, this._ref, this._employeeId) : super(const AsyncValue.loading()) {
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getEmployeeDocuments(user.companyId, _employeeId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> saveDocument(EmployeeDocumentModel doc) async {
    await _repo.saveEmployeeDocument(doc);
    await loadDocuments();
    _ref.read(allCompanyDocumentsProvider.notifier).loadAllDocuments();
  }

  Future<void> approveDocument(String documentId) async {
    final user = _ref.read(authProvider).user;
    await _repo.updateDocumentVerification(
      documentId: documentId,
      verificationStatus: 'verified',
      verifiedBy: user?.uid,
      verifiedByName: user?.name ?? 'Admin',
    );
    await loadDocuments();
    _ref.read(allCompanyDocumentsProvider.notifier).loadAllDocuments();
  }

  Future<void> rejectDocument(String documentId, String reason) async {
    final user = _ref.read(authProvider).user;
    await _repo.updateDocumentVerification(
      documentId: documentId,
      verificationStatus: 'rejected',
      rejectionReason: reason,
      rejectedBy: user?.uid,
      rejectedByName: user?.name ?? 'Admin',
    );
    await loadDocuments();
    _ref.read(allCompanyDocumentsProvider.notifier).loadAllDocuments();
  }

  Future<void> archiveDocument(String documentId) async {
    await _repo.archiveEmployeeDocument(documentId);
    await loadDocuments();
    _ref.read(allCompanyDocumentsProvider.notifier).loadAllDocuments();
  }

  Future<void> restoreDocument(String documentId) async {
    await _repo.restoreEmployeeDocument(documentId);
    await loadDocuments();
    _ref.read(allCompanyDocumentsProvider.notifier).loadAllDocuments();
  }

  Future<void> deleteDocument(String documentId) async {
    await _repo.deleteEmployeeDocument(documentId);
    await loadDocuments();
    _ref.read(allCompanyDocumentsProvider.notifier).loadAllDocuments();
  }
}

final adminEmployeeDocumentsProvider = StateNotifierProvider.family.autoDispose<
    AdminEmployeeDocumentsNotifier,
    AsyncValue<List<EmployeeDocumentModel>>,
    String>((ref, employeeId) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminEmployeeDocumentsNotifier(repo, ref, employeeId);
});

class AllCompanyDocumentsNotifier extends StateNotifier<AsyncValue<List<EmployeeDocumentModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AllCompanyDocumentsNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadAllDocuments();
  }

  Future<void> loadAllDocuments() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getCompanyAllEmployeeDocuments(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> approveDocument(String documentId, String employeeId) async {
    final user = _ref.read(authProvider).user;
    await _repo.updateDocumentVerification(
      documentId: documentId,
      verificationStatus: 'verified',
      verifiedBy: user?.uid,
      verifiedByName: user?.name ?? 'Admin',
    );
    await loadAllDocuments();
    _ref.read(adminEmployeeDocumentsProvider(employeeId).notifier).loadDocuments();
  }

  Future<void> rejectDocument(String documentId, String employeeId, String reason) async {
    final user = _ref.read(authProvider).user;
    await _repo.updateDocumentVerification(
      documentId: documentId,
      verificationStatus: 'rejected',
      rejectionReason: reason,
      rejectedBy: user?.uid,
      rejectedByName: user?.name ?? 'Admin',
    );
    await loadAllDocuments();
    _ref.read(adminEmployeeDocumentsProvider(employeeId).notifier).loadDocuments();
  }
}

final allCompanyDocumentsProvider = StateNotifierProvider.autoDispose<
    AllCompanyDocumentsNotifier,
    AsyncValue<List<EmployeeDocumentModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AllCompanyDocumentsNotifier(repo, ref);
});

// ==========================================
// SALARY REVISION HISTORY NOTIFIER (per employee)
// ==========================================
class SalaryRevisionsNotifier
    extends StateNotifier<AsyncValue<List<SalaryRevisionModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;
  final String _employeeId;

  SalaryRevisionsNotifier(this._repo, this._ref, this._employeeId)
      : super(const AsyncValue.loading()) {
    loadRevisions();
  }

  Future<void> loadRevisions() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list =
          await _repo.getEmployeeSalaryRevisions(user.companyId, _employeeId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> addRevision(SalaryRevisionModel revision) async {
    await _repo.saveSalaryRevision(revision);
    await loadRevisions();
  }
}

final salaryRevisionsProvider = StateNotifierProvider.family.autoDispose<
    SalaryRevisionsNotifier,
    AsyncValue<List<SalaryRevisionModel>>,
    String>((ref, employeeId) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return SalaryRevisionsNotifier(repo, ref, employeeId);
});

// ==========================================
// COMPANY-WIDE SALARY REVISIONS NOTIFIER
// ==========================================
class AdminAllRevisionsNotifier
    extends StateNotifier<AsyncValue<List<SalaryRevisionModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  AdminAllRevisionsNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    loadAllRevisions();
  }

  Future<void> loadAllRevisions() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list = await _repo.getCompanySalaryRevisions(user.companyId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }

  Future<void> addRevision(SalaryRevisionModel revision) async {
    await _repo.saveSalaryRevision(revision);
    await loadAllRevisions();
  }
}

final adminAllRevisionsProvider = StateNotifierProvider<AdminAllRevisionsNotifier,
    AsyncValue<List<SalaryRevisionModel>>>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return AdminAllRevisionsNotifier(repo, ref);
});

// ==========================================
// MODULE 16 - PAYROLL PROCESSING NOTIFIER
// ==========================================
class PayrollState {
  final List<PayrollModel> payrolls;
  final bool isLoading;
  final bool isGenerating;
  final String? error;
  final int selectedMonth;
  final int selectedYear;

  PayrollState({
    this.payrolls = const [],
    this.isLoading = false,
    this.isGenerating = false,
    this.error,
    required this.selectedMonth,
    required this.selectedYear,
  });

  PayrollState copyWith({
    List<PayrollModel>? payrolls,
    bool? isLoading,
    bool? isGenerating,
    String? error,
    int? selectedMonth,
    int? selectedYear,
  }) {
    return PayrollState(
      payrolls: payrolls ?? this.payrolls,
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error ?? this.error,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
    );
  }

  PayrollState clearError() => PayrollState(
        payrolls: payrolls,
        isLoading: isLoading,
        isGenerating: isGenerating,
        error: null,
        selectedMonth: selectedMonth,
        selectedYear: selectedYear,
      );
}

class PayrollNotifier extends StateNotifier<PayrollState> {
  final CompanyAdminRepository _repo;
  final Ref _ref;

  PayrollNotifier(this._repo, this._ref)
      : super(PayrollState(
          selectedMonth: DateTime.now().month,
          selectedYear: DateTime.now().year,
        )) {
    loadPayrolls(DateTime.now().month, DateTime.now().year);
  }

  Future<void> loadPayrolls(int month, int year) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedMonth: month,
      selectedYear: year,
    );
    try {
      final list = await _repo.getPayrolls(user.companyId, month, year);
      // Sort by employee name
      list.sort((a, b) => a.employeeName.compareTo(b.employeeName));
      state = state.copyWith(isLoading: false, payrolls: list);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Failed to load payrolls: $e');
    }
  }

  /// Generates payroll for all eligible employees for the selected month/year.
  /// Returns number of new records generated, or -1 on error.
  Future<int> generatePayroll(int month, int year) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return -1;

    state = state.copyWith(isGenerating: true, error: null);
    try {
      final count = await _repo.generateMonthlyPayroll(
        companyId: user.companyId,
        month: month,
        year: year,
        generatedBy: user.name,
      );
      await loadPayrolls(month, year);
      state = state.copyWith(isGenerating: false);
      return count;
    } catch (e) {
      state = state.copyWith(
          isGenerating: false, error: 'Payroll generation failed: $e');
      return -1;
    }
  }

  Future<void> approvePayroll(String payrollId) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    try {
      await _repo.updatePayrollStatus(
        payrollId,
        'Approved',
        approvedBy: user.name,
        approvedAt: DateTime.now(),
      );
      await loadPayrolls(state.selectedMonth, state.selectedYear);
    } catch (e) {
      state = state.copyWith(error: 'Failed to approve payroll: $e');
    }
  }

  Future<void> rejectPayroll(String payrollId, String remarks) async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;
    try {
      await _repo.updatePayrollStatus(
        payrollId,
        'Rejected',
        approvedBy: user.name,
        remarks: remarks,
        approvedAt: DateTime.now(),
      );
      await loadPayrolls(state.selectedMonth, state.selectedYear);
    } catch (e) {
      state = state.copyWith(error: 'Failed to reject payroll: $e');
    }
  }

  Future<void> markAsPaid(String payrollId) async {
    try {
      await _repo.updatePayrollStatus(
        payrollId,
        'Paid',
        paidAt: DateTime.now(),
      );
      await loadPayrolls(state.selectedMonth, state.selectedYear);
    } catch (e) {
      state = state.copyWith(error: 'Failed to mark as paid: $e');
    }
  }

  Future<void> updatePayrollStatus(String payrollId, String status) async {
    if (status == 'Approved') {
      await approvePayroll(payrollId);
    } else if (status == 'Rejected') {
      await rejectPayroll(payrollId, '');
    } else if (status == 'Paid') {
      await markAsPaid(payrollId);
    }
  }

  void clearError() {
    state = state.clearError();
  }
}

final payrollProvider =
    StateNotifierProvider<PayrollNotifier, PayrollState>((ref) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return PayrollNotifier(repo, ref);
});

// Employee payroll history (per-employee drill-down)
class EmployeePayrollHistoryNotifier
    extends StateNotifier<AsyncValue<List<PayrollModel>>> {
  final CompanyAdminRepository _repo;
  final Ref _ref;
  final String _employeeId;

  EmployeePayrollHistoryNotifier(this._repo, this._ref, this._employeeId)
      : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final list =
          await _repo.getEmployeePayrolls(user.companyId, _employeeId);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(AppErrorHandler.parseError(e, stack), stack);
    }
  }
}

final employeePayrollHistoryProvider = StateNotifierProvider.family.autoDispose<
    EmployeePayrollHistoryNotifier,
    AsyncValue<List<PayrollModel>>,
    String>((ref, employeeId) {
  final repo = ref.watch(companyAdminRepositoryProvider);
  return EmployeePayrollHistoryNotifier(repo, ref, employeeId);
});

class CompanyFeaturesState {
  final Map<String, bool> modules;

  const CompanyFeaturesState({required this.modules});

  bool isEnabled(String moduleKey) => modules[moduleKey] ?? true;

  CompanyFeaturesState copyWith({Map<String, bool>? modules}) {
    return CompanyFeaturesState(modules: modules ?? this.modules);
  }
}

class CompanyFeaturesNotifier extends StateNotifier<CompanyFeaturesState> {
  final Ref _ref;

  CompanyFeaturesNotifier(this._ref) : super(const CompanyFeaturesState(modules: {
    'employee_management': true,
    'attendance': true,
    'leave_management': true,
    'payroll': true,
    'lead_management': true,
    'order_management': true,
    'notifications': true,
    'reports': true,
    'department_management': true,
    'designation_management': true,
    'holiday_management': true,
    'shift_management': true,
    'task_management': true,
    'expense_management': true,
    'document_management': true,
  }));

  Future<void> toggleModule(String moduleKey, bool isEnabled) async {
    final updated = Map<String, bool>.from(state.modules)..[moduleKey] = isEnabled;
    state = state.copyWith(modules: updated);
    
    final user = _ref.read(authProvider).user;
    if (user != null && user.companyId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(user.companyId)
            .set({'enabledModules': updated}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to save module toggles: $e');
      }
    }
  }
}

final companyFeaturesProvider = StateNotifierProvider<CompanyFeaturesNotifier, CompanyFeaturesState>((ref) {
  return CompanyFeaturesNotifier(ref);
});
