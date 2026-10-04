import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';
import '../widgets/auth_form_layout.dart';

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
  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final service = ProfileScope.of(context);
    setState(() => _busy = true);
    try {
      await service.register(fullName: _name.text, email: _email.text);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to create your session. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
                validator: AuthValidators.name,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.mail_outline),
                validator: AuthValidators.email,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Password',
                controller: _password,
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: AuthValidators.password,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              HeritageTextField(
                label: 'Confirm Password',
                controller: _confirm,
                isPassword: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: (value) => value == null || value.isEmpty
                    ? 'Confirm your password'
                    : value != _password.text
                    ? 'Passwords must match'
                    : null,
                enabled: !_busy,
              ),
              const SizedBox(height: 24),
              HeritageButton(
                label: 'Sign Up',
                onPressed: _register,
                isLoading: _busy,
              ),
            ],
          ),
        ),
        const AuthDivider(),
        HeritageButton(
          label: 'Sign up with Google',
          variant: HeritageButtonVariant.outlined,
          enabled: !_busy,
          onPressed: () => showSocialMessage(context),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Already have an account?'),
            TextButton(
              onPressed: _busy ? null : _signIn,
              child: const Text('Sign In'),
            ),
          ],
        ),
      ],
    ),
  );
}
