import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CustomerModel>> getCustomers(String companyId) async {
    final snap = await _firestore
        .collection('customers')
        .where('companyId', isEqualTo: companyId)
        .get();
    final list = snap.docs.map((d) => CustomerModel.fromMap(d.data())).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveCustomer(CustomerModel customer) async {
    await _firestore.collection('customers').doc(customer.customerId).set(customer.toMap());
  }

  Future<void> deleteCustomer(String customerId) async {
    await _firestore.collection('customers').doc(customerId).delete();
  }
}
