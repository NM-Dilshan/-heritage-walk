import 'package:flutter/material.dart';

import 'dart:async';

import '../../../core/firebase/account_repository.dart';
import '../../../core/firebase/backend_error.dart';
import '../../../core/firebase/social_auth.dart';
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

  /// Foreground sharing cleanup must run while Firebase still owns this UID.
  Future<void> Function()? beforeSignOut;
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

  void _checkIdle() {
    if (_working) {
      throw const BackendFailure(
        'An authentication request is already in progress. Please wait.',
      );
    }
  }

  Future<SocialResult> signInSocial(SocialProvider provider) async {
    await ready;
    _checkIdle();
    final account = repository;
    if (account is! SocialAccountRepository) {
      throw const BackendFailure(
        'Social sign-in is unavailable in this preview.',
      );
    }
    _working = true;
    try {
      final result = await (account as SocialAccountRepository).signInSocial(
        provider,
      );
      if (result == SocialResult.cancelled) return result;
      final profile = await account!.restore();
      if (profile == null) {
        throw const BackendFailure(
          'Unable to complete the request. Please try again.',
        );
      }
      if (_disposed) return SocialResult.cancelled;
      _profile = profile;
      await onSession?.call(profile.id);
      if (!_disposed) {
        _authenticated = true;
        lastError = null;
        notifyListeners();
      }
      return result;
    } catch (error) {
      await account!.signOut();
      await _endSession();
      rethrow;
    } finally {
      _working = false;
    }
  }

  Future<void> signIn(String email, {String password = ''}) async {
    await ready;
    _checkIdle();
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
    await ready;
    _checkIdle();
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
    await ready;
    _checkIdle();
    final validation = AuthValidators.email(email);
    if (validation != null) throw BackendFailure(validation);
    _working = true;
    try {
      if (repository != null) {
        if (AuthValidators.email(email) != null) {
          throw const BackendFailure('Enter a valid email address.');
        }
        await repository!.resetPassword(email.trim());
        return;
      }
      // Replace this simulated boundary during backend integration.
      await Future<void>.delayed(const Duration(milliseconds: 450));
    } finally {
      _working = false;
    }
  }

  Future<void> signOut() async {
    await ready;
    _checkIdle();
    if (repository != null) {
      _working = true;
      try {
        await beforeSignOut?.call();
        await repository!.signOut();
        await _endSession();
      } finally {
        _working = false;
      }
      return;
    }
    await beforeSignOut?.call();
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
