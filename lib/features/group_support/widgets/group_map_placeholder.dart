import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../models/tour_group.dart';

class GroupMapPlaceholder extends StatelessWidget {
  const GroupMapPlaceholder({super.key, required this.group});
  final TourGroup group;
  @override
  Widget build(BuildContext context) {
    final visible = group.members
        .where((member) => member.isSharingLocation)
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: UiText(
              'Demo group tracking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: 240,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GroupGridPainter(Theme.of(context).colorScheme),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Semantics(
                      label: 'Demo destination marker',
                      child: Icon(
                        Icons.flag,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final member in visible)
                    Positioned(
                      left:
                          (member.relativeX ?? .3).clamp(.1, .9).toDouble() *
                          (constraints.maxWidth - 40),
                      top:
                          (member.relativeY ?? .4).clamp(.1, .9).toDouble() *
                          200,
                      child: Tooltip(
                        message: '${member.name} - demo position',
                        child: Semantics(
                          label: '${member.name} demo marker',
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimary,
                            child: member.isLeader
                                ? const Icon(Icons.star)
                                : Text(
                                    member.name.characters.first.toUpperCase(),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UiText(
                  'Star: leader | Initial: member | Flag: destination',
                ),
                const SizedBox(height: 8),
                Text(
                  '${visible.length} sharing members shown. Positions are UI illustrations, not geographic locations.',
                ),
                const SizedBox(height: 8),
                const UiText('No live GPS or background updates.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupGridPainter extends CustomPainter {
  _GroupGridPainter(this.colors);
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerLow,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * .2, 30, size.width * .45, 140),
      Paint()..color = colors.primaryContainer,
    );
    final paint = Paint()
      ..color = colors.surface
      ..strokeWidth = 10;
    for (var index = 1; index < 6; index++) {
      canvas.drawLine(
        Offset(size.width * index / 6, 0),
        Offset(size.width * index / 6, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * index / 6),
        Offset(size.width, size.height * index / 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GroupGridPainter oldDelegate) =>
      colors != oldDelegate.colors;
}
