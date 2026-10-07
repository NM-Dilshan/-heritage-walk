import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth_profile/models/user_profile.dart';
import 'backend_error.dart';
import 'cloud_values.dart';
import 'social_auth.dart';

abstract interface class AccountRepository {
  Stream<String?> get authChanges;
  Future<UserProfile?> restore();
  Future<UserProfile> signIn(String email, String password);
  Future<UserProfile> register(String name, String email, String password);
  Future<void> update(UserProfile profile);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class FirebaseAccountRepository
    implements AccountRepository, SocialAccountRepository {
  FirebaseAccountRepository(
    this.auth,
    this.db, {
    SocialCredentialSource? social,
  }) : social = social ?? DeviceSocialCredentialSource();
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final SocialCredentialSource social;
  @override
  Stream<String?> get authChanges =>
      auth.authStateChanges().map((user) => user?.uid);
  Future<UserProfile> _profile(User user) async {
    final reference = db.collection('users').doc(user.uid);
    // Atomic read/create: an existing profile (including admin role) is never
    // replaced, even when restoration and authentication race across devices.
    return db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        final profile = UserProfile(
          id: user.uid,
          fullName: user.displayName ?? '',
          email: user.email ?? '',
          photoPath: user.photoURL,
        );
        transaction.set(reference, {
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
    });
  }

  @override
  Future<SocialResult> signInSocial(SocialProvider provider) async {
    final credential = await social.credential(provider);
    if (credential == null) return SocialResult.cancelled;
    final UserCredential result;
    try {
      result = await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-credential') {
        throw BackendFailure(
          provider == SocialProvider.google
              ? 'Unable to sign in with Google. Please try again.'
              : 'Unable to sign in with Facebook. Please try again.',
        );
      }
      rethrow;
    }
    try {
      if (result.user == null) {
        throw const BackendFailure(
          'Unable to complete the request. Please try again.',
        );
      }
      await _profile(result.user!);
      return SocialResult.authenticated;
    } catch (_) {
      // Do not leave a partially initialized session behind the auth gate.
      await signOut();
      rethrow;
    }
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
  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      // Older projects without enumeration protection may return this code.
      // Match the neutral success response without revealing account existence.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    final ids =
        auth.currentUser?.providerData.map((info) => info.providerId).toSet() ??
        <String>{};
    final providers = {
      for (final provider in SocialProvider.values)
        if (ids.contains('${provider.name}.com')) provider,
    };
    await auth.signOut();
    try {
      await social.signOut(providers: providers);
    } catch (_) {
      /* Local cleanup cannot retain a Firebase session. */
    }
  }
}
