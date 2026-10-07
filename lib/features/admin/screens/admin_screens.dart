import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/firebase/backend_error.dart';
import '../../../core/routes/app_routes.dart';
import '../../discovery_planning/models/heritage_place.dart';
import '../../discovery_planning/services/discovery_service.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../services/catalog_controller.dart';
import '../services/predefined_places.dart';
import '../services/place_validation.dart';
import '../services/place_image_catalog.dart';
import '../widgets/place_image_selector.dart';
import '../../discovery_planning/widgets/place_card.dart';
import '../../navigation_guide/services/emergency_controller.dart';

/// Rebuilds on role changes, including revocation while an admin route is open.
class AdminGuard extends StatelessWidget {
  const AdminGuard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CatalogScope.of(context).isAdmin
      ? child
      : const DiscoveryLayout(
          title: 'Admin access required',
          child: UiText(
            'This area is available only to authorized administrators. Return to your profile.',
          ),
        );
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    final recent = catalog.places.where((p) => p.updatedAt != null).toList()
      ..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
    return DiscoveryLayout(
      title: 'HeritageWalk Admin',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(
            'Historical Places',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          _CatalogStatus(catalog: catalog),
          if (!catalog.loading && catalog.error == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Total Places: ${catalog.places.length}\nActive: ${catalog.places.where((p) => p.isActive).length}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in DiscoveryService.categories.skip(1))
                  Chip(
                    label: Text(
                      '$category: ${catalog.places.where((p) => p.category == category).length}',
                    ),
                  ),
              ],
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 16),
              const UiText('Recently updated'),
              for (final place in recent.take(3))
                ListTile(
                  title: Text(place.name),
                  subtitle: Text(place.updatedAt!.toLocal().toString()),
                ),
            ],
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminReviews),
            icon: const Icon(Icons.reviews_outlined),
            label: const UiText('Review Moderation'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminPlaces),
            icon: const Icon(Icons.account_balance),
            label: const UiText('Manage Historical Places'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.adminEmergency),
            icon: const Icon(Icons.contact_phone_outlined),
            label: const UiText('Emergency Contacts'),
          ),
          Text(
            'Emergency contacts: ${EmergencyScope.of(context).adminContacts.length}',
          ),
        ],
      ),
    );
  }
}

class _CatalogStatus extends StatelessWidget {
  const _CatalogStatus({required this.catalog});
  final CatalogController catalog;
  @override
  Widget build(BuildContext context) => catalog.loading
      ? const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      : catalog.error != null
      ? Column(
          children: [
            Text(catalog.error!),
            TextButton(
              onPressed: catalog.reloadAdmin,
              child: const UiText('Reload catalog'),
            ),
          ],
        )
      : const SizedBox.shrink();
}

class AdminPlacesScreen extends StatefulWidget {
  const AdminPlacesScreen({super.key});
  @override
  State<AdminPlacesScreen> createState() => _AdminPlacesScreenState();
}

class _AdminPlacesScreenState extends State<AdminPlacesScreen> {
  String _query = '', _category = 'All';
  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: UiText(text)));
    }
  }

  Future<void> _delete(CatalogController catalog, HeritagePlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: UiText("Delete {0}?", args: [place.name]),
        content: const UiText(
          'This removes the catalog place. Saved favorites, itineraries and groups are retained. Consider deactivating it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const UiText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const UiText('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await catalog.delete(place.id);
      _message('Place deleted.');
    } catch (error) {
      _message(backendMessage(error));
    }
  }

  Future<void> _seed(CatalogController catalog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UiText('Seed original catalog?'),
        content: const UiText(
          'Add the eight original demo places using their stable IDs. Existing documents are skipped without overwriting them. Ratings are illustrative demo values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const UiText('Seed catalog'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await catalog.seed();
      _message('Created ${result.created}; skipped ${result.skipped}.');
    } catch (error) {
      _message(backendMessage(error));
    }
  }

  Future<void> _import(CatalogController catalog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UiText('Import all 17 predefined historical places?'),
        content: const UiText(
          'Existing matching places receive predefined metadata. Reviews and saved references are retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const UiText('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await catalog.importPredefined();
      _message(
        'Created ${result.created}; updated ${result.updated}; skipped ${result.skipped}.',
      );
    } catch (error) {
      _message(backendMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    final places = catalog.search(query: _query, category: _category);
    return DiscoveryLayout(
      title: 'Manage Historical Places',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: catalog.busy
                ? null
                : () => Navigator.pushNamed(context, AppRoutes.adminPlaceAdd),
            icon: const Icon(Icons.add),
            label: const UiText('Add Place'),
          ),

          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: AppLocalizations.text(context, 'Search places'),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.text(context, 'Category filter'),
            ),
            items: [
              for (final category in DiscoveryService.categories)
                DropdownMenuItem(value: category, child: UiText(category)),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'All'),
          ),
          _CatalogStatus(catalog: catalog),
          if (catalog.busy) const LinearProgressIndicator(),
          if (!catalog.loading && catalog.error == null && places.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: UiText(
                catalog.places.isEmpty
                    ? 'No historical places yet. Add a place or seed the original catalog.'
                    : 'No places match your search.',
              ),
            ),
          for (final place in places)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PlaceImage(place: place),
                    ),
                    Text(
                      place.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${place.city}, ${place.district} • ${place.category}',
                    ),
                    Chip(label: UiText(place.isActive ? 'Active' : 'Inactive')),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.adminPlacePreview,
                            arguments: place,
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const UiText('Preview'),
                        ),
                        TextButton.icon(
                          onPressed: catalog.busy
                              ? null
                              : () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.adminPlaceEdit,
                                  arguments: place.id,
                                ),
                          icon: const Icon(Icons.edit_outlined),
                          label: const UiText('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: catalog.busy
                              ? null
                              : () => _delete(catalog, place),
                          icon: const Icon(Icons.delete_outline),
                          label: const UiText('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminPlaceFormScreen extends StatefulWidget {
  const AdminPlaceFormScreen({super.key, this.placeId});
  final String? placeId;
  @override
  State<AdminPlaceFormScreen> createState() => _AdminPlaceFormScreenState();
}

class _AdminPlaceFormScreenState extends State<AdminPlaceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  static const _labels = {
    'name': 'Name',
    'shortDescription': 'Short description',
    'description': 'Description',
    'city': 'City',
    'district': 'District',
    'address': 'Address',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'historicalPeriod': 'Historical period',
    'openingHours': 'Opening hours',
    'entranceFee': 'Entry fee',
    'highlights': 'Highlights (one per line)',
    'accessibilityInfo': 'Accessibility information',
  };
  HeritagePlace? _original;
  String? _category;
  String? _documentId, _predefinedId;
  String _imagePath = AppAssets.placePlaceholder;
  bool _active = true, _featured = false, _saving = false, _initialized = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final catalog = CatalogScope.of(context);
    if (widget.placeId != null) {
      if (catalog.loading) return;
      _original = catalog.places
          .where((p) => p.id == widget.placeId)
          .firstOrNull;
      if (_original == null) return;
    }
    final values = _original?.toMap() ?? <String, Object?>{};
    for (final key in _labels.keys) {
      final value = key == 'highlights'
          ? _original?.highlights.join('\n')
          : values[key]?.toString();
      _controllers[key] = TextEditingController(
        text: value ?? (key == 'imagePath' ? AppAssets.placePlaceholder : ''),
      );
    }
    _imagePath = _original?.imagePath ?? AppAssets.placePlaceholder;
    _category = _original?.category;
    _documentId = _original?.id ?? catalog.repository?.newId();
    _active = _original?.isActive ?? true;
    _featured = _original?.isFeatured ?? false;
    _initialized = true;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(CatalogController catalog) async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = {
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    final place = HeritagePlace.fromMap({
      ...?_original?.toMap(),
      ...values,
      'id': _documentId,
      'category': _category,
      'latitude': double.tryParse(values['latitude']!),
      'longitude': double.tryParse(values['longitude']!),
      'highlights': values['highlights']!
          .split('\n')
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      'imagePath': _imagePath,
      'isActive': _active,
      'isFeatured': _featured,
    });
    try {
      await catalog.save(place, create: _original == null);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = backendMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _loadPredefined(HeritagePlace place, CatalogController catalog) {
    FocusManager.instance.primaryFocus?.unfocus();
    final values = place.toMap();
    setState(() {
      for (final entry in _controllers.entries) {
        entry.value.text = entry.key == 'highlights'
            ? place.highlights.join('\n')
            : values[entry.key]?.toString() ?? '';
      }
      _predefinedId = place.id;
      final alias = PredefinedPlaces.aliases[place.id];
      _documentId =
          !catalog.places.any((p) => p.id == place.id) &&
              alias != null &&
              catalog.places.any((p) => p.id == alias)
          ? alias
          : place.id;
      _category = place.category;
      _imagePath = place.imagePath;
      _active = place.isActive;
      _featured = place.isFeatured;
      _error = null;
    });
  }

  Future<void> _chooseImage() async {
    final selected = await choosePlaceImage(context, _imagePath);
    if (mounted && selected != null) setState(() => _imagePath = selected);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context);
    if (!_initialized) {
      return DiscoveryLayout(
        title: 'Edit Historical Place',
        child: catalog.loading
            ? const Center(child: CircularProgressIndicator())
            : const UiText(
                'This place is unavailable. Return to the catalog and reload.',
              ),
      );
    }
    return PopScope(
      canPop: !_saving,
      child: DiscoveryLayout(
        title: _original == null
            ? 'Add Historical Place'
            : 'Edit Historical Place',
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.placeId == null) ...[
                DropdownButtonFormField<String>(
                  key: const ValueKey('load-predefined-place'),
                  initialValue: _predefinedId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.text(
                      context,
                      'Load Predefined Place',
                    ),
                  ),
                  items: [
                    for (final place in PredefinedPlaces.places)
                      DropdownMenuItem(
                        value: place.id,
                        child: Text(
                          place.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving || catalog.busy
                      ? null
                      : (id) {
                          if (id != null) {
                            _loadPredefined(
                              PredefinedPlaces.places.singleWhere(
                                (p) => p.id == id,
                              ),
                              catalog,
                            );
                          }
                        },
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                key: ValueKey('place-category-$_category'),
                initialValue: DiscoveryService.categories.contains(_category)
                    ? _category
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.text(context, 'Category *'),
                ),
                items: [
                  for (final category in DiscoveryService.categories.skip(1))
                    DropdownMenuItem(value: category, child: UiText(category)),
                ],
                validator: (value) => localizeError(
                  context,
                  (PlaceValidation.requiredText)(value),
                ),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 16),
              UiText(
                'Choose Place Image',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              PlaceImage(
                place: HeritagePlace.fromMap({
                  ...?_original?.toMap(),
                  'name': _controllers['name']!.text,
                  'imagePath': _imagePath,
                }),
              ),
              const SizedBox(height: 8),
              Text(
                PlaceImageCatalog.forAsset(_imagePath)?.displayName ??
                    (_imagePath == AppAssets.placePlaceholder
                        ? 'Default placeholder'
                        : 'Current image'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _chooseImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const UiText('Choose Place Image'),
                  ),
                  if (_imagePath != AppAssets.placePlaceholder)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _imagePath = AppAssets.placePlaceholder,
                            ),
                      child: const UiText('Use placeholder'),
                    ),
                  if (_imagePath !=
                      (_original?.imagePath ?? AppAssets.placePlaceholder))
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _imagePath =
                                  _original?.imagePath ??
                                  AppAssets.placePlaceholder,
                            ),
                      child: const UiText('Restore current image'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (final entry in _labels.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    key: ValueKey('place-field-${entry.key}'),
                    controller: _controllers[entry.key],
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText:
                          '${entry.value}${['name', 'description', 'city', 'district'].contains(entry.key) ? ' *' : ''}',
                    ),
                    maxLines:
                        [
                          'description',
                          'highlights',
                          'accessibilityInfo',
                        ].contains(entry.key)
                        ? 4
                        : 1,
                    keyboardType: ['latitude', 'longitude'].contains(entry.key)
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    validator: (value) => localizeError(
                      context,
                      ((value) => switch (entry.key) {
                        'name' ||
                        'description' ||
                        'city' ||
                        'district' => PlaceValidation.requiredText(value),
                        'latitude' => PlaceValidation.coordinate(value, 90),
                        'longitude' => PlaceValidation.coordinate(value, 180),
                        'imagePath' => PlaceValidation.image(value),
                        _ => null,
                      })(value),
                    ),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const UiText('Active'),
                subtitle: const UiText('Visible in normal discovery'),
                value: _active,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _active = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const UiText('Featured'),
                value: _featured,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _featured = value),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: UiText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_saving) const LinearProgressIndicator(),
              FilledButton(
                onPressed: _saving || catalog.busy
                    ? null
                    : () => _save(catalog),
                child: const UiText('Save Place'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
