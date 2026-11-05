import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw StateError('Firebase n’a retourné aucun utilisateur connecté.');
    }
    try {
      return await loadProfile(firebaseUser.uid);
    } catch (_) {
      // Never leave an authenticated session active when its EduTrack profile
      // is missing, malformed, or not authorized for the requested role.
      await _auth.signOut();
      rethrow;
    }
  }

  Future<AppUser> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw StateError('Firebase n’a pas créé le compte utilisateur.');
    }

    final name = displayName.trim();
    try {
      await firebaseUser.updateDisplayName(name);
      await _users.doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'displayName': name,
        'role': AppRole.student.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      try {
        await firebaseUser.delete();
      } on FirebaseAuthException catch (cleanupError) {
        throw StateError(
          'Le profil n’a pas pu être créé et le compte Firebase '
          'n’a pas pu être annulé (${cleanupError.code}).',
        );
      }
      rethrow;
    }

    try {
      return await loadProfile(firebaseUser.uid);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<AppUser> loadProfile(String uid) async {
    final signedInUser = _auth.currentUser;
    if (signedInUser == null || signedInUser.uid != uid) {
      throw const UnauthorizedAccountException(
        'La session Firebase ne correspond pas au profil demandé.',
      );
    }
    await signedInUser.reload();
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.uid != uid) {
      throw const UnauthorizedAccountException(
        'La session Firebase n’est plus valide.',
      );
    }

    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw UserProfileNotFoundException(uid);
    }

    final displayName = data['displayName'];
    final email = data['email'];
    final profileUid = data['uid'];
    final className = data['className'];
    if (profileUid != uid ||
        displayName is! String ||
        displayName.trim().isEmpty ||
        email is! String ||
        email.trim().isEmpty ||
        email.toLowerCase() != firebaseUser.email?.toLowerCase() ||
        (className != null && className is! String)) {
      throw const FormatException('Le profil utilisateur est incomplet.');
    }

    final role = AppRole.fromValue(data['role']);
    final token = await firebaseUser.getIdTokenResult(role == AppRole.admin);
    final hasAdminClaim = token.claims?['admin'] == true;
    if ((role == AppRole.admin) != hasAdminClaim) {
      throw const UnauthorizedAccountException(
        'Le rôle du profil ne correspond pas aux autorisations du compte.',
      );
    }

    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role,
      className: className as String?,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

}

class UserProfileNotFoundException implements Exception {
  const UserProfileNotFoundException(this.uid);

  final String uid;

  @override
  String toString() =>
      'Aucun profil EduTrack n’est associé au compte Firebase $uid.';
}

class UnauthorizedAccountException implements Exception {
  const UnauthorizedAccountException(this.message);

  final String message;

  @override
  String toString() => message;
}
