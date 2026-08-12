import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/user_roles.dart';

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

  // Additional Tenant & Employee Details
  final String? department;
  final String? designation;
  final String? branch;
  final String? employeeId;
  final DateTime? joiningDate;
  final String? status; // 'Active', 'Inactive', 'Suspended'
  final DateTime? lastLogin;
  final String? personalEmail;

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
    this.department,
    this.designation,
    this.branch,
    this.employeeId,
    this.joiningDate,
    this.status,
    this.lastLogin,
    this.personalEmail,
  });

  /// Normalize database values to code constants
  static String normalizeRole(String rawRole) {
    switch (rawRole.trim().toLowerCase()) {
      case 'super admin':
      case 'super_admin':
        return UserRoles.superAdmin;
      case 'company admin':
      case 'company_admin':
        return UserRoles.companyAdmin;
      case 'employee':
        return UserRoles.employee;
      case 'hr':
        return UserRoles.hr;
      case 'manager':
        return UserRoles.manager;
      case 'team leader':
      case 'team_leader':
        return UserRoles.teamLeader;
      default:
        return rawRole.isNotEmpty ? rawRole : UserRoles.employee;
    }
  }

  /// Denormalize code constants to legacy database values
  static String denormalizeRole(String normalizedRole) {
    switch (normalizedRole) {
      case UserRoles.superAdmin:
        return 'Super Admin';
      case UserRoles.companyAdmin:
        return 'Company Admin';
      case UserRoles.employee:
        return 'Employee';
      case UserRoles.hr:
        return 'HR';
      case UserRoles.manager:
        return 'Manager';
      case UserRoles.teamLeader:
        return 'Team Leader';
      default:
        return normalizedRole;
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawEmpId = map['employeeId'] ?? map['empId'] ?? map['employee_id'] ?? map['employeeCode'] ?? map['customEmployeeId'];
    final rawEmail = map['companyEmail'] ?? map['employeeEmail'] ?? map['email'] ?? map['hiddenEmail'] ?? '';

    return UserModel(
      uid: map['uid'] ?? map['id'] ?? '',
      email: rawEmail,
      name: map['name'] ?? map['fullName'] ?? '',
      role: normalizeRole(map['role'] ?? 'Employee'),
      companyId: map['companyId'] ?? map['tenantId'] ?? '',
      companyName: map['companyName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? map['phone'],
      profileImageUrl: map['profileImageUrl'] ?? map['avatar'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isEmailVerified: map['isEmailVerified'] ?? false,
      isPhoneVerified: map['isPhoneVerified'] ?? false,
      department: map['department'] ?? map['departmentName'],
      designation: map['designation'] ?? map['designationName'] ?? map['jobTitle'],
      branch: map['branch'] ?? map['branchName'] ?? map['location'],
      employeeId: (rawEmpId != null && rawEmpId.toString().isNotEmpty) ? rawEmpId.toString() : null,
      joiningDate: map['joiningDate'] != null
          ? (map['joiningDate'] is Timestamp
              ? (map['joiningDate'] as Timestamp).toDate()
              : DateTime.tryParse(map['joiningDate'].toString()))
          : null,
      status: map['status'] ?? map['accountStatus'] ?? 'Active',
      lastLogin: map['lastLogin'] != null
          ? (map['lastLogin'] is Timestamp
              ? (map['lastLogin'] as Timestamp).toDate()
              : DateTime.tryParse(map['lastLogin'].toString()))
          : null,
      personalEmail: map['personalEmail'] ?? map['employeeEmail'] ?? map['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
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
      'department': department,
      'designation': designation,
      'branch': branch,
      'employeeId': employeeId,
      'joiningDate': joiningDate != null ? Timestamp.fromDate(joiningDate!) : null,
      'status': status,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'personalEmail': personalEmail,
    };
  }
}

