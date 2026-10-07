import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_info.dart';
import 'location_service.dart';

enum RouteFailure { offline, timeout, server, malformed, noRoute }

class RoutingException implements Exception {
  const RoutingException(this.reason);
  final RouteFailure reason;
}

class RoutedPath {
  const RoutedPath(this.points, this.distanceMeters, this.durationSeconds);
  final List<LatLng> points;
  final double distanceMeters, durationSeconds;
  static RoutedPath decode(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['code'] == 'NoRoute') {
        throw const RoutingException(RouteFailure.noRoute);
      }
      if (data['code'] != 'Ok') {
        throw const RoutingException(RouteFailure.server);
      }
      final routes = data['routes'] as List;
      if (routes.isEmpty) throw const RoutingException(RouteFailure.noRoute);
      final route = routes.first as Map;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      final geometry = route['geometry'] as Map;
      if (geometry['type'] != 'LineString' ||
          !distance.isFinite ||
          !duration.isFinite ||
          distance < 0 ||
          duration < 0) {
        throw const FormatException();
      }
      final points = (geometry['coordinates'] as List).map((p) {
        final lat = (p[1] as num).toDouble(), lon = (p[0] as num).toDouble();
        if (!validCoordinates(lat, lon)) throw const FormatException();
        return LatLng(lat, lon);
      }).toList();
      if (points.length < 2) throw const FormatException();
      return RoutedPath(List.unmodifiable(points), distance, duration);
    } on RoutingException {
      rethrow;
    } catch (_) {
      throw const RoutingException(RouteFailure.malformed);
    }
  }
}

abstract interface class RoutingService {
  Future<RoutedPath> route(LatLng start, LatLng destination, TravelMode mode);
}

class FossgisRoutingService implements RoutingService {
  FossgisRoutingService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  DateTime? _lastRequest;
  Future<void> _queue = Future.value();
  final Map<String, (DateTime, RoutedPath)> _cache = {};
  @override
  Future<RoutedPath> route(
    LatLng start,
    LatLng destination,
    TravelMode mode,
  ) async {
    final key =
        '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}:${destination.latitude},${destination.longitude}:$mode';
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 5)) {
      return cached.$2;
    }
    final completer = Completer<RoutedPath>();
    _queue = _queue.then((_) async {
      try {
        final elapsed = _lastRequest == null
            ? const Duration(seconds: 2)
            : DateTime.now().difference(_lastRequest!);
        if (elapsed < const Duration(seconds: 2)) {
          await Future<void>.delayed(const Duration(seconds: 2) - elapsed);
        }
        _lastRequest = DateTime.now();
        final profile = mode == TravelMode.walking ? 'foot' : 'car';
        final uri = Uri.https(
          'routing.openstreetmap.de',
          '/routed-$profile/route/v1/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}',
          {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
        );
        final response = await _client
            .get(
              uri,
              headers: {
                'User-Agent': 'HeritageWalk/1.0 (lk.heritagewalk.heritage_walk; academic route preview)',
              },
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw const RoutingException(RouteFailure.server);
        }
        final result = RoutedPath.decode(response.body);
        if (_cache.length >= 20) _cache.remove(_cache.keys.first);
        _cache[key] = (DateTime.now(), result);
        completer.complete(result);
      } on TimeoutException {
        completer.completeError(const RoutingException(RouteFailure.timeout));
      } on RoutingException catch (error) {
        completer.completeError(error);
      } catch (_) {
        completer.completeError(const RoutingException(RouteFailure.offline));
      }
    });
    return completer.future;
  }

  void dispose() => _client.close();
}
