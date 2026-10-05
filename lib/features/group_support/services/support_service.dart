import 'package:flutter/material.dart';

import '../models/support_request.dart';

class SupportService extends ChangeNotifier {
  final Map<String, SupportRequest> _requests = {};
  int _sequence = 0;
  String Function()? idFactory;
  void restore(Iterable<SupportRequest> requests) {
    _requests.clear();
    for (final request in requests) {
      _requests[request.id] = request;
    }
    notifyListeners();
  }

  List<SupportRequest> getSupportRequests() =>
      List.unmodifiable(_requests.values.toList().reversed);
  SupportRequest? getById(String id) => _requests[id];

  static String? validateText(String? value, String label, int maximum) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    if (value.trim().length > maximum) {
      return '$label must be $maximum characters or fewer';
    }
    return null;
  }

  void _validate(String subject, String message) {
    final error =
        validateText(subject, 'Subject', 100) ??
        validateText(message, 'Message', 1000);
    if (error != null) throw ArgumentError(error);
  }

  SupportRequest createSupportRequest({
    required String subject,
    required String message,
    required SupportCategory category,
  }) {
    _validate(subject, message);
    final now = DateTime.now();
    final request = SupportRequest(
      id: idFactory?.call() ?? 'support-${++_sequence}',
      subject: subject.trim(),
      message: message.trim(),
      category: category,
      status: SupportStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    _requests[request.id] = request;
    notifyListeners();
    return request;
  }

  SupportRequest _require(String id) =>
      _requests[id] ?? (throw StateError('Support request is unavailable'));
  void updateSupportRequest(
    String id, {
    required String subject,
    required String message,
    required SupportCategory category,
  }) {
    final request = _require(id);
    _validate(subject, message);
    _requests[id] = request.copyWith(
      subject: subject.trim(),
      message: message.trim(),
      category: category,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void markResolved(String id, {bool resolved = true}) {
    _requests[id] = _require(id).copyWith(
      status: resolved ? SupportStatus.resolved : SupportStatus.open,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void deleteSupportRequest(String id) {
    _require(id);
    _requests.remove(id);
    notifyListeners();
  }

  void clear() {
    _requests.clear();
    notifyListeners();
  }
}

class SupportScope extends InheritedNotifier<SupportService> {
  const SupportScope({
    super.key,
    required SupportService service,
    required super.child,
  }) : super(notifier: service);
  static SupportService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SupportScope>()!.notifier!;
}
