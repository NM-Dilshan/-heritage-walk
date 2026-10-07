import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class HeritageMapMarker {
  const HeritageMapMarker(
    this.id,
    this.position,
    this.label, {
    this.current = false,
    this.onTap,
  });
  final String id, label;
  final LatLng position;
  final bool current;
  final VoidCallback? onTap;
}

class HeritageMap extends StatefulWidget {
  const HeritageMap({
    super.key,
    required this.markers,
    this.route = const [],
    this.active = false,
    this.current,
    this.tilesEnabled = true,
    this.focus,
    this.fitMarkers = false,
    this.groupRecenter = false,
  });
  final List<HeritageMapMarker> markers;
  final List<LatLng> route;
  final bool active, tilesEnabled;
  final LatLng? current;
  final LatLng? focus;
  final bool fitMarkers;

  final bool groupRecenter;
  @override
  State<HeritageMap> createState() => _HeritageMapState();
}

class _HeritageMapState extends State<HeritageMap> {
  final controller = MapController();
  bool tileError = false, ready = false;
  @override
  void didUpdateWidget(HeritageMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ready && widget.focus != null && oldWidget.focus != widget.focus) {
      controller.move(widget.focus!, 16);
    } else if (ready &&
        widget.fitMarkers &&
        widget.focus == null &&
        oldWidget.markers.map((m) => '${m.id}:${m.position}').join() !=
            widget.markers.map((m) => '${m.id}:${m.position}').join()) {
      _fitMarkers();
    } else if (ready &&
        oldWidget.route != widget.route &&
        widget.route.isNotEmpty) {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(widget.route),
          padding: const EdgeInsets.all(45),
        ),
      );
    } else if (ready && oldWidget.current == null && widget.current != null) {
      controller.move(widget.current!, 14);
    }
  }

  void _fitMarkers() {
    final points = widget.markers.map((m) => m.position).toList();
    if (points.length > 1) {
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(45),
          maxZoom: 16,
        ),
      );
    } else if (points.isNotEmpty) {
      controller.move(points.first, 14);
    }
  }

  // Labels have their own geographic anchors, so text layout cannot move a
  // location symbol. Exactly coincident members share a readable label column.
  List<Marker> _labelMarkers() {
    final groups = <LatLng, List<HeritageMapMarker>>{};
    for (final marker in widget.markers) {
      groups.putIfAbsent(marker.position, () => []).add(marker);
    }
    return groups.entries.map((entry) {
      final clearance = entry.value.any((m) => !m.current) ? 30.0 : 15.0;
      return Marker(
        point: entry.key,
        width: 130,
        height: entry.value.length * 20.0 + clearance,
        alignment: Alignment.topCenter,
        rotate: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: clearance),
          child: Column(
            children: entry.value
                .map(
                  (m) => SizedBox(
                    height: 20,
                    child: GestureDetector(
                      onTap: m.onTap,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          m.label,
                          key: ValueKey('marker-label-${m.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 340,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter:
                      widget.current ??
                      widget.markers.firstOrNull?.position ??
                      const LatLng(7.8731, 80.7718),
                  initialZoom: widget.current != null ? 14 : 7,
                  maxZoom: 19,
                  onMapReady: () {
                    ready = true;
                    if (widget.focus != null) {
                      controller.move(widget.focus!, 16);
                    } else if (widget.fitMarkers) {
                      _fitMarkers();
                    }
                    if (widget.route.isNotEmpty) {
                      controller.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(widget.route),
                          padding: const EdgeInsets.all(45),
                        ),
                      );
                    }
                  },
                ),
                children: [
                  if (widget.tilesEnabled)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'lk.heritagewalk.heritage_walk',
                      maxNativeZoom: 19,
                      panBuffer: 0,
                      tileProvider: NetworkTileProvider(
                        silenceExceptions: true,
                      ),
                      errorTileCallback: (tile, error, stack) {
                        if (mounted && !tileError) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => tileError = true);
                          });
                        }
                      },
                    ),
                  if (widget.route.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.route,
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: widget.active ? 7 : 4,
                        ),
                      ],
                    ),
                  MarkerLayer(markers: _labelMarkers()),
                  MarkerLayer(
                    markers: widget.markers
                        .map(
                          (m) => Marker(
                            point: m.position,
                            width: 30,
                            height: 30,
                            alignment: m.current
                                ? Alignment.center
                                : Alignment.topCenter,
                            rotate: true,
                            child: Semantics(
                              label: m.label,
                              button: m.onTap != null,
                              child: GestureDetector(
                                onTap: m.onTap,
                                child: Icon(
                                  m.current
                                      ? Icons.my_location
                                      : Icons.location_on,
                                  key: ValueKey('marker-${m.id}'),
                                  color: m.current ? Colors.blue : Colors.red,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              if (widget.current != null ||
                  (widget.groupRecenter && widget.markers.isNotEmpty))
                Positioned(
                  right: 8,
                  top: 8,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: AppLocalizations.text(context, 'Recenter'),
                    onPressed: widget.groupRecenter
                        ? _fitMarkers
                        : () => controller.move(widget.current!, 15),
                    child: const Icon(Icons.my_location),
                  ),
                ),
            ],
          ),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
            child: const UiText('© OpenStreetMap contributors'),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://routing.openstreetmap.de/about.html'),
            ),
            child: const UiText('Routing: FOSSGIS / OSRM'),
          ),
          TextButton(
            onPressed: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/fixthemap')),
            child: const UiText('Fix the map'),
          ),
        ],
      ),
      if (tileError)
        const UiText(
          'Map tiles unavailable. Check your internet connection. Routes and map tiles need internet.',
        ),
    ],
  );
}
