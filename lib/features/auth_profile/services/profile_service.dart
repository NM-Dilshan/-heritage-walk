import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Demo session only. No password storage, identity verification or persistence.
class ProfileService extends ChangeNotifier {
  static const demoProfile = UserProfile(
    id: 'demo-session',
    fullName: 'Nuwan Perera',
    email: 'nuwan@example.com',
    phone: '+94 77 123 4567',
    bio: 'Travel enthusiast and history lover.',
  );
  UserProfile _profile = demoProfile;
  UserProfile get profile => _profile;
  bool _authenticated = false;
  bool get isAuthenticated => _authenticated;

  Future<void> signIn(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _profile = _profile.copyWith(email: email.trim());
    _authenticated = true;
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _profile = UserProfile(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      fullName: fullName.trim(),
      email: email.trim(),
    );
    _authenticated = true;
    notifyListeners();
  }

  Future<void> update(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _profile = profile;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    // Replace this simulated boundary during backend integration.
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  void signOut() {
    _authenticated = false;
    _profile = demoProfile;
    notifyListeners();
  }
}

class ProfileScope extends InheritedNotifier<ProfileService> {
  const ProfileScope({
    super.key,
    required ProfileService service,
    required super.child,
  }) : super(notifier: service);
  static ProfileService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()!.notifier!;
}
