import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String expenseId;
  final String companyId;
  final String employeeId;
  final String employeeName;
  final double amount;
  final String category; // 'Travel', 'Material', 'Food', 'Others'
  final String description;
  final String? receiptUrl;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final DateTime createdAt;
  final String? orderId;

  ExpenseModel({
    required this.expenseId,
    required this.companyId,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.category,
    required this.description,
    this.receiptUrl,
    required this.status,
    required this.createdAt,
    this.orderId,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      expenseId: map['expenseId'] ?? '',
      companyId: map['companyId'] ?? '',
      employeeId: map['employeeId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : 0.0,
      category: map['category'] ?? 'Others',
      description: map['description'] ?? '',
      receiptUrl: map['receiptUrl'] ?? map['expenseImageUrl'] ?? map['expenseImage'],
      status: map['status'] ?? 'Pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      orderId: map['orderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'companyId': companyId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'category': category,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderId': orderId,
    };
  }

  ExpenseModel copyWith({
    String? expenseId,
    String? companyId,
    String? employeeId,
    String? employeeName,
    double? amount,
    String? category,
    String? description,
    String? receiptUrl,
    String? status,
    DateTime? createdAt,
    String? orderId,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
    );
  }
}
