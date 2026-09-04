import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/collections.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  User? get currentUser => auth.currentUser;

  Future<UserCredential> signIn(String email, String password) {
    return auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String name,
    required String role,
    required String mobile,
    String village = '',
    String district = '',
    String state = '',
    String referral = '',
    String aadhaarHash = '',
    String aadhaarLast4 = '',
    bool aadhaarConsent = false,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final uid = credential.user!.uid;
    final isBootstrapAdmin = email.trim().toLowerCase() == 'varunprakash547@gmail.com';
    final finalRole = isBootstrapAdmin ? 'super_admin' : role;
    final status = isBootstrapAdmin ? 'approved' : 'pending';
    final isActive = isBootstrapAdmin;

    await db.collection(Collections.users).doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'mobile': mobile.trim(),
      'role': finalRole,
      'status': status,
      'isActive': isActive,
      'village': village.trim(),
      'district': district.trim(),
      'state': state.trim(),
      'referralInput': referral.trim(),
      'aadhaarHash': aadhaarHash,
      'aadhaarLast4': aadhaarLast4,
      'aadhaarConsent': aadhaarConsent,
      'aadhaarVerified': false,
      'aadhaarHash': aadhaarHash,
      'aadhaarLast4': aadhaarLast4,
      'aadhaarConsent': aadhaarConsent,
      'aadhaarVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (credential.user != null) {
      await credential.user!.updateDisplayName(name.trim());
      await credential.user!.sendEmailVerification();
    }
    return credential;
  }

  Future<void> signOut() => auth.signOut();

  Future<void> resetPassword(String email) {
    return auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<Map<String, dynamic>?> profile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await db.collection(Collections.users).doc(uid).get();
    return snap.data();
  }
}
