import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/facility.dart';
import 'location_service.dart';

enum FacilityFailure {
  offline,
  timeout,
  server,
  rateLimited,
  malformed,
  invalidQuery,
}

class FacilityException implements Exception {
  const FacilityException(this.reason);
  final FacilityFailure reason;
}

abstract class NearbyFacilityService {
  Future<List<NearbyFacility>> search({
    required LatLng origin,
    required FacilityCategory category,
    int radiusMeters = 5000,
    bool refresh = false,
  });
  void clearCache() {}
  void dispose() {}
}

class UnavailableNearbyFacilityService extends NearbyFacilityService {
  @override
  Future<List<NearbyFacility>> search({
    required LatLng origin,
    required FacilityCategory category,
    int radiusMeters = 5000,
    bool refresh = false,
  }) async => throw const FacilityException(FacilityFailure.offline);
}

class OverpassNearbyFacilityService extends NearbyFacilityService {
  OverpassNearbyFacilityService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      endpoint = endpoint ?? Uri.https('overpass-api.de', '/api/interpreter');
  final http.Client _client;
  final Uri endpoint;
  static const radii = [1000, 2000, 5000, 10000];
  final _cache = <String, (DateTime, List<Map>)>{};
  final _pending = <String, Future<List<Map>>>{};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest, _blockedUntil;
  int _generation = 0;
  bool _disposed = false;

  static String query(
    LatLng origin,
    FacilityCategory category,
    int radiusMeters,
  ) {
    if (!validCoordinates(origin.latitude, origin.longitude) ||
        !radii.contains(radiusMeters)) {
      throw const FacilityException(FacilityFailure.invalidQuery);
    }
    final tags = category.amenities.join('|');
    return '[out:json][timeout:20][maxsize:16777216];'
        'nwr(around:$radiusMeters,${origin.latitude},${origin.longitude})["amenity"~"^($tags)\$"];out body center;';
  }

  static List<NearbyFacility> decode(
    String body,
    LatLng origin,
    FacilityCategory category,
    int radiusMeters,
  ) => _facilities(_elements(body), origin, category, radiusMeters);
  static List<Map> _elements(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map || data['elements'] is! List || data['remark'] != null) {
        throw const FormatException();
      }
      return (data['elements'] as List).whereType<Map>().toList();
    } catch (_) {
      throw const FacilityException(FacilityFailure.malformed);
    }
  }

  static List<NearbyFacility> _facilities(
    List<Map> elements,
    LatLng origin,
    FacilityCategory category,
    int radius,
  ) {
    final facilities = <String, NearbyFacility>{};
    for (final element in elements) {
      final facility = NearbyFacility.fromOsm(element, origin, category);
      if (facility != null && facility.distanceMeters <= radius) {
        facilities[facility.osmId] = facility;
      }
    }
    final sorted = facilities.values.toList()
      ..sort((a, b) {
        final distance = a.distanceMeters.compareTo(b.distanceMeters);
        return distance == 0 ? a.osmId.compareTo(b.osmId) : distance;
      });
    return List.unmodifiable(sorted);
  }

  @override
  Future<List<NearbyFacility>> search({
    required LatLng origin,
    required FacilityCategory category,
    int radiusMeters = 5000,
    bool refresh = false,
  }) async {
    final body = query(origin, category, radiusMeters);
    if (_disposed) throw const FacilityException(FacilityFailure.offline);
    final key =
        '${origin.latitude},${origin.longitude}:$category:$radiusMeters';
    final cached = _cache[key];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 5)) {
      return _facilities(cached.$2, origin, category, radiusMeters);
    }
    var pending = _pending[key];
    if (pending == null) {
      final generation = _generation;
      final completer = Completer<List<Map>>();
      pending = completer.future;
      _pending[key] = pending;
      _queue = _queue.then((_) async {
        try {
          if (_disposed || generation != _generation) {
            throw const FacilityException(FacilityFailure.offline);
          }
          if (_blockedUntil != null &&
              DateTime.now().isBefore(_blockedUntil!)) {
            throw const FacilityException(FacilityFailure.rateLimited);
          }
          final elapsed = _lastRequest == null
              ? const Duration(seconds: 3)
              : DateTime.now().difference(_lastRequest!);
          if (elapsed < const Duration(seconds: 3)) {
            await Future<void>.delayed(const Duration(seconds: 3) - elapsed);
          }
          if (_disposed || generation != _generation) {
            throw const FacilityException(FacilityFailure.offline);
          }
          _lastRequest = DateTime.now();
          final response = await _client
              .post(
                endpoint,
                headers: {
                  'User-Agent': 'HeritageWalk/1.0 (lk.heritagewalk.heritage_walk; academic nearby search)',
                  'Accept': 'application/json',
                },
                body: {'data': body},
              )
              .timeout(const Duration(seconds: 25));
          if (response.statusCode == 429) {
            final seconds =
                int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
            _blockedUntil = DateTime.now().add(
              Duration(seconds: seconds.clamp(30, 86400)),
            );
            throw const FacilityException(FacilityFailure.rateLimited);
          }
          if (response.statusCode == 504) {
            throw const FacilityException(FacilityFailure.timeout);
          }
          if (response.statusCode != 200) {
            throw const FacilityException(FacilityFailure.server);
          }
          if (response.bodyBytes.length > 4 * 1024 * 1024) {
            throw const FacilityException(FacilityFailure.malformed);
          }
          final elements = _elements(response.body);
          if (!_disposed && generation == _generation) {
            if (_cache.length >= 16) _cache.remove(_cache.keys.first);
            _cache[key] = (DateTime.now(), elements);
          }
          completer.complete(elements);
        } on TimeoutException {
          completer.completeError(
            const FacilityException(FacilityFailure.timeout),
          );
        } on FacilityException catch (e) {
          completer.completeError(e);
        } catch (_) {
          completer.completeError(
            const FacilityException(FacilityFailure.offline),
          );
        } finally {
          if (identical(_pending[key], pending)) _pending.remove(key);
        }
      });
    }
    return _facilities(await pending, origin, category, radiusMeters);
  }

  @override
  void clearCache() {
    _generation++;
    _cache.clear();
    _pending.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    clearCache();
    _client.close();
  }
}
