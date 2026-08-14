import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/user_roles.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // Stores UserRoles constants internally ('super_admin', 'company_admin', etc.)
  final String companyId;
  final String companyName;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime createdAt;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String? designation;
  final String? department;
  final String? departmentId;
  final String? designationId;
  final String? managerId;
  final DateTime? joiningDate;
  final String? employmentType;
  final String status; // 'active', 'suspended', 'deleted'
  final bool mustChangePassword;
  final String? tempPassword;
  final String? encryptedPassword;
  final String? shiftId;
  final String? employeeId;
  final String? companyCode;
  final String? hiddenEmail;
  final bool firstLogin;
  final DateTime? updatedAt;
  final String? branchId;
  final String? branchName;
  final String? salaryStructureId;
  final String? salaryStructureName;
  final String? employeeEmail;
  final DateTime? lastLogin;
  final bool passwordChanged;
  final String? personalEmail;
  final String? companyEmail;
  final String? tenantId;
  final bool? temporaryPasswordRequired;
  final String? accountStatus;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? bloodGroup;
  final String? maritalStatus;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? panNumber;
  final String? aadhaarNumber;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.companyId,
    required this.companyName,
    this.phoneNumber,
    this.profileImageUrl,
    required this.createdAt,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.designation,
    this.department,
    this.departmentId,
    this.designationId,
    this.managerId,
    this.joiningDate,
    this.employmentType,
    this.status = 'active',
    this.mustChangePassword = false,
    this.tempPassword,
    this.encryptedPassword,
    this.shiftId,
    this.updatedAt,
    this.branchId,
    this.branchName,
    this.salaryStructureId,
    this.salaryStructureName,
    this.employeeId,
    this.companyCode,
    this.hiddenEmail,
    this.firstLogin = false,
    this.employeeEmail,
    this.lastLogin,
    this.passwordChanged = false,
    this.personalEmail,
    this.companyEmail,
    this.tenantId,
    this.temporaryPasswordRequired,
    this.accountStatus,
    this.gender,
    this.dateOfBirth,
    this.bloodGroup,
    this.maritalStatus,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.panNumber,
    this.aadhaarNumber,
  });

  /// Dedicated Admin Code for Company Admin (e.g., ADM-JAS001)
  String get adminCode {
    if (employeeId != null && employeeId!.toUpperCase().startsWith('ADM-')) {
      return employeeId!;
    }
    final code = (companyCode != null && companyCode!.isNotEmpty) ? companyCode! : '001';
    return 'ADM-$code';
  }

  /// Display Employee ID (business code e.g. AB04, or Admin Code e.g. ADM-JC).
  String get displayEmployeeId {
    if (role == UserRoles.companyAdmin) {
      return adminCode;
    }
    if (employeeId != null && employeeId!.trim().isNotEmpty) {
      return employeeId!.trim();
    }
    return 'Employee ID unavailable';
  }

  /// Normalize database values to code constants
  static String normalizeRole(String rawRole) {
    switch (rawRole.trim().toLowerCase()) {
      case 'super admin':
      case 'super_admin':
      case 'company admin':
      case 'company_admin':
        return UserRoles.companyAdmin;
      case 'employee':
        return UserRoles.employee;
      case 'hr':
        return UserRoles.hr;
      case 'hr admin':
      case 'hr_admin':
        return UserRoles.hrAdmin;
      case 'hr executive':
      case 'hr_executive':
        return UserRoles.hrExecutive;
      case 'recruiter':
        return UserRoles.recruiter;
      case 'payroll executive':
      case 'payroll_executive':
        return UserRoles.payrollExecutive;
      case 'manager':
        return UserRoles.manager;
      case 'team leader':
      case 'team_role':
      case 'team_leader':
        return UserRoles.teamLeader;
      default:
        return rawRole.isNotEmpty ? rawRole : UserRoles.employee;
    }
  }

  /// Denormalize code constants to legacy database values
  static String denormalizeRole(String normalizedRole) {
    switch (normalizedRole) {
      case UserRoles.companyAdmin:
        return 'Company Admin';
      case UserRoles.employee:
        return 'Employee';
      case UserRoles.hr:
        return 'HR';
      case UserRoles.hrAdmin:
        return 'HR Admin';
      case UserRoles.hrExecutive:
        return 'HR Executive';
      case UserRoles.recruiter:
        return 'Recruiter';
      case UserRoles.payrollExecutive:
        return 'Payroll Executive';
      case UserRoles.manager:
        return 'Manager';
      case UserRoles.teamLeader:
        return 'Team Leader';
      default:
        return normalizedRole;
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final extractedUid = map['uid'] ?? map['firebaseUid'] ?? '';
    final extractedCompanyId = map['companyId'] ?? map['tenantId'] ?? '';
    return UserModel(
      uid: extractedUid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: normalizeRole(map['role'] ?? 'Employee'),
      companyId: extractedCompanyId,
      companyName: map['companyName'] ?? '',
      phoneNumber: map['phoneNumber'],
      profileImageUrl: map['profileImageUrl'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isEmailVerified: map['isEmailVerified'] ?? false,
      isPhoneVerified: map['isPhoneVerified'] ?? false,
      designation: map['designation'],
      department: map['department'],
      departmentId: map['departmentId'],
      designationId: map['designationId'],
      managerId: map['managerId'],
      joiningDate: map['joiningDate'] != null
          ? (map['joiningDate'] as Timestamp).toDate()
          : null,
      employmentType: map['employmentType'],
      status: map['status'] ?? map['accountStatus'] ?? 'active',
      mustChangePassword: (map['mustChangePassword'] as bool?) ?? (map['temporaryPasswordRequired'] as bool?) ?? false,
      tempPassword: map['tempPassword'],
      encryptedPassword: map['encryptedPassword'],
      shiftId: map['shiftId'],
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      branchId: map['branchId'],
      branchName: map['branchName'],
      salaryStructureId: map['salaryStructureId'],
      salaryStructureName: map['salaryStructureName'],
      employeeId: map['employeeId'],
      companyCode: map['companyCode'],
      hiddenEmail: map['hiddenEmail'],
      firstLogin: (map['firstLogin'] as bool?) ?? false,
      employeeEmail: map['employeeEmail'] ?? map['hiddenEmail'] ?? map['email'],
      lastLogin: map['lastLogin'] != null
          ? (map['lastLogin'] as Timestamp).toDate()
          : null,
      passwordChanged: (map['passwordChanged'] as bool?) ?? false,
      personalEmail: map['personalEmail'] ?? map['employeeEmail'] ?? map['email'],
      companyEmail: map['companyEmail'] ?? map['hiddenEmail'] ?? map['email'],
      tenantId: map['tenantId'] ?? map['companyId'],
      temporaryPasswordRequired: (map['temporaryPasswordRequired'] as bool?) ?? (map['mustChangePassword'] as bool?) ?? false,
      accountStatus: map['accountStatus'] ?? map['status'] ?? 'active',
      gender: map['gender'],
      dateOfBirth: map['dateOfBirth'] != null ? (map['dateOfBirth'] as Timestamp).toDate() : null,
      bloodGroup: map['bloodGroup'],
      maritalStatus: map['maritalStatus'],
      emergencyContactName: map['emergencyContactName'],
      emergencyContactPhone: map['emergencyContactPhone'],
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      ifscCode: map['ifscCode'],
      panNumber: map['panNumber'],
      aadhaarNumber: map['aadhaarNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firebaseUid': uid,
      'email': email,
      'name': name,
      'role': denormalizeRole(role),
      'companyId': companyId,
      'companyName': companyName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isEmailVerified': isEmailVerified,
      'isPhoneVerified': isPhoneVerified,
      'designation': designation,
      'department': department,
      'departmentId': departmentId,
      'designationId': designationId,
      'managerId': managerId,
      'joiningDate': joiningDate != null ? Timestamp.fromDate(joiningDate!) : null,
      'employmentType': employmentType,
      'status': status,
      'mustChangePassword': mustChangePassword,
      'tempPassword': tempPassword,
      'encryptedPassword': encryptedPassword,
      'shiftId': shiftId,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'branchId': branchId,
      'branchName': branchName,
      'salaryStructureId': salaryStructureId,
      'salaryStructureName': salaryStructureName,
      'employeeId': employeeId,
      'companyCode': companyCode,
      'hiddenEmail': hiddenEmail,
      'firstLogin': firstLogin,
      'employeeEmail': employeeEmail ?? hiddenEmail ?? email,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'passwordChanged': passwordChanged,
      'personalEmail': personalEmail ?? employeeEmail ?? email,
      'companyEmail': companyEmail ?? hiddenEmail ?? email,
      'tenantId': tenantId ?? companyId,
      'temporaryPasswordRequired': temporaryPasswordRequired ?? mustChangePassword,
      'accountStatus': accountStatus ?? status,
      'gender': gender,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'bloodGroup': bloodGroup,
      'maritalStatus': maritalStatus,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'panNumber': panNumber,
      'aadhaarNumber': aadhaarNumber,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? companyId,
    String? companyName,
    String? phoneNumber,
    String? profileImageUrl,
    DateTime? createdAt,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    String? designation,
    String? department,
    String? departmentId,
    String? designationId,
    String? managerId,
    DateTime? joiningDate,
    String? employmentType,
    String? status,
    bool? mustChangePassword,
    String? tempPassword,
    String? encryptedPassword,
    String? shiftId,
    DateTime? updatedAt,
    String? branchId,
    String? branchName,
    String? salaryStructureId,
    String? salaryStructureName,
    String? employeeId,
    String? companyCode,
    String? hiddenEmail,
    bool? firstLogin,
    String? employeeEmail,
    DateTime? lastLogin,
    bool? passwordChanged,
    String? personalEmail,
    String? companyEmail,
    String? tenantId,
    bool? temporaryPasswordRequired,
    String? accountStatus,
    String? gender,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? maritalStatus,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? panNumber,
    String? aadhaarNumber,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      departmentId: departmentId ?? this.departmentId,
      designationId: designationId ?? this.designationId,
      managerId: managerId ?? this.managerId,
      joiningDate: joiningDate ?? this.joiningDate,
      employmentType: employmentType ?? this.employmentType,
      status: status ?? this.status,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      tempPassword: tempPassword ?? this.tempPassword,
      encryptedPassword: encryptedPassword ?? this.encryptedPassword,
      shiftId: shiftId ?? this.shiftId,
      updatedAt: updatedAt ?? this.updatedAt,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      salaryStructureId: salaryStructureId ?? this.salaryStructureId,
      salaryStructureName: salaryStructureName ?? this.salaryStructureName,
      employeeId: employeeId ?? this.employeeId,
      companyCode: companyCode ?? this.companyCode,
      hiddenEmail: hiddenEmail ?? this.hiddenEmail,
      firstLogin: firstLogin ?? this.firstLogin,
      employeeEmail: employeeEmail ?? this.employeeEmail,
      lastLogin: lastLogin ?? this.lastLogin,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      personalEmail: personalEmail ?? this.personalEmail,
      companyEmail: companyEmail ?? this.companyEmail,
      tenantId: tenantId ?? this.tenantId,
      temporaryPasswordRequired: temporaryPasswordRequired ?? this.temporaryPasswordRequired,
      accountStatus: accountStatus ?? this.accountStatus,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
    );
  }
}
