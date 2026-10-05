import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_app_bar.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/main_bottom_navigation.dart';

class DiscoveryLayout extends StatelessWidget {
  const DiscoveryLayout({
    super.key,
    required this.title,
    required this.child,
    this.selectedIndex,
    this.actions,
  });
  final String title;
  final Widget child;
  final int? selectedIndex;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: HeritageAppBar(
      title: title,
      showBackButton: selectedIndex == null || Navigator.of(context).canPop(),
      actions: actions,
    ),
    bottomNavigationBar: selectedIndex == null
        ? null
        : MainBottomNavigation(selectedIndex: selectedIndex!),
    body: SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class DiscoveryEmptyState extends StatelessWidget {
  const DiscoveryEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.buttonLabel,
    this.onPressed,
  });
  final String title, message;
  final IconData icon;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (buttonLabel != null) ...[
          const SizedBox(height: 24),
          HeritageButton(label: buttonLabel!, onPressed: onPressed),
        ],
      ],
    ),
  );
}

String formatTourDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
