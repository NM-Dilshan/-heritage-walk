import 'package:flutter/material.dart';

import '../../../core/firebase/backend_error.dart';

import '../../../shared/widgets/heritage_text_field.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../services/group_tour_service.dart';

class GroupTextDialog extends StatefulWidget {
  const GroupTextDialog({
    super.key,
    required this.title,
    required this.label,
    this.initialText = '',
  });
  final String title, label, initialText;
  @override
  State<GroupTextDialog> createState() => _GroupTextDialogState();
}

class _GroupTextDialogState extends State<GroupTextDialog> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.initialText);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: HeritageTextField(
          label: widget.label,
          controller: _text,
          maxLength: 60,
          validator: GroupTourService.validateName,
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
            Navigator.pop(context, _text.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class GroupDestinationDialog extends StatefulWidget {
  const GroupDestinationDialog({super.key, required this.placeId});
  final String? placeId;
  @override
  State<GroupDestinationDialog> createState() => _GroupDestinationDialogState();
}

class _GroupDestinationDialogState extends State<GroupDestinationDialog> {
  final _form = GlobalKey<FormState>();
  late String? _id = widget.placeId;
  @override
  Widget build(BuildContext context) {
    final places = DiscoveryScope.of(context).discovery.places;
    return AlertDialog(
      title: const Text('Change Destination'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: DropdownButtonFormField<String>(
            key: ValueKey(places.map((p) => p.id).join(',')),
            initialValue: places.any((place) => place.id == _id) ? _id : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: places
                .map(
                  (place) => DropdownMenuItem(
                    value: place.id,
                    child: Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) => !places.any((p) => p.id == value)
                ? 'Select a destination'
                : null,
            onChanged: (value) => _id = value,
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
              Navigator.pop<HeritagePlace>(
                context,
                places.firstWhere((place) => place.id == _id),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<bool> confirmGroupAction(
  BuildContext context,
  String title,
  String message,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key, required this.service});
  final GroupTourService service;
  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Join with Code'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: HeritageTextField(
          label: 'Invite Code',
          hint: 'HW-1234',
          controller: _code,
          errorText: _error,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter an invite code'
              : null,
          onChanged: (_) => setState(() => _error = null),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () async {
                if (!_form.currentState!.validate()) return;
                setState(() => _busy = true);
                try {
                  final group = await widget.service.join(_code.text);
                  if (!mounted || !context.mounted) return;
                  if (group == null) {
                    setState(
                      () => _error = 'Group not found. Check the invite code.',
                    );
                  } else {
                    Navigator.pop(context, group.id);
                  }
                } catch (error) {
                  if (mounted) setState(() => _error = backendMessage(error));
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: const Text('Join'),
      ),
    ],
  );
}
