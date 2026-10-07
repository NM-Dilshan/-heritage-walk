import '../../../core/localization/app_localizations.dart';
import '../../../core/firebase/backend_error.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';
import '../widgets/auth_form_layout.dart';
import '../widgets/social_auth_buttons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _emailBusy = false;
  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final service = ProfileScope.of(context);
    setState(() {
      _busy = true;
      _emailBusy = true;
    });
    try {
      await service.register(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
      );
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

  void _signIn() =>
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AuthFormLayout(
      title: 'Create Account',
      subtitle: 'Join HeritageWalk today',
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeritageTextField(
                label: 'Full Name',
                controller: _name,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (value) =>
                    localizeError(context, (AuthValidators.name)(value)),
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Confirm Password',
                controller: _confirm,
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: (value) => localizeError(
                  context,
                  ((value) => value == null || value.isEmpty
                      ? 'Confirm your password'
                      : value != _password.text
                      ? 'Passwords must match'
                      : null)(value),
                ),
                enabled: !_busy,
              ),
              const SizedBox(height: 24),
              HeritageButton(
                label: 'Sign Up',
                onPressed: _register,
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
            const UiText('Already have an account?'),
            TextButton(
              onPressed: _busy ? null : _signIn,
              child: const UiText('Sign In'),
            ),
          ],
        ),
      ],
    ),
  );
}
