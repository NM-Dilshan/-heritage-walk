import 'package:cloud_firestore/cloud_firestore.dart';

/// Accept SDK timestamps and legacy ISO/local values without unsafe casts.
abstract final class CloudValues {
  static String text(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;
  static bool boolean(Object? value, [bool fallback = false]) =>
      value is bool ? value : fallback;
  static double? number(Object? value) =>
      value is num ? value.toDouble() : null;
  static DateTime date(Object? value) =>
      optionalDate(value) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  static DateTime? optionalDate(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc(),
    DateTime date => date,
    String text => DateTime.tryParse(text),
    _ => null,
  };
  static Map<String, Object?> map(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
        }
      : {};
  static List<Object?> list(Object? value) => value is List ? value : [];
  static T enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    T fallback,
  ) => values.where((item) => item.name == value).firstOrNull ?? fallback;
  static Map<String, Object?> normalize(Map<String, Object?> source) => {
    for (final entry in source.entries) entry.key: _normalize(entry.value),
  };
  static Object? _normalize(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc().toIso8601String(),
    DateTime date => date.toIso8601String(),
    Map mapValue => normalize(map(mapValue)),
    List listValue => listValue.map(_normalize).toList(),
    _ => value,
  };
  static Map<String, dynamic> timestamps(Map<String, Object?> source) => {
    for (final entry in source.entries)
      entry.key:
          ['createdAt', 'updatedAt', 'lastUpdated'].contains(entry.key) &&
              optionalDate(entry.value) != null
          ? Timestamp.fromDate(date(entry.value))
          : entry.value is Map
          ? timestamps(map(entry.value))
          : entry.value is List
          ? (entry.value as List)
                .map((item) => item is Map ? timestamps(map(item)) : item)
                .toList()
          : entry.value,
  };
}
