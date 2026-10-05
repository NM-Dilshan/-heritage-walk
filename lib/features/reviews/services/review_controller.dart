import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/backend_error.dart';
import '../../admin/services/catalog_controller.dart';
import '../models/place_review.dart';
import 'review_repository.dart';

class ReviewController extends ChangeNotifier {
  ReviewController(
    this.catalog,
    this.repository, {
    this.ownsRepository = false,
  }) {
    catalog.addListener(_sync);
    catalog.profile.addListener(_sync);
    catalog.discovery.addListener(_sync);
    _sync();
  }
  final CatalogController catalog;
  final ReviewRepository repository;
  final bool ownsRepository;
  final _feeds = <String, ReviewFeed>{};
  final _subscriptions = <String, StreamSubscription<List<PlaceReview>>>{};
  StreamSubscription<List<PlaceReview>>? _adminSub;
  String? _uid;
  bool _admin = false, _disposed = false, busy = false;
  int _generation = 0;
  List<PlaceReview> adminReviews = [];
  bool adminLoading = false;
  String? adminError;
  ReviewFeed feed(String placeId) => _feeds[placeId] ?? const ReviewFeed();
  bool get canWrite =>
      !_disposed && catalog.profile.isAuthenticated && _uid != null;
  PlaceReview? own(String placeId) =>
      feed(placeId).reviews.where((r) => r.userId == _uid).firstOrNull;
  void _sync() {
    if (_disposed) return;
    final uid = catalog.profile.isAuthenticated
        ? catalog.profile.profile.id
        : null;
    final admin = uid != null && catalog.isAdmin;
    if (uid != _uid || admin != _admin) {
      _generation++;
      _uid = uid;
      _admin = admin;
      for (final sub in _subscriptions.values) {
        sub.cancel();
      }
      _subscriptions.clear();
      _feeds.clear();
      _adminSub?.cancel();
      adminReviews = [];
      adminError = null;
      adminLoading = false;
      if (admin) reloadAdmin();
      notifyListeners();
    }
    if (uid != null) {
      for (final place in catalog.discovery.discovery.places.where(
        (p) => p.isActive,
      )) {
        ensure(place.id);
      }
    }
  }

  void ensure(String placeId) {
    if (_disposed || _uid == null || _subscriptions.containsKey(placeId)) {
      return;
    }
    _feeds[placeId] = const ReviewFeed(loading: true);
    final generation = _generation;
    _subscriptions[placeId] = repository
        .watchPlace(placeId)
        .listen(
          (reviews) {
            if (_disposed || generation != _generation) return;
            _feeds[placeId] = ReviewFeed(
              reviews: List.unmodifiable(reviews.where((r) => r.isValid)),
            );
            notifyListeners();
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            _feeds[placeId] = ReviewFeed(error: backendMessage(error));
            notifyListeners();
          },
        );
  }

  void reload(String placeId) {
    _subscriptions.remove(placeId)?.cancel();
    ensure(placeId);
    notifyListeners();
  }

  void reloadAdmin() {
    if (!_admin || _disposed) return;
    _adminSub?.cancel();
    adminLoading = true;
    adminError = null;
    notifyListeners();
    final generation = _generation;
    _adminSub = repository.watchAll().listen(
      (reviews) {
        if (_disposed || generation != _generation || !_admin) return;
        adminReviews = List.unmodifiable(reviews.where((r) => r.isValid));
        adminLoading = false;
        adminError = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed || generation != _generation || !_admin) return;
        adminReviews = [];
        adminLoading = false;
        adminError = backendMessage(error);
        notifyListeners();
      },
    );
  }

  Future<void> _operation(Future<void> Function(String uid) action) async {
    if (!canWrite) throw const BackendFailure('Sign in to manage your review.');
    if (busy) {
      throw const BackendFailure('Please wait for the current operation.');
    }
    busy = true;
    notifyListeners();
    try {
      await action(_uid!);
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> save(
    String placeId,
    int? rating,
    String comment, {
    required bool create,
  }) => _operation((uid) async {
    final message = PlaceReview.validate(rating, comment);
    if (message != null) throw BackendFailure(message);
    if (!catalog.discovery.discovery.places.any(
      (p) => p.id == placeId && p.isActive,
    )) {
      throw const BackendFailure(
        'This place is no longer available for reviews.',
      );
    }
    final review = PlaceReview(
      id: uid,
      placeId: placeId,
      userId: uid,
      userDisplayName: PlaceReview.publicName(catalog.profile.profile.fullName),
      rating: rating!,
      comment: comment.trim(),
    );
    if (create) {
      if (!await repository.create(review, uid)) {
        throw const BackendFailure(
          'You already reviewed this place. Edit your existing review.',
        );
      }
    } else {
      await repository.update(review, uid);
    }
  });
  Future<void> delete(PlaceReview review, {bool moderate = false}) =>
      _operation((uid) async {
        if (moderate ? !catalog.isAdmin : review.userId != uid) {
          throw const BackendFailure(
            'You do not have permission to delete this review.',
          );
        }
        await repository.delete(
          review.placeId,
          review.id,
          uid,
          moderate: moderate,
        );
      });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    catalog.removeListener(_sync);
    catalog.profile.removeListener(_sync);
    catalog.discovery.removeListener(_sync);
    _adminSub?.cancel();
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    if (ownsRepository && repository is InMemoryReviewRepository) {
      (repository as InMemoryReviewRepository).dispose();
    }
    super.dispose();
  }
}

class ReviewScope extends InheritedNotifier<ReviewController> {
  const ReviewScope({
    super.key,
    required ReviewController controller,
    required super.child,
  }) : super(notifier: controller);
  static ReviewController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReviewScope>()?.notifier;
  static ReviewController of(BuildContext context) => maybeOf(context)!;
}
