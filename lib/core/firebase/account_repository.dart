import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth_profile/models/user_profile.dart';
import 'backend_error.dart';
import 'cloud_values.dart';

abstract interface class AccountRepository {
  Stream<String?> get authChanges;
  Future<UserProfile?> restore();
  Future<UserProfile> signIn(String email, String password);
  Future<UserProfile> register(String name, String email, String password);
  Future<void> update(UserProfile profile);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository(this.auth, this.db);
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  @override
  Stream<String?> get authChanges =>
      auth.authStateChanges().map((user) => user?.uid);
  Future<UserProfile> _profile(User user) async {
    final reference = db.collection('users').doc(user.uid);
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) {
      final profile = UserProfile(
        id: user.uid,
        fullName: user.displayName ?? '',
        email: user.email ?? '',
      );
      await reference.set({
        ...profile.toMap(),
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return profile;
    }
    return UserProfile.fromMap({
      ...CloudValues.normalize(snapshot.data()!),
      'id': user.uid,
    });
  }

  @override
  Future<UserProfile?> restore() async {
    final user = await auth.authStateChanges().first;
    return user == null ? null : _profile(user);
  }

  @override
  Future<UserProfile> signIn(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _profile(credential.user!);
  }

  @override
  Future<UserProfile> register(
    String name,
    String email,
    String password,
  ) async {
    final user = (await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    )).user!;
    // Preserve the entered name in Auth even if Firestore is temporarily unavailable.
    await user.updateDisplayName(name);
    final profile = UserProfile(
      id: user.uid,
      fullName: name,
      email: user.email ?? email,
    );
    await db.collection('users').doc(user.uid).set({
      ...profile.toMap(),
      'uid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return profile;
  }

  @override
  Future<void> update(UserProfile profile) async {
    final user = auth.currentUser;
    if (user == null || user.uid != profile.id) {
      throw const BackendFailure('Please sign in to edit your own profile.');
    }
    // Contact email is editable profile data. Login email stays managed by Auth.
    await db.collection('users').doc(user.uid).update({
      ...profile.toMap()..remove('role'),
      'uid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await user.updateDisplayName(profile.fullName);
  }

  @override
  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email);
  @override
  Future<void> signOut() => auth.signOut();
}
