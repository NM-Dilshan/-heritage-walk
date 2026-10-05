import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../discovery_planning/widgets/place_card.dart';
import '../../discovery_planning/widgets/section_header.dart';
import '../models/guide_content.dart';
import '../models/guide_note.dart';
import '../services/navigation_guide_scope.dart';
import '../widgets/demo_audio_guide.dart';
import '../widgets/guide_note_dialog.dart';
import '../widgets/guide_section_card.dart';

class DigitalGuideScreen extends StatelessWidget {
  const DigitalGuideScreen({super.key, required this.place});
  final HeritagePlace place;
  Future<void> _editNote(BuildContext context, {GuideNote? note}) async {
    final service = NavigationGuideScope.of(context).notes;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => GuideNoteDialog(initialText: note?.text),
    );
    if (text == null || !context.mounted) return;
    if (note == null) {
      service.add(place.id, text);
    } else {
      service.update(note.id, text);
    }
  }

  Future<void> _deleteNote(BuildContext context, GuideNote note) async {
    final service = NavigationGuideScope.of(context).notes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text(note.text),
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
    if (confirmed == true && context.mounted) service.delete(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final content = GuideContent.forPlace(place);
    final notes = NavigationGuideScope.of(context).notes.forPlace(place.id);
    return DiscoveryLayout(
      title: 'Digital Guide',
      actions: [
        IconButton(
          tooltip: 'Emergency Support',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.emergency),
          icon: const Icon(Icons.health_and_safety_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PlaceImage(place: place),
          ),
          const SizedBox(height: 20),
          Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${place.city}, ${place.district}'),
          const SizedBox(height: 24),
          const DemoAudioGuide(),
          const SizedBox(height: 24),
          for (final section in <String, String>{
            'Overview': content.overview,
            'History': content.history,
            'Architecture / Significance': content.significance,
            'Highlights': content.highlights
                .map((value) => '- $value')
                .join(String.fromCharCode(10)),
            'Visitor Tips': GuideContent.visitorTips
                .map((value) => '- $value')
                .join(String.fromCharCode(10)),
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GuideSectionCard(
                title: section.key,
                content: section.value,
                initiallyExpanded: section.key == 'Overview',
              ),
            ),
          const SectionHeader(
            title: 'My Notes',
            subtitle:
                'Personal notes for this place. Stored for this session only.',
          ),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('No notes yet. Capture a thought from your journey.'),
            ),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(note.text),
                      const SizedBox(height: 8),
                      Text(
                        'Updated ${formatTourDate(note.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Note'),
                            onPressed: () => _editNote(context, note: note),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete Note'),
                            onPressed: () => _deleteNote(context, note),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          HeritageButton(
            label: 'Add Note',
            variant: HeritageButtonVariant.outlined,
            onPressed: () => _editNote(context),
          ),
          const SizedBox(height: 24),
          HeritageButton(
            label: 'Navigate to Place',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.navigation,
              arguments: place,
            ),
          ),
          const SizedBox(height: 12),
          HeritageButton(
            label: 'Nearby Facilities',
            variant: HeritageButtonVariant.outlined,
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.facilities,
              arguments: place,
            ),
          ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
