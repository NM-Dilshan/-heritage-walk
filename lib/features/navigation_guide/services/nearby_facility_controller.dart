import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/facility.dart';
import 'facility_service.dart';
import 'location_service.dart';

/// Screen-owned, one-shot GPS searches. No GPS subscription or cloud writes.
class NearbyFacilityController extends ChangeNotifier {
  NearbyFacilityController(this.location, this.service);
  final LocationService location;
  final NearbyFacilityService service;
  FacilityCategory category = FacilityCategory.hospital;
  int radiusMeters = 5000;
  LatLng? position;
  LocationState locationState = LocationState.notRequested;
  FacilityFailure? error;
  bool loading = false, hasSearched = false, _disposed = false;
  int _queryGeneration = 0, _gpsGeneration = 0;
  List<NearbyFacility> results = const [];
  NearbyFacility? selected;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<NearbyFacility> filtered(String query) {
    final term = query.trim().toLowerCase();
    return results
        .where(
          (f) =>
              '${f.name ?? ''} ${f.address ?? ''}'.toLowerCase().contains(term),
        )
        .toList();
  }

  Future<void> locate({bool refresh = false}) async {
    if (_disposed) return;
    final generation = ++_gpsGeneration;
    _queryGeneration++;
    position = null;
    results = const [];
    selected = null;
    error = null;
    hasSearched = false;
    loading = false;
    locationState = LocationState.loading;
    _notify();
    try {
      final fix = await location.current();
      if (_disposed || generation != _gpsGeneration) return;
      if (!validCoordinates(fix.latitude, fix.longitude)) {
        throw const LocationFailure(LocationState.unavailable);
      }
      position = fix;
      locationState = LocationState.granted;
      await search(refresh: refresh);
    } on LocationFailure catch (e) {
      if (generation == _gpsGeneration) locationState = e.state;
    } catch (_) {
      if (generation == _gpsGeneration) {
        locationState = LocationState.unavailable;
      }
    }
    _notify();
  }

  Future<void> selectCategory(FacilityCategory value) async {
    if (category == value) return;
    category = value;
    await search();
  }

  Future<void> selectRadius(int value) async {
    if (!OverpassNearbyFacilityService.radii.contains(value) ||
        radiusMeters == value) {
      return;
    }
    radiusMeters = value;
    await search();
  }

  Future<void> search({bool refresh = false}) async {
    final generation = ++_queryGeneration;
    results = const [];
    selected = null;
    error = null;
    hasSearched = false;
    if (position == null || _disposed) {
      _notify();
      return;
    }
    loading = true;
    _notify();
    try {
      final found = await service.search(
        origin: position!,
        category: category,
        radiusMeters: radiusMeters,
        refresh: refresh,
      );
      if (!_disposed && generation == _queryGeneration) {
        results = found;
        hasSearched = true;
      }
    } on FacilityException catch (e) {
      if (generation == _queryGeneration) error = e.reason;
    } catch (_) {
      if (generation == _queryGeneration) error = FacilityFailure.offline;
    }
    if (generation == _queryGeneration) loading = false;
    _notify();
  }

  void select(NearbyFacility? facility) {
    if (facility == null || results.any((f) => f.osmId == facility.osmId)) {
      selected = facility;
      _notify();
    }
  }

  void suspend() {
    _gpsGeneration++;
    _queryGeneration++;
    loading = false;
    if (locationState == LocationState.loading) {
      locationState = LocationState.unavailable;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _gpsGeneration++;
    _queryGeneration++;
    super.dispose();
  }
}
