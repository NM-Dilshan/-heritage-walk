import 'package:flutter/material.dart';

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, required this.destination});
  final String destination;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Demo route preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DemoMapPainter(Theme.of(context).colorScheme),
                ),
              ),
              const Align(
                alignment: Alignment(-0.65, 0.65),
                child: Icon(Icons.my_location, size: 32),
              ),
              Align(
                alignment: const Alignment(0.65, -0.65),
                child: Icon(
                  Icons.location_on,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Demo compass',
                      icon: const Icon(Icons.explore_outlined),
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Illustrative compass; live orientation is not connected.',
                              ),
                            ),
                          ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Center demo preview',
                      icon: const Icon(Icons.center_focus_strong),
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Demo preview centered; no GPS location is used.',
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('Current Location: demo marker'),
                  Text('Destination: demo marker'),
                ],
              ),
              const SizedBox(height: 8),
              Text(destination, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              const Text(
                'Illustration only. No live GPS, traffic or street routing.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DemoMapPainter extends CustomPainter {
  _DemoMapPainter(this.colors);
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerLow,
    );
    final parkPaint = Paint()..color = colors.primaryContainer;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .05,
          size.height * .12,
          size.width * .25,
          size.height * .28,
        ),
        const Radius.circular(18),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .55,
          size.height * .58,
          size.width * .34,
          size.height * .27,
        ),
        const Radius.circular(18),
      ),
      parkPaint,
    );
    final roads = Paint()
      ..color = colors.surface
      ..strokeWidth = 12;
    for (var index = 1; index < 6; index++) {
      canvas.drawLine(
        Offset(size.width * index / 6, 0),
        Offset(size.width * index / 6, size.height),
        roads,
      );
      canvas.drawLine(
        Offset(0, size.height * index / 6),
        Offset(size.width, size.height * index / 6),
        roads,
      );
    }
    final path = Path()
      ..moveTo(size.width * .175, size.height * .825)
      ..cubicTo(
        size.width * .2,
        size.height * .3,
        size.width * .75,
        size.height * .85,
        size.width * .825,
        size.height * .175,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DemoMapPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
