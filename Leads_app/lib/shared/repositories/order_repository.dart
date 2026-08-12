import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/order_attachment_model.dart';
import '../models/order_model.dart';
import '../models/task_model.dart';
import '../models/expense_model.dart';
import '../../constants/firestore_collections.dart';

class OrderPageResult {
  final List<OrderModel> orders;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;

  OrderPageResult(this.orders, this.lastDoc);
}

class OrderRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  OrderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<OrderModel>> getOrders(String companyId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.orders)
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => OrderModel.fromMap(d.data())).toList();
  }

  Future<OrderPageResult> getOrdersPage(
    String companyId, {
    int limit = 15,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      var query = _firestore
          .collection(FirestoreCollections.orders)
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      final orders = snap.docs.map((d) => OrderModel.fromMap(d.data())).toList();
      return OrderPageResult(orders, snap.docs.isNotEmpty ? snap.docs.last : null);
    } catch (e) {
      print("ORDERS PAGINATION ERROR: $e");
      rethrow;
    }
  }

  Future<void> saveOrder(OrderModel order) async {
    await _firestore.collection(FirestoreCollections.orders).doc(order.orderId).set(order.toMap());
  }

  Future<void> deleteOrder(String orderId) async {
    await _firestore.collection(FirestoreCollections.orders).doc(orderId).delete();
  }

  Future<List<TaskModel>> getTasks(String companyId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.tasks)
        .where('companyId', isEqualTo: companyId)
        .orderBy('dueDate', descending: false)
        .get();
    return snap.docs.map((d) => TaskModel.fromMap(d.data())).toList();
  }

  Future<void> saveTask(TaskModel task) async {
    await _firestore.collection(FirestoreCollections.tasks).doc(task.taskId).set(task.toMap());
  }

  Future<List<ExpenseModel>> getExpenses(String companyId) async {
    final snap = await _firestore
        .collection(FirestoreCollections.expenses)
        .where('companyId', isEqualTo: companyId)
        .get();
    final list = snap.docs.map((d) => ExpenseModel.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveExpense(ExpenseModel expense) async {
    await _firestore.collection(FirestoreCollections.expenses).doc(expense.expenseId).set(expense.toMap());
  }

  Future<List<OrderAttachmentModel>> getOrderAttachments(String companyId, String orderId) async {
    final snap = await _firestore
        .collection('orderAttachments')
        .where('companyId', isEqualTo: companyId)
        .where('orderId', isEqualTo: orderId)
        .orderBy('uploadedAt', descending: true)
        .get();

    return snap.docs.map((d) => OrderAttachmentModel.fromMap(d.data())).toList();
  }

  Future<OrderAttachmentModel> uploadOrderAttachment(
    String companyId,
    String orderId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final storagePath = 'orders/$companyId/$orderId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';
    final ref = _storage.ref(storagePath);
    final uploadTask = await ref.putData(fileBytes);
    final url = await uploadTask.ref.getDownloadURL();

    final attachment = OrderAttachmentModel(
      orderId: orderId,
      companyId: companyId,
      fileName: fileName,
      fileUrl: url,
      uploadedAt: DateTime.now(),
    );

    await _firestore
        .collection('orderAttachments')
        .doc('${orderId}_${attachment.uploadedAt.millisecondsSinceEpoch}_$safeFileName')
        .set(attachment.toMap());

    return attachment;
  }

  Future<void> deleteTask(String taskId) async {
    await _firestore.collection(FirestoreCollections.tasks).doc(taskId).delete();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection(FirestoreCollections.expenses).doc(expenseId).delete();
  }

}
