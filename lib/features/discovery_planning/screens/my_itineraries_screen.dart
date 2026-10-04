import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../models/itinerary.dart';
import '../services/discovery_scope.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/itinerary_card.dart';

class MyItinerariesScreen extends StatelessWidget {
  const MyItinerariesScreen({super.key});
  Future<void> _rename(BuildContext context, Itinerary itinerary) async {
    final service = DiscoveryScope.of(context).itineraries;
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameItineraryDialog(initialTitle: itinerary.title),
    );
    if (title != null && context.mounted) service.rename(itinerary.id, title);
  }

  Future<void> _delete(BuildContext context, Itinerary itinerary) async {
    final service = DiscoveryScope.of(context).itineraries;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this itinerary?'),
        content: Text(itinerary.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      service.delete(itinerary.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Itinerary deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = DiscoveryScope.of(context).itineraries.savedItineraries;
    return DiscoveryLayout(
      title: 'My Itineraries',
      selectedIndex: 3,
      actions: [
        IconButton(
          tooltip: 'Plan a Tour',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.planTour),
          icon: const Icon(Icons.add),
        ),
      ],
      child: items.isEmpty
          ? DiscoveryEmptyState(
              title: 'No saved itineraries yet',
              message: 'Plan your first heritage journey.',
              icon: Icons.route_outlined,
              buttonLabel: 'Plan a Tour',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.planTour),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${items.length} saved journeys',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                for (final itinerary in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ItineraryCard(
                      key: ValueKey(itinerary.id),
                      itinerary: itinerary,
                      onView: () => Navigator.pushNamed(
                        context,
                        AppRoutes.generatedItinerary,
                        arguments: itinerary.id,
                      ),
                      onRename: () => _rename(context, itinerary),
                      onDelete: () => _delete(context, itinerary),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RenameItineraryDialog extends StatefulWidget {
  const _RenameItineraryDialog({required this.initialTitle});
  final String initialTitle;
  @override
  State<_RenameItineraryDialog> createState() => _RenameItineraryDialogState();
}

class _RenameItineraryDialogState extends State<_RenameItineraryDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initialTitle);
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename Itinerary'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: HeritageTextField(
          label: 'Itinerary title',
          controller: _title,
          maxLength: 80,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter an itinerary title'
              : null,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _title.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
