import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../models/facility.dart';
import '../services/facility_service.dart';
import '../services/location_service.dart';
import '../services/navigation_guide_scope.dart';
import '../services/nearby_facility_controller.dart';
import '../widgets/facility_card.dart';
import '../widgets/heritage_map.dart';

class NearbyFacilitiesScreen extends StatefulWidget {
  const NearbyFacilitiesScreen({super.key, this.place});
  // Kept for existing Details/Guide routes. Discovery uses current GPS, not
  // these heritage coordinates, and never inserts OSM results into the catalog.
  final HeritagePlace? place;
  @override
  State<NearbyFacilitiesScreen> createState() => _NearbyFacilitiesScreenState();
}

class _NearbyFacilitiesScreenState extends State<NearbyFacilitiesScreen>
    with WidgetsBindingObserver {
  NearbyFacilityController? _controller;
  final _mapKey = GlobalKey();
  String _query = '';
  bool _awaitingSettings = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final scope = NavigationGuideScope.of(context);
    _controller = NearbyFacilityController(
      scope.navigation.location,
      scope.facilities,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller!.locate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      unawaited(_controller?.locate());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller?.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _viewMap(NearbyFacility facility) {
    _controller!.select(facility);
    final mapContext = _mapKey.currentContext;
    if (mapContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          mapContext,
          duration: const Duration(milliseconds: 200),
        ),
      );
    }
  }

  void _navigate(NearbyFacility facility) {
    _controller!.suspend();
    Navigator.pushNamed(
      context,
      AppRoutes.navigation,
      arguments: facility.destination,
    );
  }

  FacilityCard _card(NearbyFacility facility) => FacilityCard(
    key: ValueKey('facility-${facility.osmId}'),
    facility: facility,
    onMap: () => _viewMap(facility),
    onNavigate: () => _navigate(facility),
  );

  @override
  Widget build(BuildContext context) {
    final scope = NavigationGuideScope.of(context);
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        final s = _controller!;
        final matches = s.filtered(_query),
            visible = matches.take(100).toList();
        final locationMessage = switch (s.locationState) {
          LocationState.notRequested =>
            'Allow location to search nearby facilities.',
          LocationState.loading => 'Finding your current location…',
          LocationState.granted => 'Current location available',
          LocationState.denied => 'Location permission denied. Allow location to search nearby facilities.',
          LocationState.deniedForever =>
            'Location permission is blocked. Open settings to allow it.',
          LocationState.servicesOff =>
            'Device location is disabled. Enable location to continue.',
          LocationState.timeout =>
            'Location request timed out. Try again outdoors.',
          _ => 'Current location temporarily unavailable.',
        };
        final errorMessage = switch (s.error) {
          FacilityFailure.offline =>
            'Nearby search unavailable. Check your internet connection.',
          FacilityFailure.timeout =>
            'Nearby search timed out. Retry or choose a smaller radius.',
          FacilityFailure.rateLimited =>
            'Overpass is busy. Wait a minute before trying again.',
          FacilityFailure.server =>
            'Nearby search server unavailable. Try again later.',
          FacilityFailure.malformed =>
            'Nearby search returned incomplete or invalid data. Try again.',
          _ => 'Nearby search unavailable. Try again.',
        };
        return DiscoveryLayout(
          title: 'Nearby Facilities',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiText(
                'Useful places near your current location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              UiText(locationMessage),
              const SizedBox(height: 8),
              const UiText(
                'Search sends your GPS coordinates to Overpass. Results are OpenStreetMap listings, not verified emergency contacts. No search history is saved.',
              ),
              const SizedBox(height: 16),
              if (s.locationState != LocationState.granted &&
                  s.locationState != LocationState.loading)
                HeritageButton(
                  label: s.locationState == LocationState.deniedForever
                      ? 'Open Settings'
                      : s.locationState == LocationState.servicesOff
                      ? 'Enable Location'
                      : 'Allow Location',
                  onPressed: () async {
                    if (s.locationState == LocationState.deniedForever ||
                        s.locationState == LocationState.servicesOff) {
                      _awaitingSettings = true;
                      await s.location.openSettings(
                        device: s.locationState == LocationState.servicesOff,
                      );
                    } else {
                      await s.locate();
                    }
                  },
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FacilityCategory.values
                    .map(
                      (category) => ChoiceChip(
                        key: ValueKey('facility-category-${category.name}'),
                        label: UiText(category.label),
                        selected: s.category == category,
                        onSelected: (_) => s.selectCategory(category),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: s.radiusMeters,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.text(context, 'Search radius'),
                ),
                items: OverpassNearbyFacilityService.radii
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: UiText('{0} km', args: [r ~/ 1000]),
                      ),
                    )
                    .toList(),
                onChanged: (r) {
                  if (r != null) unawaited(s.selectRadius(r));
                },
              ),
              const SizedBox(height: 12),
              HeritageTextField(
                label: 'Search facilities',
                prefixIcon: const Icon(Icons.search),
                onChanged: (value) {
                  setState(() => _query = value);
                  s.select(null);
                },
              ),
              TextButton.icon(
                onPressed: s.loading || s.locationState == LocationState.loading
                    ? null
                    : () => s.locate(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const UiText('Refresh'),
              ),
              if (s.loading || s.locationState == LocationState.loading) ...[
                const UiText('Searching nearby facilities…'),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              Container(
                key: _mapKey,
                child: HeritageMap(
                  tilesEnabled: scope.tilesEnabled,
                  current: s.position,
                  focus: s.selected?.position,
                  fitMarkers: true,
                  markers: [
                    if (s.position != null)
                      HeritageMapMarker(
                        'current',
                        s.position!,
                        AppLocalizations.text(context, 'Current location'),
                        current: true,
                      ),
                    ...visible.map(
                      (f) => HeritageMapMarker(
                        f.osmId,
                        f.position,
                        f.name ??
                            AppLocalizations.text(context, 'Unnamed facility'),
                        onTap: () => s.select(f),
                      ),
                    ),
                  ],
                ),
              ),
              const UiText(
                'Proximity is measured directly from the search GPS fix. Navigation uses real road or walking routes.',
              ),
              const SizedBox(height: 16),
              if (s.error != null) ...[
                UiText(errorMessage),
                TextButton(
                  onPressed: s.search,
                  child: const UiText('Try again'),
                ),
              ],
              if (!s.loading &&
                  s.error == null &&
                  s.hasSearched &&
                  s.locationState == LocationState.granted) ...[
                UiText('{0} facilities found', args: [matches.length]),
                if (matches.isEmpty)
                  const DiscoveryEmptyState(
                    title: 'No facilities found',
                    message: 'Try another search, category or radius. OpenStreetMap coverage varies.',
                    icon: Icons.search_off,
                  ),
              ],
              if (matches.length > visible.length)
                UiText(
                  'Showing first {0} matches. Narrow your search for more.',
                  args: [visible.length],
                ),
              if (s.selected != null &&
                  visible.any((f) => f.osmId == s.selected!.osmId)) ...[
                const UiText('Selected facility'),
                _card(s.selected!),
              ],
              for (final facility in visible.where(
                (f) => f.osmId != s.selected?.osmId,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _card(facility),
                ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}
