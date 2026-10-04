import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';
import '../widgets/auth_form_layout.dart';
import '../widgets/password_reset_dialog.dart';

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
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final service = ProfileScope.of(context);
    setState(() => _busy = true);
    try {
      await service.signIn(_email.text);
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to sign in. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordResetDialog(service: ProfileScope.of(context)),
    );
    if (mounted && sent == true) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset instructions sent.')),
      );
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('Forgot Password?'),
                ),
              ),
              HeritageButton(
                label: 'Sign In',
                onPressed: _signIn,
                isLoading: _busy,
              ),
            ],
          ),
        ),
        const AuthDivider(),
        HeritageButton(
          label: 'Continue with Google',
          variant: HeritageButtonVariant.outlined,
          enabled: !_busy,
          onPressed: () => showSocialMessage(context),
        ),
        const SizedBox(height: 12),
        HeritageButton(
          label: 'Continue with Apple',
          variant: HeritageButtonVariant.outlined,
          enabled: !_busy,
          onPressed: () => showSocialMessage(context),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text("Don't have an account?"),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.register),
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ],
    ),
  );
}
