import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';
import '../../../core/firebase/backend_error.dart';

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
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.sendPasswordReset(_email.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = backendMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const UiText('Reset password'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiText(
                widget.service.isCloud
                    ? 'Enter your email to request password reset instructions.'
                    : 'Enter your email to request reset instructions. This is a demo; no email will be sent.',
              ),
              const SizedBox(height: 12),
              const UiText(
                'This resets your HeritageWalk Email/Password login. Recover Google or Facebook passwords with the provider.',
              ),
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    localizeError(context, (AuthValidators.email)(value)),
                enabled: !_busy,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: UiText(_error!)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const UiText('Back to Login'),
        ),
        HeritageButton(
          label: 'Send Reset Link',
          onPressed: _send,
          isLoading: _busy,
        ),
      ],
    ),
  );
}
