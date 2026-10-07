import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/backend_error.dart';
import '../../auth_profile/services/profile_service.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/services/discovery_service.dart';
import 'place_repository.dart';
import 'place_validation.dart';

class CatalogController extends ChangeNotifier {
  CatalogController(
    this.profile,
    this.discovery, {
    this.repository,
    this.roles,
  }) {
    profile.addListener(_sessionChanged);
    if (repository != null) discovery.discovery.replaceCatalog(const []);
    _sessionChanged();
  }
  final ProfileService profile;
  final DiscoveryState discovery;
  final PlaceRepository? repository;
  final RoleRepository? roles;
  StreamSubscription<String>? _roleSub;
  StreamSubscription<List<HeritagePlace>>? _catalogSub, _adminSub;
  String? _uid;
  bool isAdmin = false, loading = false, busy = false;
  String? error;
  List<HeritagePlace> places = [];
  int _generation = 0;
  bool _disposed = false;
  void _sessionChanged() {
    final uid = profile.isAuthenticated ? profile.profile.id : null;
    if (uid == _uid) return;
    _uid = uid;
    _generation++;
    _roleSub?.cancel();
    _catalogSub?.cancel();
    _adminSub?.cancel();
    isAdmin = false;
    places = [];
    error = null;
    loading = false;
    if (repository != null) discovery.discovery.replaceCatalog(const []);
    if (uid != null) {
      _watchActive();
      if (roles != null) {
        final generation = _generation;
        _roleSub = roles!
            .watch(uid)
            .listen(
              (role) {
                if (generation == _generation) _setRole(role);
              },
              onError: (_) {
                if (generation == _generation) _setRole('user');
              },
            );
      } else {
        _setRole(profile.profile.role);
      }
    }
    notifyListeners();
  }

  void _watchActive() {
    if (repository == null || _uid == null) return;
    discovery.discovery.setCatalogStatus(loading: true);
    _catalogSub?.cancel();
    final generation = _generation;
    _catalogSub = repository!.watch().listen(
      (items) {
        if (_disposed || generation != _generation) return;
        discovery.discovery.replaceCatalog(items.where((p) => p.isActive));
        discovery.favorites.reconcile(discovery.discovery.places);
      },
      onError: (Object failure) {
        if (!_disposed && generation == _generation) {
          discovery.discovery.replaceCatalog(const []);
          discovery.discovery.setCatalogStatus(error: backendMessage(failure));
        }
      },
    );
  }

  void _setRole(String role) {
    if (_disposed) return;
    final allowed = _uid != null && role == 'admin';
    if (allowed == isAdmin) return;
    isAdmin = allowed;
    _adminSub?.cancel();
    places = [];
    error = null;
    loading = allowed && repository != null;
    notifyListeners();
    if (allowed) reloadAdmin();
  }

  void retryCatalog() => _watchActive();
  void reloadAdmin() {
    if (!isAdmin || repository == null) return;
    _adminSub?.cancel();
    loading = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    _adminSub = repository!
        .watch(activeOnly: false)
        .listen(
          (items) {
            if (_disposed || !isAdmin || generation != _generation) return;
            places = items;
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object failure) {
            if (_disposed || generation != _generation) return;
            places = [];
            loading = false;
            error = backendMessage(failure);
            notifyListeners();
          },
        );
  }

  List<HeritagePlace> search({String query = '', String category = 'All'}) =>
      places
          .where(
            (p) =>
                (category == 'All' || p.category == category) &&
                '${p.name} ${p.city} ${p.district} ${p.category}'
                    .toLowerCase()
                    .contains(query.trim().toLowerCase()),
          )
          .toList();
  Future<T> _operation<T>(Future<T> Function(String uid) action) async {
    if (_disposed || !isAdmin || _uid == null || repository == null) {
      throw const BackendFailure('Admin access is required.');
    }
    if (busy) {
      throw const BackendFailure('Please wait for the current operation.');
    }
    busy = true;
    notifyListeners();
    try {
      final future = action(_uid!);
      return await future.timeout(const Duration(seconds: 20));
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> save(HeritagePlace place, {required bool create}) => _operation((
    uid,
  ) async {
    for (final value in [
      place.name,
      place.category,
      place.description,
      place.city,
      place.district,
    ]) {
      if (PlaceValidation.requiredText(value) != null) {
        throw const BackendFailure('Complete the required place information.');
      }
    }
    if (!DiscoveryService.categories.skip(1).contains(place.category) ||
        PlaceValidation.image(place.imagePath) != null ||
        PlaceValidation.coordinate(place.latitude?.toString(), 90) != null ||
        PlaceValidation.coordinate(place.longitude?.toString(), 180) != null) {
      throw const BackendFailure(
        'Check the category, image reference and coordinates.',
      );
    }
    if (_disposed ||
        !isAdmin ||
        !profile.isAuthenticated ||
        profile.profile.id != uid) {
      throw const BackendFailure('Admin access is required.');
    }
    if (create) {
      if (!await repository!.create(place, uid)) {
        throw const BackendFailure(
          'This place already exists. Reload the catalog.',
        );
      }
    } else {
      await repository!.update(place, uid);
    }
  });
  Future<void> delete(String id) => _operation((_) => repository!.delete(id));
  Future<({int created, int skipped})> seed() => _operation((uid) async {
    var created = 0, skipped = 0;
    for (final place in DiscoveryService.localPlaces) {
      if (!isAdmin || _uid != uid) {
        throw const BackendFailure('Admin access is required.');
      }
      if (await repository!.create(place, uid)) {
        created++;
      } else {
        skipped++;
      }
    }
    return (created: created, skipped: skipped);
  });
  Future<PlaceImportResult> importPredefined() => _operation((uid) async {
    if (!isAdmin || !profile.isAuthenticated || profile.profile.id != uid) {
      throw const BackendFailure('Admin access is required.');
    }
    return repository!.importPredefined(uid);
  });

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    profile.removeListener(_sessionChanged);
    _roleSub?.cancel();
    _catalogSub?.cancel();
    _adminSub?.cancel();
    super.dispose();
  }
}

class CatalogScope extends InheritedNotifier<CatalogController> {
  const CatalogScope({
    super.key,
    required CatalogController controller,
    required super.child,
  }) : super(notifier: controller);
  static CatalogController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CatalogScope>()!.notifier!;
}
