import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heritage_walk/features/navigation_guide/widgets/heritage_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const own = LatLng(6.032, 80.218);
  const remote = LatLng(6.0321, 80.2181);
  const destination = LatLng(6.0322, 80.2182);
  const points = [own, remote, destination];
  const markers = [
    HeritageMapMarker('own', own, 'You', current: true),
    HeritageMapMarker('remote', remote, 'Member'),
    HeritageMapMarker('destination', destination, 'Destination'),
  ];

  Future<MapController> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HeritageMap(
            markers: markers,
            current: own,
            route: points,
            tilesEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
  }

  List<Marker> symbols(WidgetTester tester) =>
      tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).last.markers;

  void verifyAnchors(WidgetTester tester, MapController controller) {
    final origin = tester.getTopLeft(find.byType(FlutterMap));
    final layer = symbols(tester);
    for (var i = 0; i < markers.length; i++) {
      expect(layer[i].point, same(markers[i].position));
      expect(
        layer[i].alignment,
        i == 0 ? Alignment.center : Alignment.topCenter,
      );
      final icon = find.byKey(ValueKey('marker-${markers[i].id}'));
      final anchor = i == 0
          ? tester.getCenter(icon)
          : tester.getRect(icon).bottomCenter;
      final projected =
          origin + controller.camera.latLngToScreenOffset(points[i]);
      expect((anchor - projected).distance, lessThan(0.001));
    }
    expect(
      tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points,
      same(points),
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('all geographic symbols and route remain anchored at zoom 7–18', (
    tester,
  ) async {
    final controller = await mount(tester);
    for (final zoom in [7.0, 10.0, 13.0, 16.0, 18.0]) {
      controller.move(own, zoom);
      await tester.pump();
      verifyAnchors(tester, controller);
    }
    expect(markers.map((m) => m.position), points);
  });

  testWidgets(
    'panning and rotation affect camera only, preserving location models',
    (tester) async {
      final controller = await mount(tester);
      controller.move(const LatLng(6.03205, 80.21805), 18);
      await tester.pump();
      verifyAnchors(tester, controller);
      controller.rotate(35);
      await tester.pump();
      // Counter-rotation keeps the symbol anchor at the projected coordinate.
      verifyAnchors(tester, controller);
      expect(markers.map((m) => m.position), points);
      expect(controller.camera.center, isNot(own));
    },
  );

  testWidgets(
    'recenter moves camera without reconstructing GPS or route points',
    (tester) async {
      final controller = await mount(tester);
      controller.move(const LatLng(6.04, 80.23), 12);
      await tester.pump();
      await tester.tap(find.byTooltip('Recenter'));
      await tester.pumpAndSettle();
      expect(controller.camera.center, own);
      expect(controller.camera.zoom, 15);
      verifyAnchors(tester, controller);
      expect(
        tester.widget<HeritageMap>(find.byType(HeritageMap)).current,
        same(own),
      );
    },
  );

  testWidgets('labels cannot determine symbol bounds or their anchors', (
    tester,
  ) async {
    final controller = await mount(tester);
    verifyAnchors(tester, controller);
    for (final marker in symbols(tester)) {
      expect(marker.width, 30);
      expect(marker.height, 30);
      expect(
        find.descendant(
          of: find.byWidget(marker.child),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    }
    expect(find.byKey(const ValueKey('marker-label-own')), findsOneWidget);
    expect(find.byKey(const ValueKey('marker-label-remote')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('marker-label-destination')),
      findsOneWidget,
    );
  });
}
