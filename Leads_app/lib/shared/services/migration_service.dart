import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:worktrack/shared/models/company_model.dart';
import 'package:worktrack/shared/models/user_model.dart';
import 'package:worktrack/shared/utils/employee_id_generator.dart';

class MigrationService {
  static Future<void> runMigrations() async {
    try {
      final fs = FirebaseFirestore.instance;
      
      // 1. Fetch all companies
      final companySnap = await fs.collection('companies').get();
      debugPrint('Migration: Found ${companySnap.docs.length} companies to evaluate.');
      
      for (final compDoc in companySnap.docs) {
        final companyData = compDoc.data();
        final companyId = compDoc.id;
        final companyObj = CompanyModel.fromMap(companyData);
        String? currentCode = companyData['companyCode'];
        final companyName = companyData['name'] ?? 'Company';
        
        bool needsUpdate = false;
        
        if (currentCode == null || currentCode == 'N/A' || currentCode.trim().isEmpty) {
          currentCode = await _generateCodeForMigration(fs, companyName);
          needsUpdate = true;
        }
        
        if (needsUpdate) {
          await fs.collection('companies').doc(companyId).update({
            'companyCode': currentCode,
          });
        }
        
        // 2. Fetch all users belonging to this company
        final userSnap = await fs.collection('users')
            .where('companyId', isEqualTo: companyId)
            .get();

        final allCompanyUsers = userSnap.docs.map((d) => UserModel.fromMap(d.data())).toList();
            
        for (final userDoc in userSnap.docs) {
          final userData = userDoc.data();
          final userId = userDoc.id;
          final role = userData['role'] ?? 'employee';
          final name = userData['name'] ?? 'Employee';
          
          String? empId = userData['employeeId'];
          String? userCode = userData['companyCode'];
          String? companyEmail = userData['companyEmail'];
          
          bool userNeedsUpdate = false;
          
          if (userCode != currentCode) {
            userCode = currentCode;
            userNeedsUpdate = true;
          }
          
          // Migrate Employee ID & Company Email if missing or blank
          if (role != 'super_admin') {
            if (empId == null || empId.trim().isEmpty || empId == 'N/A') {
              final creds = EmployeeIdGenerator.generateCredentials(
                employeeName: name,
                existingEmployees: allCompanyUsers,
                company: companyObj,
              );
              empId = creds.employeeId;
              companyEmail = creds.companyEmail;
              userNeedsUpdate = true;
            } else if (companyEmail == null || companyEmail.trim().isEmpty) {
              final domain = EmployeeIdGenerator.extractCompanyDomain(companyObj);
              companyEmail = EmployeeIdGenerator.formatCompanyEmail(employeeId: empId, companyDomain: domain);
              userNeedsUpdate = true;
            }
          }
          
          if (userNeedsUpdate || userData.containsKey('username')) {
            final updateMap = <String, dynamic>{
              'companyCode': userCode,
              'username': FieldValue.delete(),
            };
            if (empId != null) updateMap['employeeId'] = empId;
            if (companyEmail != null) updateMap['companyEmail'] = companyEmail;
            
            await fs.collection('users').doc(userId).update(updateMap);
            debugPrint('Migration: Updated user $userId: employeeId=$empId, companyEmail=$companyEmail');
          }
        }
      }
      
      debugPrint('Migration completed successfully.');
    } catch (e) {
      debugPrint('Migration failed: $e');
    }
  }

  static Future<String> _generateCodeForMigration(FirebaseFirestore fs, String companyName) async {
    final cleanName = companyName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    var prefix = cleanName.length >= 3 ? cleanName.substring(0, 3) : (cleanName + 'AAA').substring(0, 3);
    if (prefix == 'NAN' || prefix == 'N/A') {
      prefix = 'COM';
    }
    
    final snapshot = await fs
        .collection('companies')
        .where('companyCode', isGreaterThanOrEqualTo: prefix)
        .where('companyCode', isLessThan: prefix + '\uf8ff')
        .get();
        
    final existingCodes = snapshot.docs
        .map((doc) => doc.data()['companyCode'] as String?)
        .where((code) => code != null && code.startsWith(prefix))
        .toList();
        
    int maxNum = 0;
    final regex = RegExp('^' + prefix + r'(\d+)$');
    for (final code in existingCodes) {
      final match = regex.firstMatch(code!);
      if (match != null) {
        final num = int.tryParse(match.group(1)!);
        if (num != null && num > maxNum) {
          maxNum = num;
        }
      }
    }
    
    final nextNum = maxNum + 1;
    final formattedNum = nextNum.toString().padLeft(3, '0');
    return '$prefix$formattedNum';
  }
}