import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../../core/firebase/backend_error.dart';
import '../../../core/firebase/social_auth.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../services/profile_service.dart';

/// Login and Register share one provider flow and the existing ProfileService.
class SocialAuthButtons extends StatefulWidget {
  const SocialAuthButtons({
    super.key,
    required this.busy,
    required this.onBusyChanged,
  });
  final bool busy;
  final ValueChanged<bool> onBusyChanged;
  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  SocialProvider? _active;
  Future<void> _signIn(SocialProvider provider) async {
    if (widget.busy || _active != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _active = provider);
    widget.onBusyChanged(true);
    try {
      final result = await ProfileScope.of(context).signInSocial(provider);
      if (mounted && result == SocialResult.authenticated) {
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
        setState(() => _active = null);
        widget.onBusyChanged(false);
      }
    }
  }

  String _label(SocialProvider provider) => provider == SocialProvider.google
      ? (_active == provider
            ? 'Signing in with Google…'
            : 'Continue with Google')
      : (_active == provider
            ? 'Signing in with Facebook…'
            : 'Continue with Facebook');

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Measure both localized labels at the actual text scale so the pair stays
      // equal in height when one label wraps onto more lines.
      final defaults = const OutlinedButton(
        onPressed: null,
        child: SizedBox(),
      ).defaultStyleOf(context);
      final style = defaults.merge(Theme.of(context).outlinedButtonTheme.style);
      final padding = (style.padding?.resolve({}) ?? EdgeInsets.zero).resolve(
        Directionality.of(context),
      );
      final textStyle = DefaultTextStyle.of(context).style
          .merge(style.textStyle?.resolve({}));
      var height = 52.0;
      if (constraints.hasBoundedWidth) {
        for (final provider in SocialProvider.values) {
          final painter =
              TextPainter(
                text: TextSpan(
                  text: AppLocalizations.text(context, _label(provider)),
                  style: textStyle,
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
              )..layout(
                maxWidth: math.max(
                  1,
                  constraints.maxWidth - padding.horizontal - 36,
                ),
              );
          height = math.max(
            height,
            math.max(24, painter.height).ceilToDouble() + padding.vertical,
          );
          painter.dispose();
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final provider in SocialProvider.values) ...[
            if (provider == SocialProvider.facebook) const SizedBox(height: 12),
            SizedBox(
              height: height,
              child: OutlinedButton(
                key: ValueKey('social-${provider.name}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 52),
                ),
                onPressed: widget.busy || _active != null
                    ? null
                    : () => _signIn(provider),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_active == provider)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ExcludeSemantics(
                        child: Image.asset(
                          'assets/branding/${provider.name}_sign_in.png',
                          key: ValueKey('social-${provider.name}-icon'),
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: UiText(
                        _label(provider),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}
