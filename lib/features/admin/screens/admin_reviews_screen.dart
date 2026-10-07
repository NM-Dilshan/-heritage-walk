import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../reviews/services/review_controller.dart';
import '../../reviews/widgets/review_widgets.dart';
import '../../reviews/models/place_review.dart';
import '../services/catalog_controller.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});
  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  String _query = '', _place = 'All';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_place != 'All' &&
        !ReviewScope.of(context).adminReviews.any((r) => r.placeId == _place)) {
      _place = 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ReviewScope.of(context),
        catalog = CatalogScope.of(context);
    String name(String id) =>
        catalog.places.where((p) => p.id == id).firstOrNull?.name ??
        'Unavailable place';
    final ids = controller.adminReviews.map((r) => r.placeId).toSet().toList()
      ..sort((a, b) => name(a).compareTo(name(b)));
    final selectedPlace = ids.contains(_place) ? _place : 'All';
    final reviews = controller.adminReviews.where(
      (r) =>
          (selectedPlace == 'All' || r.placeId == selectedPlace) &&
          '${name(r.placeId)} ${r.userDisplayName} ${r.comment} ${r.rating}'
              .toLowerCase()
              .contains(_query.trim().toLowerCase()),
    );
    return DiscoveryLayout(
      title: 'Review Moderation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: AppLocalizations.text(context, 'Search reviews'),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedPlace),
            initialValue: selectedPlace,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.text(context, 'Place filter'),
            ),
            items: [
              const DropdownMenuItem(value: 'All', child: UiText('All places')),
              for (final id in ids)
                DropdownMenuItem(
                  value: id,
                  child: Text(name(id), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _place = value ?? 'All'),
          ),
          if (controller.adminLoading)
            const Center(child: CircularProgressIndicator()),
          if (controller.adminError != null) ...[
            Text(controller.adminError!),
            TextButton(
              onPressed: controller.reloadAdmin,
              child: const UiText('Reload reviews'),
            ),
          ],
          if (!controller.adminLoading &&
              controller.adminError == null &&
              reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: UiText('No reviews match this view.'),
            ),
          for (final review in reviews)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name(review.placeId),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(PlaceReview.publicName(review.userDisplayName)),
                    UiText("{0}/5 stars", args: [review.rating]),
                    Text(review.comment),
                    if (review.createdAt != null)
                      Text(reviewDate(review.createdAt!)),
                    TextButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => confirmReviewDelete(
                              context,
                              review,
                              moderate: true,
                            ),
                      icon: const Icon(Icons.delete_outline),
                      label: const UiText('Delete Review'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
