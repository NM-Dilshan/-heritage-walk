import '../../../core/localization/app_localizations.dart';

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
    title: UiText(
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
            const UiText(
              'Signed-in requests are saved to your account. No message is sent to a real support team.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SupportCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.text(context, 'Category'),
              ),
              items: [
                for (final category in SupportCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: UiText(category.label),
                  ),
              ],
              onChanged: (value) => _category = value,
              validator: (value) => localizeError(
                context,
                ((value) =>
                    value == null ? 'Category is required' : null)(value),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: AppLocalizations.text(context, 'Subject'),
              ),
              validator: (value) => localizeError(
                context,
                ((value) =>
                    SupportService.validateText(value, 'Subject', 100))(value),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: AppLocalizations.text(context, 'Message'),
              ),
              validator: (value) => localizeError(
                context,
                ((value) =>
                    SupportService.validateText(value, 'Message', 1000))(value),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const UiText('Cancel'),
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
        child: UiText(
          widget.request == null ? 'Submit Request' : 'Save Changes',
        ),
      ),
    ],
  );
}
