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

  /// Authenticate user using email and password
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
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
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Count how many Super Admin accounts exist in Firestore
  Future<int> getSuperAdminCount() async {
    final snap1 = await _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'Super Admin')
        .get();
        
    final snap2 = await _firestore
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

  /// Safe check method to get masked email of existing super admin for dev/testing without exposing passwords
  Future<String?> getSuperAdminMaskedEmail() async {
    final count = await getSuperAdminCount();
    if (count == 0) return null;

    final snap = await _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: 'Super Admin')
        .get();

    if (snap.docs.isNotEmpty) {
      final email = (snap.docs.first.data()['email'] ?? '').toString();
      if (email.contains('@')) {
        final parts = email.split('@');
        final namePart = parts[0];
        final domainPart = parts[1];
        if (namePart.length > 2) {
          return '${namePart.substring(0, 2)}***@$domainPart';
        }
        return '***@$domainPart';
      }
      return 'Registered';
    }
    return 'Registered';
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

    // Create user in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
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
}

