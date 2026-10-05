import 'package:flutter/material.dart';

import '../services/place_image_catalog.dart';

Future<String?> choosePlaceImage(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (context) => _PlaceImageSelector(current: current),
    );

class _PlaceImageSelector extends StatefulWidget {
  const _PlaceImageSelector({required this.current});
  final String current;
  @override
  State<_PlaceImageSelector> createState() => _PlaceImageSelectorState();
}

class _PlaceImageSelectorState extends State<_PlaceImageSelector> {
  late String _selected = widget.current;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose Place Image'),
    content: SizedBox(
      width: 640,
      height: MediaQuery.sizeOf(context).height * .55,
      child: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          itemCount: PlaceImageCatalog.options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 480
                ? 3
                : constraints.maxWidth >= 280
                ? 2
                : 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent:
                120 + 76 * MediaQuery.textScalerOf(context).scale(1),
          ),
          itemBuilder: (context, index) {
            final option = PlaceImageCatalog.options[index];
            final selected = _selected == option.assetPath;
            return Semantics(
              selected: selected,
              button: true,
              label: option.displayName,
              child: Material(
                color: selected
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey(option.assetPath),
                  onTap: () => setState(() => _selected = option.assetPath),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 120,
                        child: Image.asset(
                          option.assetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) =>
                              const Icon(Icons.image_outlined),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            option.displayName,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (selected) const Icon(Icons.check_circle, size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: PlaceImageCatalog.forAsset(_selected) == null
            ? null
            : () => Navigator.pop(context, _selected),
        child: const Text('Use Image'),
      ),
    ],
  );
}
