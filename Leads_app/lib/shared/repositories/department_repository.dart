import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/department_model.dart';

class DepartmentRepository {
  final FirebaseFirestore _firestore;

  DepartmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<DepartmentModel>> getDepartments(String companyId) async {
    final query = await _firestore
        .collection('departments')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'active')
        .get();
    return query.docs.map((doc) => DepartmentModel.fromMap(doc.data())).toList();
  }

  Future<void> saveDepartment(DepartmentModel department) async {
    await _firestore
        .collection('departments')
        .doc(department.departmentId)
        .set(department.toMap());
  }

  Future<void> deleteDepartment(String departmentId) async {
    await _firestore
        .collection('departments')
        .doc(departmentId)
        .update({'status': 'inactive', 'updatedAt': FieldValue.serverTimestamp()});
  }
}
