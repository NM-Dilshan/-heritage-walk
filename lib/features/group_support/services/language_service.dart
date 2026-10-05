import 'package:flutter/material.dart';

class LanguageOption {
  const LanguageOption(this.code, this.name, this.nativeName, this.preview);
  final String code, name, nativeName, preview;
}

class LanguageService extends ChangeNotifier {
  static const _languages = [
    LanguageOption('en', 'English', 'English', 'Explore Sri Lanka'),
    LanguageOption('si', 'Sinhala', 'සිංහල', 'ශ්‍රී ලංකාව ගවේෂණය කරන්න'),
    LanguageOption('ta', 'Tamil', 'தமிழ்', 'இலங்கையை ஆராயுங்கள்'),
  ];
  String _selectedLanguageCode = 'en';
  String get selectedLanguageCode => _selectedLanguageCode;
  List<LanguageOption> getAvailableLanguages() => _languages;
  LanguageOption getSelectedLanguage() => _languages.singleWhere(
    (language) => language.code == _selectedLanguageCode,
  );
  void setLanguage(String code) {
    if (!_languages.any((language) => language.code == code)) {
      throw ArgumentError('Unsupported language');
    }
    if (code == _selectedLanguageCode) return;
    _selectedLanguageCode = code;
    notifyListeners();
  }
}

class LanguageScope extends InheritedNotifier<LanguageService> {
  const LanguageScope({
    super.key,
    required LanguageService service,
    required super.child,
  }) : super(notifier: service);
  static LanguageService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()!.notifier!;
}
