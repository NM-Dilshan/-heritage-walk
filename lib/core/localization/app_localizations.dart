import 'package:flutter/foundation.dart';

import 'messages.g.dart';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

/// Standard JSON resources through Flutter Localizations. English message keys
/// retain compatibility with the existing English UI and service validation.
class AppLocalizations {
  AppLocalizations(this.locale, this.messages);
  final Locale locale;
  final Map<String, String> messages;
  static const supportedLocales = [Locale('en'), Locale('si'), Locale('ta')];
  static const delegate = _AppLocalizationDelegate();
  static AppLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);
  static String text(BuildContext context, String key) =>
      maybeOf(context)?.get(key) ?? key;
  String get(String key) {
    const suffix = ' Cloud save was not confirmed. Reload before continuing.';
    if (key.endsWith(suffix)) {
      return '${get(key.substring(0, key.length - suffix.length))} ${get(suffix.trim())}';
    }
    return messages[key] ?? key;
  }

  String format(String key, List<Object?> args) {
    var result = get(key);
    for (var i = 0; i < args.length; i++) {
      result = result.replaceAll('{$i}', '${args[i]}');
    }
    return result;
  }

  String number(num value, {int decimals = 0}) =>
      NumberFormat.decimalPatternDigits(
        locale: locale.languageCode,
        decimalDigits: decimals,
      ).format(value);
}

class _AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationDelegate();
  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(
    AppLocalizations(locale, localizedMessages[locale.languageCode]!),
  );
  @override
  bool shouldReload(_AppLocalizationDelegate old) => false;
}

/// Only application-owned labels use this widget. Names, review text, notes,
/// itinerary titles and Firestore content continue to use Flutter Text.
class UiText extends StatelessWidget {
  const UiText(
    this.message, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textScaler,
    this.textWidthBasis,
    this.args = const [],
  });
  final String message;
  final List<Object?> args;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  final TextWidthBasis? textWidthBasis;
  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.maybeOf(context)?.format(message, args) ?? _english(),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    semanticsLabel: semanticsLabel == null
        ? null
        : AppLocalizations.text(context, semanticsLabel!),
    textScaler: textScaler,
    textWidthBasis: textWidthBasis,
  );
  String _english() {
    var value = message;
    for (var i = 0; i < args.length; i++) {
      value = value.replaceAll('{$i}', '${args[i]}');
    }
    return value;
  }
}

String? localizeError(BuildContext context, String? error) =>
    error == null ? null : AppLocalizations.text(context, error);

String uiFormat(BuildContext context, String key, List<Object?> args) =>
    AppLocalizations.maybeOf(context)?.format(key, args) ??
    AppLocalizations(const Locale('en'), const {}).format(key, args);
