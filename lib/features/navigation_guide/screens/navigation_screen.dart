import '../../../core/localization/app_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../models/navigation_destination.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../models/route_info.dart';
import '../services/navigation_guide_scope.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import '../widgets/heritage_map.dart';
import '../widgets/route_summary_card.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, this.place});
  final RouteDestination? place;
  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  NavigationService? service;
  bool _awaitingSettings = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (service != null) return;
    service = NavigationGuideScope.of(context).navigation;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.place != null) service!.selectDestination(widget.place!);
        unawaited(service!.locate());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      unawaited(service?.locate());
      return;
    }
    // The permission dialog can make a foreground activity inactive. Keep the
    // initial permission/fix request alive; actual backgrounding cancels it.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive && service?.isActive == true)) {
      service?.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service?.suspend(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = NavigationGuideScope.of(context).navigation;
    final places = <RouteDestination>[
      if (service.destination != null &&
          !DiscoveryScope.of(context).discovery.places
              .any((p) => p.id == service.destination!.id))
        service.destination!,
      ...DiscoveryScope.of(context).discovery.places,
    ];
    final destinationName = service.destination == null
        ? ''
        : service.destination!.hasName
        ? service.destination!.name
        : AppLocalizations.text(context, service.destination!.name);
    final route = service.route;
    final state = service.locationState;
    final message = switch (state) {
      LocationState.notRequested => 'Allow location to find a route.',
      LocationState.loading => 'Finding your current location…',
      LocationState.granted => 'Current location available',
      LocationState.denied =>
        'Location permission denied. Allow location to calculate a route.',
      LocationState.deniedForever =>
        'Location permission is blocked. Open settings to allow it.',
      LocationState.servicesOff =>
        'Device location is disabled. Enable location to continue.',
      LocationState.unavailable => 'Current location temporarily unavailable.',
      LocationState.timeout =>
        'Location request timed out. Try again outdoors.',
      LocationState.error => 'Current location unavailable. Try again.',
    };
    return DiscoveryLayout(
      title: 'Navigation',
      selectedIndex: 2,
      actions: [
        IconButton(
          tooltip: AppLocalizations.text(context, 'Emergency Support'),
          onPressed: () {
            service.suspend();
            Navigator.pushNamed(context, AppRoutes.emergency);
          },
          icon: const Icon(Icons.health_and_safety_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'Route Guidance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const UiText(
            'Route preview with live GPS. No voice or turn-by-turn instructions.',
          ),
          const SizedBox(height: 16),
          const UiText('Choose a destination'),
          DropdownButtonFormField<String>(
            key: ValueKey(
              '${service.destination?.id}:${places.map((p) => p.id).join(',')}',
            ),
            initialValue: places.any((p) => p.id == service.destination?.id)
                ? service.destination?.id
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.text(context, 'Destination'),
            ),
            items: places
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.hasName
                          ? p.name
                          : AppLocalizations.text(context, p.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id != null) {
                service.selectDestination(places.firstWhere((p) => p.id == id));
              }
            },
          ),
          const SizedBox(height: 16),
          if (service.destination != null)
            Text(
              destinationName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          HeritageMap(
            tilesEnabled: NavigationGuideScope.of(context).tilesEnabled,
            current: service.currentPosition,
            route: service.path?.points ?? const [],
            active: service.isActive,
            markers: [
              if (service.currentPosition != null)
                HeritageMapMarker(
                  'current',
                  service.currentPosition!,
                  AppLocalizations.text(context, 'Current location'),
                  current: true,
                ),
              if (service.destinationPosition != null)
                HeritageMapMarker(
                  'destination',
                  service.destinationPosition!,
                  destinationName,
                ),
            ],
          ),
          UiText(message),
          if (state == LocationState.loading || service.loadingRoute)
            const LinearProgressIndicator(),
          if (state != LocationState.loading && state != LocationState.granted)
            HeritageButton(
              label: state == LocationState.deniedForever
                  ? 'Open Settings'
                  : state == LocationState.servicesOff
                  ? 'Enable Location'
                  : 'Allow Location',
              onPressed: () async {
                if (state == LocationState.deniedForever ||
                    state == LocationState.servicesOff) {
                  _awaitingSettings = true;
                  await service.location.openSettings(
                    device: state == LocationState.servicesOff,
                  );
                } else {
                  await service.locate();
                }
              },
            ),
          if (service.destination != null && !service.validDestination)
            const UiText(
              'Location information is unavailable for this destination.',
            ),
          if (service.destination == null)
            const UiText('Select a heritage destination to calculate a route.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: TravelMode.values
                .map(
                  (mode) => ChoiceChip(
                    label: UiText(
                      mode == TravelMode.walking ? 'Walking' : 'Driving',
                    ),
                    selected: mode == service.mode,
                    onSelected: (_) => service.selectMode(mode),
                  ),
                )
                .toList(),
          ),
          if (service.routeFailure != null) ...[
            UiText(
              "Route unavailable: {0}. Check your connection and retry.",
              args: [
                AppLocalizations.text(context, service.routeFailure!.name),
              ],
            ),
            HeritageButton(label: 'Retry', onPressed: service.calculateRoute),
          ],
          if (route != null) ...[
            RouteSummaryCard(route: route),
            const SizedBox(height: 12),
            UiText(
              service.isActive
                  ? 'Route guidance active'
                  : 'Route preview ready',
            ),
            HeritageButton(
              label: service.isActive
                  ? 'End Navigation'
                  : 'Start Route Guidance',
              onPressed: service.isActive ? service.end : service.start,
            ),
            TextButton(
              onPressed: service.calculateRoute,
              child: const UiText('Recalculate route'),
            ),
          ],
          const SizedBox(height: 24),
          const UiText(
            'GPS stays on this device during individual navigation. Routing sends start and destination coordinates to FOSSGIS.',
          ),
        ],
      ),
    );
  }
}
