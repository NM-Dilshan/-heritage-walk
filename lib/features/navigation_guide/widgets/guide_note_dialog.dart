import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_text_field.dart';
import '../services/guide_notes_service.dart';

class GuideNoteDialog extends StatefulWidget {
  const GuideNoteDialog({super.key, this.initialText});
  final String? initialText;
  @override
  State<GuideNoteDialog> createState() => _GuideNoteDialogState();
}

class _GuideNoteDialogState extends State<GuideNoteDialog> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.initialText);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: UiText(widget.initialText == null ? 'Add Note' : 'Edit Note'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: HeritageTextField(
          label: 'Personal note',
          controller: _text,
          maxLines: 4,
          maxLength: 500,
          keyboardType: TextInputType.multiline,
          validator: (value) =>
              localizeError(context, (GuideNotesService.validate)(value)),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const UiText('Cancel'),
      ),
      TextButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _text.text.trim());
          }
        },
        child: const UiText('Save'),
      ),
    ],
  );
}
