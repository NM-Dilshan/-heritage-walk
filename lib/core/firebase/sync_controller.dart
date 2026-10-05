import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend_error.dart';
import 'data_repository.dart';

bool cloudEqual(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && cloudEqual(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (index) => index,
        ).every((index) => cloudEqual(a[index], b[index]));
  }
  return a == b;
}

class CollectionBinding {
  CollectionBinding(this.name, this.service, this.read, this.restore);
  final String name;
  final ChangeNotifier service;
  final CloudDocuments Function() read;
  final void Function(CloudDocuments) restore;
  CloudDocuments baseline = {};
  StreamSubscription<CloudDocuments>? subscription;
  VoidCallback? listener;
  bool hydrating = false;
  int writes = 0;
  Future<void> tail = Future.value();
  void accept(CloudDocuments documents) {
    hydrating = true;
    try {
      restore(documents);
      baseline = read();
    } finally {
      hydrating = false;
    }
  }

  void stop() {
    if (listener != null) service.removeListener(listener!);
    listener = null;
    unawaited(subscription?.cancel());
    subscription = null;
  }
}

/// Bridges the existing synchronous view models to durable repositories.
/// Restores never trigger uploads; logout only detaches and clears local caches.
class SyncController extends ChangeNotifier {
  SyncController(this.repository, this.bindings, this.clearLocal);
  final DataRepository repository;
  final List<CollectionBinding> bindings;
  final VoidCallback clearLocal;
  String? _uid;
  int _generation = 0, _pending = 0;
  bool loading = false;
  String? error;
  bool get busy => loading || _pending > 0;
  Future<void> start(String uid) async {
    stop();
    _uid = uid;
    final generation = _generation;
    clearLocal();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final records = await Future.wait(
        bindings.map((binding) => repository.load(uid, binding.name)),
      ).timeout(const Duration(seconds: 20));
      if (generation != _generation) return;
      for (var index = 0; index < bindings.length; index++) {
        final binding = bindings[index];
        binding.accept(records[index]);
        binding.listener = () => _changed(binding, uid, generation);
        binding.service.addListener(binding.listener!);
        binding.subscription = repository
            .watch(uid, binding.name)
            .listen(
              (documents) {
                if (generation == _generation &&
                    binding.writes == 0 &&
                    error == null) {
                  binding.accept(documents);
                }
              },
              onError: (Object failure) {
                if (generation == _generation) {
                  error = backendMessage(failure);
                  notifyListeners();
                }
              },
            );
      }
    } catch (failure) {
      if (generation == _generation) error = backendMessage(failure);
      rethrow;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _changed(CollectionBinding binding, String uid, int generation) {
    if (binding.hydrating || generation != _generation) return;
    final after = binding.read(), before = binding.baseline;
    if (cloudEqual(before, after)) return;
    if (error != null) {
      binding.accept(before);
      return;
    }
    binding.baseline = after;
    binding.writes++;
    _pending++;
    notifyListeners();
    binding.tail = binding.tail.then((_) async {
      if (generation != _generation) return;
      try {
        await repository
            .write(uid, binding.name, before, after)
            .timeout(const Duration(seconds: 20));
        final latest = await repository
            .load(uid, binding.name)
            .timeout(const Duration(seconds: 20));
        if (generation == _generation && binding.writes == 1) {
          binding.accept(latest);
        }
      } catch (failure) {
        if (generation == _generation) {
          binding.accept(before);
          error =
              '${backendMessage(failure)} Cloud save was not confirmed. Reload before continuing.';
        }
      } finally {
        if (generation == _generation) {
          binding.writes--;
          _pending--;
          notifyListeners();
        }
      }
    });
  }

  Future<void> flush() => Future.wait(bindings.map((binding) => binding.tail));
  Future<void> retry() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await start(uid);
    } catch (_) {
      /* Error is displayed by the status view. */
    }
  }

  Future<T> operation<T>(Future<T> Function() action) async {
    final generation = _generation;
    _pending++;
    notifyListeners();
    try {
      return await action().timeout(const Duration(seconds: 20));
    } finally {
      if (generation == _generation) {
        _pending--;
        notifyListeners();
      }
    }
  }

  void stop() {
    _generation++;
    _uid = null;
    for (final binding in bindings) {
      binding.stop();
      binding.writes = 0;
      binding.tail = Future.value();
    }
    _pending = 0;
    loading = false;
    error = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
