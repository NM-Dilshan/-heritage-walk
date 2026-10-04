import 'package:flutter/material.dart';

import 'heritage_loading.dart';

enum HeritageButtonVariant { primary, outlined }

class HeritageButton extends StatelessWidget {
  const HeritageButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HeritageButtonVariant.primary,
    this.isLoading = false,
    this.enabled = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final HeritageButtonVariant variant;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final callback = enabled && !isLoading ? onPressed : null;
    final child = isLoading
        ? const HeritageLoading(size: 20)
        : Text(label, textAlign: TextAlign.center);
    return variant == HeritageButtonVariant.primary
        ? FilledButton(onPressed: callback, child: child)
        : OutlinedButton(onPressed: callback, child: child);
  }
}
