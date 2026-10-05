import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({super.key, required this.service});
  final ProfileService service;
  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.service.sendPasswordReset(_email.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to send reset instructions. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Reset password'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.service.isCloud
                    ? 'Enter your email to request password reset instructions.'
                    : 'Enter your email to request reset instructions. This is a demo; no email will be sent.',
              ),
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: AuthValidators.email,
                enabled: !_busy,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        HeritageButton(
          label: 'Send instructions',
          onPressed: _send,
          isLoading: _busy,
        ),
      ],
    ),
  );
}
