import 'package:firebase_core/firebase_core.dart';

class BackendFailure implements Exception {
  const BackendFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String backendMessage(Object error) {
  if (error is BackendFailure) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'user-disabled' => 'This account is disabled. Please contact support.',
      'email-already-in-use' =>
        'An account already uses this email. Please sign in.',
      'account-exists-with-different-credential' ||
      'credential-already-in-use' ||
      'provider-already-linked' => 'Please sign in using your existing account method. Linking another provider requires secure account verification.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'network-request-failed' || 'unavailable' =>
        'Unable to connect. Check your connection and try again.',
      'permission-denied' =>
        'You do not have permission to access this data. Please sign in again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'requires-recent-login' =>
        'Please sign in again before changing account details.',
      _ => 'Unable to complete the request. Please try again.',
    };
  }
  return 'Unable to complete the request. Please try again.';
}
