import 'package:flutter/material.dart';

import 'dart:async';

import '../../../core/firebase/account_repository.dart';
import '../../../core/firebase/backend_error.dart';
import 'auth_validators.dart';

import '../models/user_profile.dart';

/// Memory implementation by default; production injects Firebase repositories.
class ProfileService extends ChangeNotifier {
  ProfileService({this.repository}) {
    if (repository != null) {
      _profile = const UserProfile(id: '', fullName: '', email: '');
    }
  }
  final AccountRepository? repository;
  bool get isCloud => repository != null;
  Future<void> Function(String?)? onSession;
  Future<void> ready = Future.value();
  StreamSubscription<String?>? _subscription;
  bool _working = false, _disposed = false;
  String? lastError;
  void initialize() {
    if (repository == null) return;
    ready = _restore();
    _subscription = repository!.authChanges.listen(
      (uid) {
        if (_working || _disposed) return;
        if (uid == null && _authenticated) {
          unawaited(_endSession());
        } else if (uid != null && uid != _profile.id) {
          ready = _restore();
        }
      },
      onError: (Object error) {
        if (!_disposed) {
          lastError = backendMessage(error);
          notifyListeners();
        }
      },
    );
  }

  Future<void> _restore() async {
    _working = true;
    try {
      _authenticated = false;
      await onSession?.call(null);
      _profile = const UserProfile(id: '', fullName: '', email: '');
      if (!_disposed) notifyListeners();
      final profile = await repository!.restore();
      if (_disposed) return;
      if (profile != null) {
        _profile = profile;
        await onSession?.call(profile.id);
        if (!_disposed) _authenticated = true;
      }
      lastError = null;
    } catch (error) {
      lastError = backendMessage(error);
    } finally {
      _working = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _endSession() async {
    _authenticated = false;
    await onSession?.call(null);
    _profile = repository == null
        ? demoProfile
        : const UserProfile(id: '', fullName: '', email: '');
    if (!_disposed) notifyListeners();
  }

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

  Future<void> signIn(String email, {String password = ''}) async {
    if (repository != null) {
      final error =
          AuthValidators.email(email) ?? AuthValidators.password(password);
      if (error != null) throw BackendFailure(error);
      _working = true;
      try {
        _profile = await repository!.signIn(email.trim(), password);
        await onSession?.call(_profile.id);
        _authenticated = true;
        lastError = null;
        notifyListeners();
      } finally {
        _working = false;
      }
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _profile = _profile.copyWith(email: email.trim());
    _authenticated = true;
    notifyListeners();
  }

  Future<void> register({
    required String fullName,
    required String email,
    String password = '',
  }) async {
    if (repository != null) {
      final error =
          AuthValidators.name(fullName) ??
          AuthValidators.email(email) ??
          AuthValidators.password(password);
      if (error != null) throw BackendFailure(error);
      _working = true;
      try {
        _profile = await repository!.register(
          fullName.trim(),
          email.trim(),
          password,
        );
        await onSession?.call(_profile.id);
        _authenticated = true;
        lastError = null;
        notifyListeners();
      } finally {
        _working = false;
      }
      return;
    }
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
    if (repository != null) {
      if (!_authenticated || profile.id != _profile.id) {
        throw const BackendFailure('You can edit only your own profile.');
      }
      await repository!.update(profile);
      _profile = profile;
      notifyListeners();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _profile = profile;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) async {
    if (repository != null) {
      if (AuthValidators.email(email) != null) {
        throw const BackendFailure('Enter a valid email address.');
      }
      await repository!.resetPassword(email.trim());
      return;
    }
    // Replace this simulated boundary during backend integration.
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  Future<void> signOut() async {
    if (repository != null) {
      _working = true;
      try {
        await repository!.signOut();
        await _endSession();
      } finally {
        _working = false;
      }
      return;
    }
    _authenticated = false;
    _profile = demoProfile;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
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
