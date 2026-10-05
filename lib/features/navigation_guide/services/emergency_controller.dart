import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/backend_error.dart';
import '../../admin/services/catalog_controller.dart';
import '../models/emergency_contact.dart';
import 'emergency_repository.dart';
import 'phone_launcher.dart';

class EmergencyController extends ChangeNotifier {
  EmergencyController(this.catalog, {this.repository, this.phone}) {
    catalog.addListener(_session);
    catalog.profile.addListener(_session);
    _session();
  }
  final CatalogController catalog;
  final EmergencyRepository? repository;
  final PhoneLauncher? phone;
  List<EmergencyContact> contacts = [], adminContacts = [];
  bool loading = false, adminLoading = false, busy = false;
  String? error, adminError;
  String? _uid;
  bool _admin = false, _disposed = false;
  int _generation = 0;
  StreamSubscription<List<EmergencyContact>>? _publicSub, _adminSub;
  bool get isCloud => repository != null;
  void _session() {
    final uid = catalog.profile.isAuthenticated
        ? catalog.profile.profile.id
        : null;
    final admin = uid != null && catalog.isAdmin;
    if (_uid == uid && _admin == admin) return;
    final accountChanged = _uid != uid;
    _uid = uid;
    _admin = admin;
    _generation++;
    _publicSub?.cancel();
    _adminSub?.cancel();
    if (accountChanged) contacts = [];
    adminContacts = [];
    error = null;
    adminError = null;
    loading = uid != null && repository != null;
    adminLoading = admin && repository != null;
    if (uid != null && repository != null) {
      reload();
      if (admin) reloadAdmin();
    }
    notifyListeners();
  }

  void reload() {
    if (_uid == null || repository == null) return;
    _publicSub?.cancel();
    loading = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    _publicSub = repository!.watch().listen(
      (values) {
        if (_disposed || generation != _generation) return;
        contacts = values
            .where(
              (c) =>
                  c.isActive &&
                  c.isVerified &&
                  EmergencyValidation.phone(c.phoneNumber) == null,
            )
            .toList();
        loading = false;
        error = null;
        notifyListeners();
      },
      onError: (Object failure) {
        if (_disposed || generation != _generation) return;
        contacts = [];
        loading = false;
        error = backendMessage(failure);
        notifyListeners();
      },
    );
  }

  void reloadAdmin() {
    if (!_admin || repository == null) return;
    _adminSub?.cancel();
    adminLoading = true;
    adminError = null;
    notifyListeners();
    final generation = _generation;
    _adminSub = repository!
        .watch(publicOnly: false)
        .listen(
          (values) {
            if (_disposed || generation != _generation || !_admin) return;
            adminContacts = values;
            adminLoading = false;
            adminError = null;
            notifyListeners();
          },
          onError: (Object failure) {
            if (_disposed || generation != _generation || !_admin) return;
            adminContacts = [];
            adminLoading = false;
            adminError = backendMessage(failure);
            notifyListeners();
          },
        );
  }

  List<EmergencyContact> search({String query = '', String category = 'All'}) =>
      adminContacts
          .where(
            (c) =>
                (category == 'All' || c.category == category) &&
                '${c.name} ${c.description} ${c.phoneNumber}'
                    .toLowerCase()
                    .contains(query.trim().toLowerCase()),
          )
          .toList();
  Future<T> _operation<T>(Future<T> Function(String uid) action) async {
    if (_disposed || !catalog.isAdmin || _uid == null || repository == null) {
      throw const BackendFailure('Admin access is required.');
    }
    if (busy) {
      throw const BackendFailure('Please wait for the current operation.');
    }
    busy = true;
    notifyListeners();
    try {
      return await action(_uid!);
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> save(
    EmergencyContact contact, {
    required bool create,
  }) => _operation((uid) async {
    if (EmergencyValidation.requiredText(contact.name) != null ||
        EmergencyValidation.requiredText(contact.description) != null ||
        !EmergencyContact.categories.contains(contact.category) ||
        EmergencyValidation.phone(contact.phoneNumber) != null ||
        EmergencyValidation.priority(contact.priority.toString()) != null) {
      throw const BackendFailure(
        'Check the contact name, category, number, description and priority.',
      );
    }
    final normalized = EmergencyContact.fromMap({
      ...contact.toMap(),
      'phoneNumber': EmergencyValidation.normalizedPhone(contact.phoneNumber),
    });
    if (create) {
      if (!await repository!.create(normalized, uid)) {
        throw const BackendFailure(
          'This contact already exists. Reload the list.',
        );
      }
    } else {
      await repository!.update(normalized, uid);
    }
  });
  Future<void> delete(String id) => _operation((_) => repository!.delete(id));
  Future<void> call(EmergencyContact contact) async {
    final current = contacts.where((c) => c.id == contact.id).firstOrNull;
    if (_disposed || current == null || phone == null) {
      throw const BackendFailure(
        'This contact is no longer available. Reload the list.',
      );
    }
    await dialContact(current, phone!);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    catalog.removeListener(_session);
    catalog.profile.removeListener(_session);
    _publicSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }
}

class EmergencyScope extends InheritedNotifier<EmergencyController> {
  const EmergencyScope({
    super.key,
    required EmergencyController controller,
    required super.child,
  }) : super(notifier: controller);
  static EmergencyController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EmergencyScope>()!.notifier!;
}
