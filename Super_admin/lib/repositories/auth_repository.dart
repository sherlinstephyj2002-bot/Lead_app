import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../constants/firestore_collections.dart';
import '../constants/user_roles.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of user authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the currently authenticated Firebase user
  User? currentUser() {
    return _auth.currentUser;
  }

  /// Maps internal/development email formats to valid Firebase Auth REST API formats if necessary
  String _mapFirebaseEmail(String email) {
    final clean = email.trim().toLowerCase();
    if (clean == 'superadmin@worktrack.local' || clean == 'admin@worktrack.local') {
      return 'superadmin.worktrack@gmail.com';
    }
    if (clean.endsWith('.local')) {
      return clean.replaceAll('.local', '@worktrackapp.com');
    }
    return clean;
  }

  /// Authenticate user using email and password
  Future<UserCredential> login(String email, String password) async {
    final targetEmail = _mapFirebaseEmail(email);
    return await _auth.signInWithEmailAndPassword(
      email: targetEmail,
      password: password,
    );
  }

  /// Sign out the current user from Firebase Auth
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Fetch the custom user model details from Cloud Firestore
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Send a password reset email to the specified address
  Future<void> sendPasswordResetEmail(String email) async {
    final targetEmail = _mapFirebaseEmail(email);
    await _auth.sendPasswordResetEmail(email: targetEmail);
  }

  /// Strip SuperAdmin role from any personal email accounts in Firestore to ensure complete isolation
  Future<void> sanitizePersonalSuperAdminRoles() async {
    try {
      final snap = await _firestore.collection(FirestoreCollections.users).get();
      for (var doc in snap.docs) {
        final data = doc.data();
        final email = (data['email'] ?? '').toString().trim().toLowerCase();
        final role = (data['role'] ?? '').toString();
        if (email.isNotEmpty &&
            email != 'superadmin@worktrack.local' &&
            email != 'superadmin.worktrack@gmail.com' &&
            (role == 'SuperAdmin' || role == 'Super Admin' || role == 'super_admin')) {
          print("[SUPERADMIN_AUTH] Purging SuperAdmin role association from personal account: $email");
          await _firestore.collection(FirestoreCollections.users).doc(doc.id).update({
            'role': 'CompanyAdmin',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print("[SUPERADMIN_AUTH] Sanitization exception: $e");
    }
  }

  /// Count how many Super Admin accounts exist in Firestore
  Future<int> getSuperAdminCount() async {
    final snap1 = await _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'SuperAdmin')
        .get();

    final snap2 = await _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'Super Admin')
        .get();

    final snap3 = await _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: UserRoles.superAdmin)
        .get();

    final uids = <String>{};
    for (var doc in snap1.docs) {
      uids.add(doc.id);
    }
    for (var doc in snap2.docs) {
      uids.add(doc.id);
    }
    for (var doc in snap3.docs) {
      uids.add(doc.id);
    }
    return uids.length;
  }

  /// Check if an email is registered as a Super Admin in Firestore
  Future<bool> checkIsSuperAdminEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    
    final snap = await _firestore
        .collection(FirestoreCollections.users)
        .where('email', isEqualTo: cleanEmail)
        .get();

    if (snap.docs.isEmpty) {
      final snapAll = await _firestore
          .collection(FirestoreCollections.users)
          .get();
      for (var doc in snapAll.docs) {
        final data = doc.data();
        final userEmail = (data['email'] ?? '').toString().trim().toLowerCase();
        if (userEmail == cleanEmail) {
          final role = UserModel.normalizeRole(data['role'] ?? '');
          return role == UserRoles.superAdmin;
        }
      }
      return false;
    }

    for (var doc in snap.docs) {
      final role = UserModel.normalizeRole(doc.data()['role'] ?? '');
      if (role == UserRoles.superAdmin) {
        return true;
      }
    }
    return false;
  }

  /// Safe check method to get masked email of existing super admin (Returns null to ensure no email exposure)
  Future<String?> getSuperAdminMaskedEmail() async {
    return null;
  }

  /// One-time initial Super Admin setup. Rejects if a Super Admin already exists.
  Future<UserCredential> registerInitialSuperAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final existingCount = await getSuperAdminCount();
    if (existingCount > 0) {
      throw Exception("Super Admin initial setup is disabled because a Super Admin account already exists.");
    }

    final cleanEmail = email.trim().toLowerCase();
    final targetFbEmail = _mapFirebaseEmail(cleanEmail);

    // Create user in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: targetFbEmail,
      password: password,
    );

    final uid = userCredential.user!.uid;

    final superAdminUser = UserModel(
      uid: uid,
      email: cleanEmail,
      name: name.trim(),
      role: UserRoles.superAdmin,
      companyId: 'platform',
      companyName: 'Platform System',
      createdAt: DateTime.now(),
      isEmailVerified: true,
      isPhoneVerified: false,
    );

    // Write user profile to Firestore
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(superAdminUser.toMap());

    return userCredential;
  }

  /// Change SuperAdmin password after re-authenticating with current password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception("No authenticated SuperAdmin session found.");
    }

    // Re-authenticate user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password in Firebase Auth
    await user.updatePassword(newPassword);
  }
}

