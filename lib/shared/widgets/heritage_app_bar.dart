import 'package:flutter/material.dart';

class HeritageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HeritageAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.actions,
    this.onBack,
  });
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    automaticallyImplyLeading: false,
    leading: showBackButton ? BackButton(onPressed: onBack) : null,
    actions: actions,
  );
}
