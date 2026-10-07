import '../../../core/localization/app_localizations.dart';
import '../../../core/firebase/backend_error.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';
import '../widgets/auth_form_layout.dart';
import '../widgets/password_reset_dialog.dart';
import '../widgets/social_auth_buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _emailBusy = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final service = ProfileScope.of(context);
    setState(() {
      _busy = true;
      _emailBusy = true;
    });
    try {
      await service.signIn(_email.text, password: _password.text);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: UiText(backendMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _emailBusy = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PasswordResetDialog(service: ProfileScope.of(context)),
      );
      if (mounted && sent == true) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: UiText(
              ProfileScope.of(context).isCloud
                  ? 'If this email has an Email/Password account, reset instructions have been requested. Check your inbox and spam folder.'
                  : 'Preview only: no reset email was sent.',
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
    child: AuthFormLayout(
      title: 'Welcome Back',
      subtitle: 'Sign in to continue your journey',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeritageTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline),
                validator: (value) =>
                    localizeError(context, (AuthValidators.email)(value)),
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Password',
                controller: _password,
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: (value) =>
                    localizeError(context, (AuthValidators.password)(value)),
                enabled: !_busy,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const UiText('Forgot Password?'),
                ),
              ),
              HeritageButton(
                label: 'Sign In',
                onPressed: _signIn,
                isLoading: _emailBusy,
                enabled: !_busy,
              ),
            ],
          ),
        ),
        const AuthDivider(),
        SocialAuthButtons(
          busy: _busy,
          onBusyChanged: (value) => setState(() => _busy = value),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const UiText("Don't have an account?"),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.register),
              child: const UiText('Sign Up'),
            ),
          ],
        ),
      ],
    ),
  );
}
