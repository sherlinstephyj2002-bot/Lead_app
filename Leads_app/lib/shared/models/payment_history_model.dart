import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentHistoryModel {
  final String paymentId;
  final double amount;
  final DateTime paidDate;
  final String billingMonth; // e.g. "July 2026"
  final String status; // "Paid", "Pending", "Failed"
  final String transactionReference;

  PaymentHistoryModel({
    required this.paymentId,
    required this.amount,
    required this.paidDate,
    required this.billingMonth,
    required this.status,
    required this.transactionReference,
  });

  factory PaymentHistoryModel.fromMap(Map<String, dynamic> map) {
    return PaymentHistoryModel(
      paymentId: map['paymentId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidDate: map['paidDate'] != null
          ? (map['paidDate'] as Timestamp).toDate()
          : DateTime.now(),
      billingMonth: map['billingMonth'] ?? '',
      status: map['status'] ?? 'Pending',
      transactionReference: map['transactionReference'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'amount': amount,
      'paidDate': Timestamp.fromDate(paidDate),
      'billingMonth': billingMonth,
      'status': status,
      'transactionReference': transactionReference,
    };
  }
}
