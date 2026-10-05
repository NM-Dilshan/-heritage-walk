abstract final class AuthValidators {
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? name(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Full name is required';
    if (value!.trim().length < 2) return 'Enter at least 2 characters';
    if (value.trim().length > 60) return 'Use no more than 60 characters';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return value.length < 6 ? 'Use at least 6 characters' : null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[0-9\s()\-]+$').hasMatch(text) ||
        digits.length < 7 ||
        digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? bio(String? value) =>
      (value?.length ?? 0) > 150 ? 'Use no more than 150 characters' : null;
}
