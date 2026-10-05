import 'package:flutter/material.dart';

import '../models/support_request.dart';
import '../services/support_service.dart';

class SupportRequestForm extends StatefulWidget {
  const SupportRequestForm({super.key, this.request, required this.service});
  final SupportRequest? request;
  final SupportService service;
  @override
  State<SupportRequestForm> createState() => _SupportRequestFormState();
}

class _SupportRequestFormState extends State<SupportRequestForm> {
  final _form = GlobalKey<FormState>();
  late final _subject = TextEditingController(text: widget.request?.subject);
  late final _message = TextEditingController(text: widget.request?.message);
  late SupportCategory? _category = widget.request?.category;
  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.request == null ? 'Contact Support' : 'Edit Support Request',
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Signed-in requests are saved to your account. No message is sent to a real support team.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SupportCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in SupportCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) => _category = value,
              validator: (value) =>
                  value == null ? 'Category is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (value) =>
                  SupportService.validateText(value, 'Subject', 100),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Message'),
              validator: (value) =>
                  SupportService.validateText(value, 'Message', 1000),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          if (widget.request == null) {
            widget.service.createSupportRequest(
              subject: _subject.text,
              message: _message.text,
              category: _category!,
            );
          } else {
            widget.service.updateSupportRequest(
              widget.request!.id,
              subject: _subject.text,
              message: _message.text,
              category: _category!,
            );
          }
          Navigator.pop(context, true);
        },
        child: Text(widget.request == null ? 'Submit Request' : 'Save Changes'),
      ),
    ],
  );
}
