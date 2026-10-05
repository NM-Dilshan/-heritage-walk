import 'package:flutter/material.dart';

import '../../../core/firebase/backend_error.dart';
import '../../admin/services/catalog_controller.dart';
import '../models/place_review.dart';
import '../services/review_controller.dart';

class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.placeId});
  final String placeId;
  @override
  Widget build(BuildContext context) {
    final feed =
        ReviewScope.maybeOf(context)?.feed(placeId) ?? const ReviewFeed();
    return Text(
      feed.loading
          ? 'Ratings loading?'
          : feed.error != null
          ? 'Ratings unavailable'
          : feed.reviewCount == 0
          ? 'No reviews'
          : '? ${feed.averageRating.toStringAsFixed(1)} (${feed.reviewCount})',
      semanticsLabel: feed.reviewCount > 0
          ? 'Average rating ${feed.averageRating.toStringAsFixed(1)} out of 5 from ${feed.reviewCount} reviews'
          : null,
    );
  }
}

class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key, required this.placeId});
  final String placeId;
  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ReviewScope.of(context).ensure(widget.placeId);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ReviewScope.of(context);
    final feed = controller.feed(widget.placeId),
        own = controller.own(widget.placeId);
    final available = CatalogScope.of(context).discovery.discovery.places
        .any((p) => p.id == widget.placeId && p.isActive);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          'Reviews & Ratings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        RatingSummary(placeId: widget.placeId),
        if (feed.reviewCount > 0)
          Semantics(
            label: '${feed.averageRating.toStringAsFixed(1)} stars out of 5',
            child: ExcludeSemantics(
              child: Text(
                List.generate(
                  5,
                  (i) => i < feed.averageRating.round() ? '?' : '?',
                ).join(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        if (feed.loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (feed.error != null) ...[
          Text(feed.error!),
          TextButton(
            onPressed: () => controller.reload(widget.placeId),
            child: const Text('Reload reviews'),
          ),
        ],
        if (!feed.loading && feed.error == null && feed.reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No reviews yet. Be the first to share your experience.',
            ),
          ),
        if (!controller.canWrite) const Text('Sign in to write a review.'),
        if (controller.canWrite &&
            available &&
            !feed.loading &&
            feed.error == null)
          OutlinedButton.icon(
            onPressed: controller.busy
                ? null
                : () => editReview(context, widget.placeId, own),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(own == null ? 'Write a Review' : 'Edit Review'),
          ),
        if (!available)
          const Text('This place is unavailable for new or edited reviews.'),
        for (final review in feed.reviews)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PlaceReview.publicName(review.userDisplayName),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${'?' * review.rating}${'?' * (5 - review.rating)} ? ${review.rating}/5',
                    semanticsLabel: '${review.rating} out of 5 stars',
                  ),
                  const SizedBox(height: 8),
                  Text(review.comment),
                  if (review.createdAt != null)
                    Text(
                      reviewDate(review.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (own?.id == review.id && controller.canWrite)
                    TextButton.icon(
                      onPressed: controller.busy
                          ? null
                          : () => confirmReviewDelete(context, review),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Review'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String reviewDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

Future<void> editReview(
  BuildContext context,
  String placeId,
  PlaceReview? existing,
) => showDialog<void>(
  context: context,
  builder: (_) => _ReviewForm(placeId: placeId, existing: existing),
);

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.placeId, this.existing});
  final String placeId;
  final PlaceReview? existing;
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _form = GlobalKey<FormState>();
  late final _comment = TextEditingController(
    text: widget.existing?.comment ?? '',
  );
  late int? _rating = widget.existing?.rating;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ReviewScope.of(context).save(
        widget.placeId,
        _rating,
        _comment.text,
        create: widget.existing == null,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = backendMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.existing == null ? 'Write a Review' : 'Edit Review'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _rating,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Rating'),
                items: [
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text('$i ${i == 1 ? 'star' : 'stars'}'),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _rating = value),
                validator: (value) =>
                    value == null ? 'Choose a rating from 1 to 5.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _comment,
                enabled: !_saving,
                maxLines: 4,
                maxLength: PlaceReview.maxCommentLength,
                decoration: const InputDecoration(labelText: 'Your experience'),
                validator: (value) =>
                    PlaceReview.validate(_rating ?? 1, value ?? ''),
              ),
              if (_error != null) Text(_error!),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save Review'),
        ),
      ],
    ),
  );
}

Future<void> confirmReviewDelete(
  BuildContext context,
  PlaceReview review, {
  bool moderate = false,
}) async {
  final controller = ReviewScope.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Review?'),
      content: Text(
        'Delete the review by ${PlaceReview.publicName(review.userDisplayName)}? This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await controller.delete(review, moderate: moderate);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(backendMessage(error))));
    }
  }
}
