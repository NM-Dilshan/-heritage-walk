import 'package:flutter/material.dart';

import '../services/language_service.dart';

class LanguageOptionCard extends StatelessWidget {
  const LanguageOptionCard({
    super.key,
    required this.language,
    required this.selected,
    required this.onTap,
  });
  final LanguageOption language;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        title: Text(language.name),
        subtitle: Text(language.nativeName),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          semanticLabel: selected ? 'Selected' : 'Select ${language.name}',
          color: Theme.of(context).colorScheme.primary,
        ),
        onTap: onTap,
      ),
    ),
  );
}
