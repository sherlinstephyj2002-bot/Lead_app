import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyModel {
  final String companyId;
  final String name;
  final String subscriptionPlan; // Keep for compatibility: 'Free', 'Standard', 'Enterprise'
  final String status; // 'Active', 'Suspended', 'Deleted'
  final DateTime createdAt;
  final double? geofenceLat;
  final double? geofenceLng;
  final double? geofenceRadius;
  
  // Detailed SaaS profile registration fields
  final String companyType;
  final String businessEmail;
  final String companyMobile;
  final String country;
  final String state;
  final String city;
  final String address;
  final String zip;
  final String timeZone;
  final String? logoUrl;
  final String gstVat;
  final String website;
  final String? emailDomain;

  // Wizard Setup & Configuration Fields
  final List<String> workingDays;
  final String currency;
  final bool isSetupCompleted;
  final int setupWizardStep;

  // Audit and Management Fields
  final DateTime? updatedAt;
  final String? updatedBy;
  final DateTime? deletedAt;
  final String? deletedBy;
  final bool? isDeleted;
  final String? companyCode;
  final int? employeeCounter;
  final String? defaultEmployeePassword;

  // SaaS Subscription & Billing fields
  final String planName;
  final int freeEmployeeLimit;
  final double pricePerEmployee;
  final int activeEmployees;
  final int chargeableEmployees;
  final double monthlyBill;
  final String billingStatus;
  final DateTime? nextBillingDate;
  final String subscriptionStatus;
  final bool cancelAtPeriodEnd;
  final DateTime? cancellationEffectiveDate;
  final String? cancellationReason;

  // Feature Management / Module Enablement Flags
  final bool isLeadManagementEnabled;
  final bool isTaskManagementEnabled;
  final bool isAttendanceEnabled;
  final bool isLeaveEnabled;
  final bool isPayrollEnabled;

  CompanyModel({
    required this.companyId,
    required this.name,
    required this.subscriptionPlan,
    required this.status,
    required this.createdAt,
    this.geofenceLat,
    this.geofenceLng,
    this.geofenceRadius,
    this.companyType = '',
    this.businessEmail = '',
    this.companyMobile = '',
    this.country = '',
    this.state = '',
    this.city = '',
    this.address = '',
    this.zip = '',
    this.timeZone = '',
    this.logoUrl,
    this.gstVat = '',
    this.website = '',
    this.emailDomain,
    this.workingDays = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    this.currency = 'USD',
    this.isSetupCompleted = false,
    this.setupWizardStep = 0,
    this.updatedAt,
    this.updatedBy,
    this.deletedAt,
    this.deletedBy,
    this.isDeleted = false,
    this.companyCode,
    this.employeeCounter,
    this.defaultEmployeePassword,
    
    // SaaS defaults
    this.planName = 'Free',
    this.freeEmployeeLimit = 5,
    this.pricePerEmployee = 0.50,
    this.activeEmployees = 0,
    this.chargeableEmployees = 0,
    this.monthlyBill = 0.0,
    this.billingStatus = 'Active',
    this.nextBillingDate,
    this.subscriptionStatus = 'Active',
    this.cancelAtPeriodEnd = false,
    this.cancellationEffectiveDate,
    this.cancellationReason,

    // Feature enablement defaults
    this.isLeadManagementEnabled = true,
    this.isTaskManagementEnabled = true,
    this.isAttendanceEnabled = true,
    this.isLeaveEnabled = true,
    this.isPayrollEnabled = true,
  });

  /// Returns whether the company is on a Paid Plan.
  bool get isPaidPlan {
    final plan = (planName.isNotEmpty ? planName : subscriptionPlan).trim().toLowerCase();
    return plan == 'paid' ||
        plan == 'standard' ||
        plan == 'enterprise' ||
        plan == 'pro' ||
        plan == 'business' ||
        plan == 'growth' ||
        subscriptionStatus.trim().toLowerCase() == 'paid';
  }

  /// Returns whether the company is on the Free Plan.
  bool get isFreePlan => !isPaidPlan;

  /// Returns whether cancellation is pending at end of billing cycle.
  bool get isCancellationPending {
    final status = subscriptionStatus.trim().toLowerCase();
    return cancelAtPeriodEnd || status == 'cancellation pending' || status == 'cancellation_pending';
  }

  /// Returns whether paid features and limits are currently active.
  bool get isPaidAccessActive {
    if (isPaidPlan) {
      if (isCancellationPending && cancellationEffectiveDate != null) {
        return DateTime.now().isBefore(cancellationEffectiveDate!);
      }
      return true;
    }
    return false;
  }

  /// Centralized ad visibility logic:
  /// - Free Plan: Google Ads enabled (shown in designated dashboard location).
  /// - Paid Plan: Google Ads completely hidden everywhere.
  /// - Safe status handling: Expired / Cancelled -> hide ads.
  bool get showAds {
    if (isPaidAccessActive) return false;
    final status = subscriptionStatus.trim().toLowerCase();
    if (status == 'expired' || status == 'cancelled') return false;
    return isFreePlan;
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      companyId: map['companyId'] ?? map['tenantId'] ?? '',
      name: map['name'] ?? map['companyName'] ?? '',
      subscriptionPlan: map['subscriptionPlan'] ?? 'Free',
      status: map['status'] ?? 'Active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      geofenceLat: map['geofenceLat'] != null ? (map['geofenceLat'] as num).toDouble() : null,
      geofenceLng: map['geofenceLng'] != null ? (map['geofenceLng'] as num).toDouble() : null,
      geofenceRadius: map['geofenceRadius'] != null ? (map['geofenceRadius'] as num).toDouble() : null,
      companyType: map['companyType'] ?? '',
      businessEmail: map['businessEmail'] ?? '',
      companyMobile: map['companyMobile'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      zip: map['zip'] ?? '',
      timeZone: map['timeZone'] ?? '',
      logoUrl: map['logoUrl'],
      gstVat: map['gstVat'] ?? '',
      website: map['website'] ?? '',
      emailDomain: map['emailDomain'],
      workingDays: map['workingDays'] != null ? List<String>.from(map['workingDays']) : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      currency: map['currency'] ?? 'INR',
      isSetupCompleted: map['isSetupCompleted'] ?? false,
      setupWizardStep: map['setupWizardStep'] ?? 0,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      updatedBy: map['updatedBy'],
      deletedAt: map['deletedAt'] != null ? (map['deletedAt'] as Timestamp).toDate() : null,
      deletedBy: map['deletedBy'],
      isDeleted: map['isDeleted'] ?? false,
      companyCode: map['companyCode'],
      employeeCounter: map['employeeCounter'] ?? 0,
      defaultEmployeePassword: map['defaultEmployeePassword'] as String?,
      
      // SaaS parsing
      planName: map['planName'] ?? 'Free',
      freeEmployeeLimit: map['freeEmployeeLimit'] ?? 5,
      pricePerEmployee: (map['pricePerEmployee'] as num?)?.toDouble() ?? 0.50,
      activeEmployees: map['activeEmployees'] ?? 0,
      chargeableEmployees: map['chargeableEmployees'] ?? 0,
      monthlyBill: (map['monthlyBill'] as num?)?.toDouble() ?? 0.0,
      billingStatus: map['billingStatus'] ?? 'Active',
      nextBillingDate: map['nextBillingDate'] != null ? (map['nextBillingDate'] as Timestamp).toDate() : null,
      subscriptionStatus: map['subscriptionStatus'] ?? 'Active',
      cancelAtPeriodEnd: map['cancelAtPeriodEnd'] ?? false,
      cancellationEffectiveDate: map['cancellationEffectiveDate'] != null ? (map['cancellationEffectiveDate'] as Timestamp).toDate() : null,
      cancellationReason: map['cancellationReason'],

      // Feature enablement parsing
      isLeadManagementEnabled: map['isLeadManagementEnabled'] ?? true,
      isTaskManagementEnabled: map['isTaskManagementEnabled'] ?? true,
      isAttendanceEnabled: map['isAttendanceEnabled'] ?? true,
      isLeaveEnabled: map['isLeaveEnabled'] ?? true,
      isPayrollEnabled: map['isPayrollEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'tenantId': companyId,
      'name': name,
      'companyName': name,
      'subscriptionPlan': subscriptionPlan,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'geofenceLat': geofenceLat,
      'geofenceLng': geofenceLng,
      'geofenceRadius': geofenceRadius,
      'companyType': companyType,
      'businessEmail': businessEmail,
      'companyMobile': companyMobile,
      'country': country,
      'state': state,
      'city': city,
      'address': address,
      'zip': zip,
      'timeZone': timeZone,
      'logoUrl': logoUrl,
      'gstVat': gstVat,
      'website': website,
      'emailDomain': emailDomain,
      'workingDays': workingDays,
      'currency': currency,
      'isSetupCompleted': isSetupCompleted,
      'setupWizardStep': setupWizardStep,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedBy': deletedBy,
      'isDeleted': isDeleted,
      'companyCode': companyCode,
      'employeeCounter': employeeCounter,
      'defaultEmployeePassword': defaultEmployeePassword,
      
      // SaaS serialization
      'planName': planName,
      'freeEmployeeLimit': freeEmployeeLimit,
      'pricePerEmployee': pricePerEmployee,
      'activeEmployees': activeEmployees,
      'chargeableEmployees': chargeableEmployees,
      'monthlyBill': monthlyBill,
      'billingStatus': billingStatus,
      'nextBillingDate': nextBillingDate != null ? Timestamp.fromDate(nextBillingDate!) : null,
      'subscriptionStatus': subscriptionStatus,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'cancellationEffectiveDate': cancellationEffectiveDate != null ? Timestamp.fromDate(cancellationEffectiveDate!) : null,
      'cancellationReason': cancellationReason,

      // Feature enablement serialization
      'isLeadManagementEnabled': isLeadManagementEnabled,
      'isTaskManagementEnabled': isTaskManagementEnabled,
      'isAttendanceEnabled': isAttendanceEnabled,
      'isLeaveEnabled': isLeaveEnabled,
      'isPayrollEnabled': isPayrollEnabled,
    };
  }

  CompanyModel copyWith({
    String? companyId,
    String? name,
    String? subscriptionPlan,
    String? status,
    DateTime? createdAt,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadius,
    String? companyType,
    String? businessEmail,
    String? companyMobile,
    String? country,
    String? state,
    String? city,
    String? address,
    String? zip,
    String? timeZone,
    String? logoUrl,
    bool clearLogoUrl = false,
    String? gstVat,
    String? website,
    String? emailDomain,
    List<String>? workingDays,
    String? currency,
    bool? isSetupCompleted,
    int? setupWizardStep,
    DateTime? updatedAt,
    String? updatedBy,
    DateTime? deletedAt,
    String? deletedBy,
    bool? isDeleted,
    String? companyCode,
    int? employeeCounter,
    String? defaultEmployeePassword,
    
    // SaaS fields
    String? planName,
    int? freeEmployeeLimit,
    double? pricePerEmployee,
    int? activeEmployees,
    int? chargeableEmployees,
    double? monthlyBill,
    String? billingStatus,
    DateTime? nextBillingDate,
    String? subscriptionStatus,
    bool? cancelAtPeriodEnd,
    DateTime? cancellationEffectiveDate,
    String? cancellationReason,

    // Feature enablement fields
    bool? isLeadManagementEnabled,
    bool? isTaskManagementEnabled,
    bool? isAttendanceEnabled,
    bool? isLeaveEnabled,
    bool? isPayrollEnabled,
  }) {
    return CompanyModel(
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      geofenceLat: geofenceLat ?? this.geofenceLat,
      geofenceLng: geofenceLng ?? this.geofenceLng,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      companyType: companyType ?? this.companyType,
      businessEmail: businessEmail ?? this.businessEmail,
      companyMobile: companyMobile ?? this.companyMobile,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      address: address ?? this.address,
      zip: zip ?? this.zip,
      timeZone: timeZone ?? this.timeZone,
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      gstVat: gstVat ?? this.gstVat,
      website: website ?? this.website,
      emailDomain: emailDomain ?? this.emailDomain,
      workingDays: workingDays ?? this.workingDays,
      currency: currency ?? this.currency,
      isSetupCompleted: isSetupCompleted ?? this.isSetupCompleted,
      setupWizardStep: setupWizardStep ?? this.setupWizardStep,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      companyCode: companyCode ?? this.companyCode,
      employeeCounter: employeeCounter ?? this.employeeCounter,
      defaultEmployeePassword: defaultEmployeePassword ?? this.defaultEmployeePassword,
      
      // SaaS copyWith mapping
      planName: planName ?? this.planName,
      freeEmployeeLimit: freeEmployeeLimit ?? this.freeEmployeeLimit,
      pricePerEmployee: pricePerEmployee ?? this.pricePerEmployee,
      activeEmployees: activeEmployees ?? this.activeEmployees,
      chargeableEmployees: chargeableEmployees ?? this.chargeableEmployees,
      monthlyBill: monthlyBill ?? this.monthlyBill,
      billingStatus: billingStatus ?? this.billingStatus,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      cancellationEffectiveDate: cancellationEffectiveDate ?? this.cancellationEffectiveDate,
      cancellationReason: cancellationReason ?? this.cancellationReason,

      // Feature enablement copyWith mapping
      isLeadManagementEnabled: isLeadManagementEnabled ?? this.isLeadManagementEnabled,
      isTaskManagementEnabled: isTaskManagementEnabled ?? this.isTaskManagementEnabled,
      isAttendanceEnabled: isAttendanceEnabled ?? this.isAttendanceEnabled,
      isLeaveEnabled: isLeaveEnabled ?? this.isLeaveEnabled,
      isPayrollEnabled: isPayrollEnabled ?? this.isPayrollEnabled,
    );
  }
}
