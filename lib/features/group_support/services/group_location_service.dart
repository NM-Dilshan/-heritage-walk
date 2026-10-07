import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../navigation_guide/services/location_service.dart';
import 'group_tour_service.dart';

class SharedLocation {
  const SharedLocation(
    this.userId,
    this.displayName,
    this.position,
    this.updatedAt,
  );
  final String userId, displayName;
  final LatLng position;
  final DateTime updatedAt;
  bool staleAt(DateTime now) =>
      now.difference(updatedAt) > const Duration(minutes: 2) ||
      updatedAt.isAfter(now.add(const Duration(minutes: 1)));
}

abstract interface class GroupLocationRepository {
  Stream<List<SharedLocation>> watch(String groupId);
  Future<void> write(String groupId, SharedLocation location);
  Future<void> remove(String groupId, String uid);
}

/// Reads the acknowledged own write, never a cached or pending timestamp.
abstract interface class GroupLocationServerClock {
  Future<DateTime?> confirmedWriteTime(String groupId, String uid);
}

class FirestoreGroupLocationRepository
    implements GroupLocationRepository, GroupLocationServerClock {
  FirestoreGroupLocationRepository(this.db);
  final FirebaseFirestore db;
  CollectionReference<Map<String, dynamic>> _collection(String id) =>
      db.collection('groups').doc(id).collection('locations');
  @override
  Stream<List<SharedLocation>> watch(String groupId) {
    String? lastDiagnostic;
    return _collection(groupId).snapshots(includeMetadataChanges: true).map(
      // Cached snapshots are not represented as live member positions.
      (snapshot) {
        if (kDebugMode) {
          final diagnostic =
              'group=$groupId documents=${snapshot.docs.length} '
              'cache=${snapshot.metadata.isFromCache} '
              'pending=${snapshot.docs.where((d) => d.metadata.hasPendingWrites).length} '
              'documentUIDs=${snapshot.docs.map((d) => d.id).join(",")}';
          if (diagnostic != lastDiagnostic) {
            lastDiagnostic = diagnostic;
            debugPrint('[GroupTracking/Firestore] $diagnostic');
          }
        }
        return snapshot.docs
            .where(
              (d) =>
                  !snapshot.metadata.isFromCache &&
                  !d.metadata.hasPendingWrites,
            )
            .map((d) {
              final v = d.data();
              final lat = v['latitude'],
                  lon = v['longitude'],
                  time = v['updatedAt'];
              if (v['userId'] != d.id ||
                  lat is! num ||
                  lon is! num ||
                  !validCoordinates(lat.toDouble(), lon.toDouble()) ||
                  time is! Timestamp ||
                  v['displayName'] is! String) {
                return null;
              }
              return SharedLocation(
                d.id,
                v['displayName'] as String,
                LatLng(lat.toDouble(), lon.toDouble()),
                time.toDate().toUtc(),
              );
            })
            .whereType<SharedLocation>()
            .toList();
      },
    );
  }

  @override
  Future<DateTime?> confirmedWriteTime(String groupId, String uid) async {
    final snapshot = await _collection(groupId)
        .doc(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
    final time = snapshot.data()?['updatedAt'];
    return !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites &&
            time is Timestamp
        ? time.toDate().toUtc()
        : null;
  }

  @override
  Future<void> write(String groupId, SharedLocation location) =>
      _collection(groupId)
          .doc(location.userId)
          .set({
            'userId': location.userId,
            'displayName': location.displayName,
            'latitude': location.position.latitude,
            'longitude': location.position.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));
  @override
  Future<void> remove(String groupId, String uid) =>
      _collection(groupId)
          .doc(uid)
          .delete()
          .timeout(const Duration(seconds: 15));
}

class MemoryGroupLocationRepository implements GroupLocationRepository {
  final Map<String, Map<String, SharedLocation>> values = {};
  final changes = StreamController<String>.broadcast();
  @override
  Stream<List<SharedLocation>> watch(String groupId) async* {
    yield values[groupId]?.values.toList() ?? [];
    yield* changes.stream
        .where((id) => id == groupId)
        .map((_) => values[groupId]?.values.toList() ?? []);
  }

  @override
  Future<void> write(String groupId, SharedLocation location) async {
    (values[groupId] ??= {})[location.userId] = location;
    changes.add(groupId);
  }

  @override
  Future<void> remove(String groupId, String uid) async {
    values[groupId]?.remove(uid);
    changes.add(groupId);
  }

  void dispose() => changes.close();
}

/// Foreground consent session owned by the group service, never by a screen.
class GroupLocationSession extends ChangeNotifier {
  GroupLocationSession(
    this.groups,
    this.repository,
    this.location,
    this.groupId, {
    DateTime Function()? now,
    this.elapsed,
  }) : _now = now ?? DateTime.now {
    groups.addListener(_membershipChanged);
    groups.profileService.addListener(_membershipChanged);
    _listen();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _notify());
  }
  final GroupTourService groups;
  final GroupLocationRepository repository;
  final LocationService location;
  final String groupId;
  final DateTime Function() _now;
  final Duration Function()? elapsed;
  final Stopwatch _clock = Stopwatch()..start();
  Duration get _ticks => elapsed?.call() ?? _clock.elapsed;
  DateTime? _serverTime;
  Duration? _serverAnchor;
  DateTime get _freshnessNow => _serverTime == null
      ? _now().toUtc()
      : _serverTime!.add(_ticks - _serverAnchor!);
  List<SharedLocation> locations = [];
  bool sharing = false, busy = false, disposed = false;
  String? error;
  LocationState locationState = LocationState.notRequested;
  StreamSubscription<List<SharedLocation>>? _feed;
  StreamSubscription<LatLng>? _gps;
  Timer? _timer, _heartbeat, _expiry;
  static const sharingLimit = Duration(minutes: 5);
  Duration? _sharingStartedTick;
  DateTime? sharingStartedAt, sharingExpiresAt;
  Duration get remainingDuration {
    if (!sharing || _sharingStartedTick == null) return Duration.zero;
    final remaining = sharingLimit - (_ticks - _sharingStartedTick!);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void reconcileExpiry() {
    if (sharing &&
        _sharingStartedTick != null &&
        _ticks - _sharingStartedTick! >= sharingLimit) {
      unawaited(stop());
    }
  }

  bool get _expired =>
      _sharingStartedTick != null &&
      _ticks - _sharingStartedTick! >= sharingLimit;

  void _beginSharingWindow() {
    _sharingStartedTick = _ticks;
    sharingStartedAt = _freshnessNow;
    sharingExpiresAt = sharingStartedAt!.add(sharingLimit);
    _expiry = Timer(sharingLimit, () => unawaited(stop()));
  }

  int _generation = 0;
  int _feedGeneration = 0;
  String? _listeningUid, _diagnostic;
  String? _sharingUid;
  Future<void> _writes = Future.value();
  Duration? _lastWrite;
  bool get isMember {
    final g = groups.getGroupById(groupId);
    return g != null &&
        groups.isMember(g) &&
        groups.profileService.isAuthenticated;
  }

  List<SharedLocation> get freshLocations {
    if (!isMember || disposed) return [];
    final g = groups.getGroupById(groupId);
    return locations
        .where(
          (l) =>
              !l.staleAt(_freshnessNow) &&
              (g?.members.any((m) => m.id == l.userId) ?? false),
        )
        .toList();
  }

  void _notify() {
    if (disposed) return;
    if (kDebugMode) {
      final summary =
          'uid=${groups.currentUserId} group=$groupId '
          'members=${groups.getGroupById(groupId)?.members.length ?? 0} '
          'received=${locations.length} fresh=${freshLocations.length} '
          'documentUIDs=${locations.map((l) => l.userId).join(",")}';
      if (_diagnostic != summary) {
        _diagnostic = summary;
        debugPrint('[GroupTracking] $summary');
      }
    }
    notifyListeners();
  }

  void _listen() {
    if (!isMember || disposed || _listeningUid == groups.currentUserId) return;
    _cancelFeed();
    final uid = groups.currentUserId, generation = _feedGeneration;
    _listeningUid = uid;
    _feed = repository
        .watch(groupId)
        .listen(
          (value) {
            if (disposed ||
                generation != _feedGeneration ||
                !isMember ||
                groups.currentUserId != uid) {
              return;
            }
            locations = value;
            error = null;
            _notify();
          },
          onError: (Object e) {
            if (disposed || generation != _feedGeneration) return;
            locations = [];
            error = 'Group locations unavailable. Retry when connected.';
            if (kDebugMode) {
              debugPrint(
                '[GroupTracking] group=$groupId listenerError='
                '${e is FirebaseException ? e.code : e.runtimeType}',
              );
            }
            _notify();
          },
          onDone: () {
            if (disposed || generation != _feedGeneration) return;
            _feed = null;
            _listeningUid = null;
          },
        );
  }

  void _cancelFeed() {
    ++_feedGeneration;
    final feed = _feed;
    _feed = null;
    _listeningUid = null;
    unawaited(feed?.cancel());
  }

  void retry() {
    _cancelFeed();
    _listen();
  }

  void _membershipChanged() {
    if (!isMember ||
        (_sharingUid != null && _sharingUid != groups.currentUserId)) {
      unawaited(stop());
      _cancelFeed();
      locations = [];
    }
    if (_listeningUid != null && _listeningUid != groups.currentUserId) {
      _cancelFeed();
      locations = [];
    }
    _listen();
    _notify();
  }

  Future<void> start() async {
    if (!isMember || busy || sharing || disposed) return;
    final generation = ++_generation, uid = groups.currentUserId;
    busy = true;
    await _writes;
    if (disposed || !isMember || generation != _generation) {
      busy = false;
      return;
    }
    busy = true;
    error = null;
    locationState = LocationState.loading;
    _notify();
    try {
      final fix = await location.current();
      if (disposed ||
          generation != _generation ||
          !isMember ||
          uid != groups.currentUserId) {
        return;
      }
      _sharingUid = uid;
      sharing = true;
      locationState = LocationState.granted;
      _lastWrite = null;
      await _publish(fix, generation, uid);
      if (disposed || generation != _generation || !sharing) return;
      _gps = location.watch().listen(
        (p) {
          unawaited(_publish(p, generation, uid));
        },
        onError: (Object e) {
          locationState = e is LocationFailure
              ? e.state
              : LocationState.unavailable;
          error = 'Location sharing stopped. Current location unavailable.';
          unawaited(stop());
        },
      );
      // A fresh fix keeps stationary members current without uploading trails.
      _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) async {
        if (disposed || generation != _generation || !sharing) return;
        try {
          final fix = await location.current();
          await _publish(fix, generation, uid);
        } catch (_) {
          if (disposed || generation != _generation) return;
          locationState = LocationState.unavailable;
          error = 'Location sharing stopped. Current location unavailable.';
          unawaited(stop());
        }
      });
    } on LocationFailure catch (e) {
      if (disposed || generation != _generation) return;
      locationState = e.state;
      error = 'Location unavailable. Check permission and device location.';
    } catch (_) {
      if (disposed || generation != _generation) return;
      error = 'Location sharing unavailable. Check your connection.';
      await stop();
    } finally {
      if (generation == _generation) busy = false;
      _notify();
    }
  }

  Future<void> _publish(LatLng position, int generation, String uid) {
    if (_expired) {
      unawaited(stop());
      return Future.value();
    }
    if (disposed ||
        !sharing ||
        generation != _generation ||
        !isMember ||
        uid != groups.currentUserId) {
      return Future.value();
    }
    if (_lastWrite != null &&
        _ticks - _lastWrite! < const Duration(seconds: 10)) {
      return Future.value();
    }
    _lastWrite = _ticks;
    final raw = groups.profileService.profile.fullName.trim();
    final name = raw.isEmpty || raw.contains('@')
        ? 'Traveler'
        : raw.substring(0, raw.length.clamp(0, 80));
    _writes = _writes.then((_) async {
      if (disposed ||
          !sharing ||
          generation != _generation ||
          !isMember ||
          uid != groups.currentUserId) {
        return;
      }
      if (_expired) {
        unawaited(stop());
        return;
      }
      try {
        final started = _ticks;
        await repository.write(
          groupId,
          SharedLocation(uid, name, position, _now().toUtc()),
        );
        if (disposed || generation != _generation || !sharing) return;
        if (_sharingStartedTick == null) _beginSharingWindow();
        // An own server timestamp plus monotonic elapsed time avoids device
        // clock skew. Counting the full round trip conservatively ages records;
        // an old remote record is never made fresh just because it arrived now.
        if (_serverTime == null && repository is GroupLocationServerClock) {
          try {
            final time = await (repository as GroupLocationServerClock)
                .confirmedWriteTime(groupId, uid);
            if (time != null &&
                !disposed &&
                generation == _generation &&
                uid == groups.currentUserId) {
              _serverTime = time;
              _serverAnchor = started;
              sharingStartedAt = _freshnessNow.subtract(
                _ticks - _sharingStartedTick!,
              );
              sharingExpiresAt = sharingStartedAt!.add(sharingLimit);
              _notify();
            }
          } catch (_) {
            // Keep the live feed and consent flow; retry calibration next write.
          }
        }
      } catch (_) {
        error = 'Location update failed. Sharing stopped.';
        unawaited(stop());
      }
    });
    return _writes;
  }

  Future<void> stop() async {
    ++_generation;
    sharing = false;
    busy = false;
    _expiry?.cancel();
    _expiry = null;
    _sharingStartedTick = null;
    sharingStartedAt = null;
    sharingExpiresAt = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    final uid = _sharingUid;
    _sharingUid = null;
    final gps = _gps;
    _gps = null;
    _notify();
    final cancellation = gps?.cancel();
    if (uid != null) {
      _writes = _writes.then((_) async {
        try {
          await repository.remove(groupId, uid);
        } catch (_) {
          error = 'Sharing stopped. Last position may remain until stale.';
        }
      });
      await _writes;
    }
    await cancellation;
    _notify();
  }

  @override
  void dispose() {
    disposed = true;
    groups.removeListener(_membershipChanged);
    groups.profileService.removeListener(_membershipChanged);
    _timer?.cancel();
    _cancelFeed();
    _clock.stop();
    unawaited(stop());
    super.dispose();
  }
}

/// App-session owner. Screens lease state; only explicit consent starts GPS.
/// At most one selected group can publish the authenticated user's position.
class GroupLocationSharingController extends ChangeNotifier {
  GroupLocationSharingController(this.groups, {this.now, this.elapsed});
  final GroupTourService groups;
  final DateTime Function()? now;
  final Duration Function()? elapsed;
  final Map<String, GroupLocationSession> _sessions = {};
  final Map<String, int> _viewers = {};
  GroupLocationSession? _active;
  String? _requestedGroup;
  bool _disposed = false, _starting = false, _foreground = true;
  int _generation = 0;

  bool get isSharing => _active?.sharing ?? false;
  String? get activeGroupId =>
      isSharing || (_active?.busy ?? false) ? _active?.groupId : null;
  DateTime? get sharingStartedAt =>
      isSharing ? _active?.sharingStartedAt : null;
  DateTime? get sharingExpiresAt =>
      isSharing ? _active?.sharingExpiresAt : null;
  Duration get remainingDuration => _active?.remainingDuration ?? Duration.zero;

  GroupLocationSession _session(String id) => _sessions.putIfAbsent(id, () {
    final session = GroupLocationSession(
      groups,
      groups.locations,
      groups.location,
      id,
      now: now,
      elapsed: elapsed,
    );
    session.addListener(_changed);
    return session;
  });

  GroupLocationSession acquire(String groupId) {
    if (_disposed) throw StateError('Group sharing service has been disposed.');
    _viewers[groupId] = (_viewers[groupId] ?? 0) + 1;
    return _session(groupId);
  }

  void release(String groupId) {
    final count = _viewers[groupId] ?? 0;
    if (count <= 1) {
      _viewers.remove(groupId);
    } else {
      _viewers[groupId] = count - 1;
    }
    _releaseIdle(groupId);
  }

  void _releaseIdle(String id) {
    // Never dispose a ChangeNotifier from inside its own notification callback.
    scheduleMicrotask(() {
      if (_disposed || (_viewers[id] ?? 0) != 0 || _requestedGroup == id) {
        return;
      }
      final session = _sessions[id];
      if (session == null || session.sharing || session.busy) return;
      _sessions.remove(id);
      if (identical(_active, session)) _active = null;
      session.removeListener(_changed);
      session.dispose();
    });
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    for (final id in _sessions.keys.toList()) {
      _releaseIdle(id);
    }
  }

  Future<void> start(String groupId) async {
    final group = groups.getGroupById(groupId);
    if (_disposed ||
        !_foreground ||
        _starting ||
        group == null ||
        !groups.profileService.isAuthenticated ||
        !groups.isMember(group)) {
      return;
    }
    _starting = true;
    _requestedGroup = groupId;
    final generation = ++_generation, uid = groups.currentUserId;
    final target = _session(groupId), previous = _active;
    try {
      if (!identical(previous, target)) await previous?.stop();
      if (_disposed ||
          !_foreground ||
          generation != _generation ||
          uid != groups.currentUserId ||
          !target.isMember) {
        return;
      }
      _active = target;
      await target.start();
    } finally {
      _starting = false;
      _requestedGroup = null;
      _changed();
    }
  }

  Future<void> stop() async {
    ++_generation;
    final sessions = <GroupLocationSession>{
      ?_active,
      if (_requestedGroup != null && _sessions[_requestedGroup] != null)
        _sessions[_requestedGroup]!,
    };
    await Future.wait(sessions.map((session) => session.stop()));
    _changed();
  }

  void handleLifecycle(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _active?.reconcileExpiry();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive && isSharing)) {
      _foreground = false;
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    for (final session in _sessions.values) {
      session.removeListener(_changed);
      session.dispose();
    }
    _sessions.clear();
    _viewers.clear();
    _active = null;
    super.dispose();
  }
}
