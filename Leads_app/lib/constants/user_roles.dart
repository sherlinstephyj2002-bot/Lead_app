class UserRoles {
  static const String superAdmin = "super_admin";
  static const String companyAdmin = "company_admin";
  static const String hr = "hr";
  static const String hrAdmin = "hr_admin";
  static const String hrExecutive = "hr_executive";
  static const String recruiter = "recruiter";
  static const String payrollExecutive = "payroll_executive";
  static const String manager = "manager";
  static const String teamLeader = "team_leader";
  static const String employee = "employee";

  /// Returns true if the user role is eligible for personal daily check-in / check-out attendance.
  static bool allowsPersonalAttendance(String? role) {
    if (role == null) return false;
    switch (role) {
      case superAdmin:
      case companyAdmin:
      case hrAdmin:
        return false;
      case employee:
      case teamLeader:
      case manager:
      case hrExecutive:
      case hr:
      default:
        return true;
    }
  }

  /// Returns true if the user role has access to Sales / Lead Management.
  static bool canAccessLeads(String? role) {
    if (role == null) return false;
    switch (role) {
      case companyAdmin:
      case superAdmin:
      case manager:
      case teamLeader:
      case employee:
        return true;
      case hrAdmin:
      case hr:
      case hrExecutive:
        return false;
      default:
        return true;
    }
  }

  /// Returns true ONLY if the role is a Company Admin or Super Admin who should access the Admin Dashboard.
  static bool isAdminRole(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase().replaceAll(' ', '_');
    return r == companyAdmin ||
        r == superAdmin ||
        r == 'company_admin' ||
        r == 'super_admin' ||
        r == 'admin';
  }

  /// Returns true if the role is any HR or Admin management role.
  static bool isHRorAdminRole(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase().replaceAll(' ', '_');
    return r == companyAdmin ||
        r == superAdmin ||
        r == hrAdmin ||
        r == hrExecutive ||
        r == hr ||
        r == recruiter ||
        r == payrollExecutive ||
        r == 'company_admin' ||
        r == 'super_admin' ||
        r == 'hr_admin' ||
        r == 'hr_executive';
  }

  /// Returns true if the user role can approve payroll.
  static bool canApprovePayroll(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase().replaceAll(' ', '_');
    return r == hrAdmin || r == companyAdmin || r == superAdmin || r == 'hr_admin' || r == 'company_admin' || r == 'super_admin';
  }

  /// Returns true if the user role can modify salary structures and components.
  static bool canModifySalaryStructure(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase().replaceAll(' ', '_');
    return r == hrAdmin || r == companyAdmin || r == superAdmin || r == 'hr_admin' || r == 'company_admin' || r == 'super_admin';
  }

  /// Returns true if the user role can manage company holidays (CRUD).
  static bool canManageHolidays(String? role) {
    if (role == null) return false;
    final r = role.trim().toLowerCase().replaceAll(' ', '_');
    return r == hrAdmin || r == companyAdmin || r == superAdmin || r == 'hr_admin' || r == 'company_admin' || r == 'super_admin';
  }
}