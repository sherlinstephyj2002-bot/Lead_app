import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String taskId;
  final String companyId;
  final String assignedTo;
  final String assignedToId;
  final String title;
  final String description;
  final String status; // 'Pending', 'In Progress', 'Completed'
  final DateTime dueDate;
  final DateTime createdAt;
  final String? orderId;

  TaskModel({
    required this.taskId,
    required this.companyId,
    required this.assignedTo,
    required this.assignedToId,
    required this.title,
    required this.description,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    this.orderId,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      taskId: map['taskId'] ?? '',
      companyId: map['companyId'] ?? '',
      assignedTo: map['assignedTo'] ?? '',
      assignedToId: map['assignedToId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'Pending',
      dueDate: map['dueDate'] != null
          ? (map['dueDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      orderId: map['orderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'companyId': companyId,
      'assignedTo': assignedTo,
      'assignedToId': assignedToId,
      'title': title,
      'description': description,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'orderId': orderId,
    };
  }

  TaskModel copyWith({
    String? taskId,
    String? companyId,
    String? assignedTo,
    String? assignedToId,
    String? title,
    String? description,
    String? status,
    DateTime? dueDate,
    DateTime? createdAt,
    String? orderId,
  }) {
    return TaskModel(
      taskId: taskId ?? this.taskId,
      companyId: companyId ?? this.companyId,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToId: assignedToId ?? this.assignedToId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
    );
  }
}
