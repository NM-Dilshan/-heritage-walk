import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'backend_error.dart';

enum SocialProvider { google, facebook }

/// null means a normal user cancellation. Never persist provider login flags.
abstract interface class SocialCredentialSource {
  Future<AuthCredential?> credential(SocialProvider provider);
  Future<void> signOut({Set<SocialProvider> providers = const {}});
}

abstract interface class SocialAccountRepository {
  Future<SocialResult> signInSocial(SocialProvider provider);
}

enum SocialResult { authenticated, cancelled }

class DeviceSocialCredentialSource implements SocialCredentialSource {
  DeviceSocialCredentialSource({
    this.google,
    this.facebook,
    Future<bool> Function()? facebookConfigured,
  }) : _configured = facebookConfigured;
  final GoogleSignIn? google;
  final FacebookAuth? facebook;
  final Future<bool> Function()? _configured;
  Future<void>? _injectedGoogleReady;
  GoogleSignIn get _googleSdk => google ?? GoogleSignIn.instance;
  FacebookAuth get _facebookSdk => facebook ?? FacebookAuth.instance;
  static Future<void>? _googleReady;
  static const _configuration = MethodChannel(
    'heritagewalk/auth_configuration',
  );

  Future<bool> _facebookConfigured() async => _configured != null
      ? _configured()
      : !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            await _configuration.invokeMethod<bool>('facebookConfigured') ==
                true;

  @override
  Future<AuthCredential?> credential(SocialProvider provider) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const BackendFailure(
        'Social sign-in is currently supported on Android.',
      );
    }
    if (provider == SocialProvider.google) {
      try {
        if (google == null) {
          await (_googleReady ??= _googleSdk.initialize());
        } else {
          await (_injectedGoogleReady ??= _googleSdk.initialize());
        }
        final account = await _googleSdk.authenticate();
        final token = account.authentication.idToken;
        if (token == null || token.isEmpty) {
          throw const BackendFailure(
            'Unable to sign in with Google. Please try again.',
          );
        }
        return GoogleAuthProvider.credential(idToken: token);
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) return null;
        throw const BackendFailure(
          'Unable to sign in with Google. Please try again.',
        );
      }
    }
    if (!await _facebookConfigured()) {
      throw const BackendFailure(
        'Facebook sign-in requires administrator setup. Please use email or Google for now.',
      );
    }
    try {
      final result = await _facebookSdk.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status == LoginStatus.cancelled) return null;
      final token = result.accessToken;
      if (result.status != LoginStatus.success ||
          token == null ||
          token.tokenString.isEmpty) {
        throw const BackendFailure(
          'Unable to sign in with Facebook. Please try again.',
        );
      }
      return FacebookAuthProvider.credential(token.tokenString);
    } on PlatformException {
      throw const BackendFailure(
        'Unable to sign in with Facebook. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut({Set<SocialProvider> providers = const {}}) async {
    // Ordinary logout clears local state; it does not disconnect/revoke Google.
    if (_googleReady != null ||
        _injectedGoogleReady != null ||
        providers.contains(SocialProvider.google)) {
      try {
        if (google == null) {
          await (_googleReady ??= _googleSdk.initialize());
        } else {
          await (_injectedGoogleReady ??= _googleSdk.initialize());
        }
        await _googleSdk.signOut();
      } catch (_) {
        /* Firebase logout remains authoritative. */
      }
    }
    try {
      if (await _facebookConfigured()) await _facebookSdk.logOut();
    } catch (_) {
      /* A missing provider cannot prevent Firebase logout. */
    }
  }
}
