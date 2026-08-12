import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryComponentModel {
  final String componentId;
  final String companyId;
  final String componentName;
  final String componentType; // 'Earning', 'Deduction'
  final String calculationType; // 'Fixed', 'Percentage'
  final double defaultValue;
  final bool isMandatory;
  final bool isTaxable;
  final String status; // 'active', 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Compatibility getters for existing codebase integration
  String get name => componentName;
  String get type => componentType;
  double get value => defaultValue;

  SalaryComponentModel({
    required this.componentId,
    required this.companyId,
    required this.componentName,
    required this.componentType,
    this.calculationType = 'Fixed',
    this.defaultValue = 0.0,
    this.isMandatory = false,
    this.isTaxable = false,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalaryComponentModel.fromMap(Map<String, dynamic> map) {
    return SalaryComponentModel(
      componentId: map['componentId'] ?? '',
      companyId: map['companyId'] ?? '',
      componentName: map['componentName'] ?? map['name'] ?? '',
      componentType: map['componentType'] ?? map['type'] ?? 'Earning',
      calculationType: map['calculationType'] ?? 'Fixed',
      defaultValue: map['defaultValue'] != null
          ? (map['defaultValue'] as num).toDouble()
          : (map['value'] != null ? (map['value'] as num).toDouble() : 0.0),
      isMandatory: map['isMandatory'] ?? false,
      isTaxable: map['isTaxable'] ?? false,
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'].toString()))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'componentId': componentId,
      'companyId': companyId,
      'componentName': componentName,
      'componentType': componentType,
      'calculationType': calculationType,
      'defaultValue': defaultValue,
      'isMandatory': isMandatory,
      'isTaxable': isTaxable,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SalaryComponentModel copyWith({
    String? componentId,
    String? companyId,
    String? componentName,
    String? componentType,
    String? calculationType,
    double? defaultValue,
    bool? isMandatory,
    bool? isTaxable,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalaryComponentModel(
      componentId: componentId ?? this.componentId,
      companyId: companyId ?? this.companyId,
      componentName: componentName ?? this.componentName,
      componentType: componentType ?? this.componentType,
      calculationType: calculationType ?? this.calculationType,
      defaultValue: defaultValue ?? this.defaultValue,
      isMandatory: isMandatory ?? this.isMandatory,
      isTaxable: isTaxable ?? this.isTaxable,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
