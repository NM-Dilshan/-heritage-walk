import 'package:flutter/material.dart';

class GuideSectionCard extends StatelessWidget {
  const GuideSectionCard({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });
  final String title, content;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      title: Text(title),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [Align(alignment: Alignment.centerLeft, child: Text(content))],
    ),
  );
}
