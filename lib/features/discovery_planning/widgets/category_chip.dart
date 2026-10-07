import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: UiText(label),
    selected: selected,
    showCheckmark: true,
    onSelected: (_) => onSelected(),
  );
}
